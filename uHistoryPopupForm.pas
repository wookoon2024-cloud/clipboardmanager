unit uHistoryPopupForm;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes,
  System.IOUtils, System.Types, Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs,
  Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.Buttons, Vcl.Menus, Vcl.Clipbrd, uLog, uDatabase;

type
  // 마우스와 히스토리 창을 가리지 않고 옆에 독립적으로 뜨는 대형 미리보기 폼
  TPreviewForm = class(TForm)
  private
    FImage: TImage;
    FPaintBoxText: TPaintBox;
    FCurrentText: string;
    procedure PaintBoxTextPaint(Sender: TObject);
  protected
    procedure CreateParams(var Params: TCreateParams); override;
  public
    constructor Create(AOwner: TComponent); override;
    procedure ShowImagePreview(const AFilePath: string; const APos: TPoint);
    procedure ShowTextPreview(const AText: string; const APos: TPoint);
    function GetPreviewDimensions(const ARecord: TClipRecord; var AWidth, AHeight: Integer): Boolean;
    procedure HidePreview;
  end;

  // 단일 통합 리스트 아이템 구조체
  TUnifiedClipItem = record
    IsFavHeader: Boolean; // 즐겨찾기 구분 헤더 여부
    IsFavorite: Boolean;
    Badge: string;       // '1'..'10', 'A'..'Z'
    ClipData: TClipRecord;
  end;

  THistoryPopupForm = class(TForm)
    PanelHeader: TPanel;
    LabelTitle: TLabel;
    PanelHeaderBtns: TPanel;
    BtnPin: TSpeedButton;
    BtnSettings: TSpeedButton;
    BtnClose: TSpeedButton;
    
    // 페이징 툴바
    PanelPaging: TPanel;
    LabelBtnPrev: TLabel;
    LabelPageInfo: TLabel;
    LabelBtnNext: TLabel;
    
    // 통합 단일 히스토리 리스트박스
    ListBoxClips: TListBox;
    
    // 하단 상태바 및 우측 하단 리사이즈 그립
    PanelBottomBar: TPanel;
    PaintBoxGrip: TPaintBox;
    
    // 마우스 아웃 실시간 감지 타이머
    TimerHoverCheck: TTimer;
    
    // 우클릭 팝업 메뉴
    PopupMenuClip: TPopupMenu;
    MenuPinClip: TMenuItem;
    MenuEditFav: TMenuItem;
    MenuToggleFav: TMenuItem;
    MenuDeleteClip: TMenuItem;
    
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure ListBoxClipsKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure ListBoxClipsDblClick(Sender: TObject);
    procedure ListBoxClipsDrawItem(Control: TWinControl; Index: Integer; Rect: TRect; State: TOwnerDrawState);
    procedure FormDeactivate(Sender: TObject);
    procedure BtnPinClick(Sender: TObject);
    procedure BtnSettingsClick(Sender: TObject);
    procedure BtnCloseClick(Sender: TObject);
    procedure LabelBtnPrevClick(Sender: TObject);
    procedure LabelBtnNextClick(Sender: TObject);
    procedure HeaderMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure GripMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure PaintBoxGripPaint(Sender: TObject);
    procedure ListBoxClipsMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure ListBoxClipsMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure ListBoxMouseLeave(Sender: TObject);
    procedure TimerHoverCheckTimer(Sender: TObject);
    procedure MenuPinClipClick(Sender: TObject);
    procedure MenuEditFavClick(Sender: TObject);
    procedure MenuToggleFavClick(Sender: TObject);
    procedure MenuDeleteClipClick(Sender: TObject);
    procedure BtnMouseEnter(Sender: TObject);
    procedure BtnMouseLeave(Sender: TObject);
  private
    FItems: TArray<TUnifiedClipItem>;
    FPrevActiveHWnd: HWND;
    FPinned: Boolean;
    FCurrentPage: Integer;
    FTotalCount: Integer;
    FTotalPages: Integer;
    FPageSize: Integer;
    FPreviewForm: TPreviewForm;
    FLastHoverIndex: Integer;
    FOldListBoxWndProc: TWndMethod;
    
    // 수동 마우스 드래그 리사이징 및 즐겨찾기 편집 모달 상태 플래그
    FIsManualResizing: Boolean;
    FIsEditingFav: Boolean;
    FUserCustomWidth: Integer;
    FUserCustomHeight: Integer;
    
    procedure ListBoxClipsWndProc(var Msg: TMessage);
    function GetPreviewForm: TPreviewForm;
    procedure UpdateUnifiedList;
    procedure AdjustWindowSize;
    procedure ShowPreviewForItem(const ARecord: TClipRecord; AItemScreenTop: Integer);
    procedure HidePreview;
    procedure PasteBitmap(const AFilePath: string; ARestoreFocus: Boolean = True);
    procedure PasteText(const AText: string; ARestoreFocus: Boolean = True);
    procedure WMActivate(var Msg: TWMActivate); message WM_ACTIVATE;
    procedure CMMouseLeave(var Msg: TMessage); message CM_MOUSELEAVE;
  protected
    procedure CreateParams(var Params: TCreateParams); override;
  public
    constructor Create(AOwner: TComponent); override;
    procedure RefreshAndShow;
    procedure UpdateDataOnly;
    procedure ApplyTheme;
    procedure PasteRecord(const ARecord: TClipRecord; ARestoreFocus: Boolean = True);
    property Pinned: Boolean read FPinned write FPinned;
  end;

var
  HistoryPopupForm: THistoryPopupForm;

implementation

uses
  uMainForm, uFavEditForm, uQuickBarForm, uThemeManager;

{$R *.dfm}

// 은은하고 부드러운 소프트 옐로우 컬러 상수
const
  COLOR_SOFT_YELLOW = $78D7F0; // RGB(240, 215, 120) in BGR

{ TPreviewForm }

constructor TPreviewForm.Create(AOwner: TComponent);
begin
  inherited CreateNew(AOwner);
  Self.BorderStyle := bsNone;
  Self.Color := RGB(45, 45, 45); // 1px 외곽 테두리
  Self.Width := 380;
  Self.Height := 240;
  Self.DoubleBuffered := True;
  
  // 이미지 뷰어
  FImage := TImage.Create(Self);
  FImage.Parent := Self;
  FImage.Stretch := True;
  FImage.Proportional := False;
  
  // 텍스트 뷰어 (Canvas 직접 렌더링 - 100% 화이트 텍스트)
  FPaintBoxText := TPaintBox.Create(Self);
  FPaintBoxText.Parent := Self;
  FPaintBoxText.OnPaint := PaintBoxTextPaint;
end;

procedure TPreviewForm.CreateParams(var Params: TCreateParams);
begin
  inherited CreateParams(Params);
  // 작업표시줄에 절대 뜨지 않는 툴윈도우 스타일
  Params.ExStyle := (Params.ExStyle or WS_EX_TOPMOST or WS_EX_TOOLWINDOW or WS_EX_NOACTIVATE) and not WS_EX_APPWINDOW;
  Params.WndParent := GetDesktopWindow;
end;

// Canvas 직접 드로잉: Windows 테마 간섭 없이 100% 선명한 화이트 텍스트 렌더링
procedure TPreviewForm.PaintBoxTextPaint(Sender: TObject);
var
  R: TRect;
begin
  FPaintBoxText.Canvas.Brush.Color := RGB(24, 24, 24);
  FPaintBoxText.Canvas.FillRect(FPaintBoxText.ClientRect);
  
  FPaintBoxText.Canvas.Font.Name := 'Segoe UI';
  FPaintBoxText.Canvas.Font.Size := 10;
  FPaintBoxText.Canvas.Font.Style := []; // BOLD 완전 제거
  FPaintBoxText.Canvas.Font.Color := RGB(245, 245, 245);
  
  R := FPaintBoxText.ClientRect;
  R.Inflate(-12, -12); // 편안한 12px 내부 패딩
  DrawText(FPaintBoxText.Canvas.Handle, PChar(FCurrentText), -1, R, DT_LEFT or DT_WORDBREAK or DT_NOPREFIX);
end;

// 이미지 해상도 비율에 맞춰 상하좌우 빈 공간 0%로 딱 맞게 리사이징
procedure TPreviewForm.ShowImagePreview(const AFilePath: string; const APos: TPoint);
var
  LBitmap: TBitmap;
  LOrigW, LOrigH: Integer;
  LDispW, LDispH: Integer;
  LScale: Double;
begin
  if not TFile.Exists(AFilePath) then
  begin
    HidePreview;
    Exit;
  end;
  
  try
    LBitmap := TBitmap.Create;
    try
      LBitmap.LoadFromFile(AFilePath);
      LOrigW := LBitmap.Width;
      LOrigH := LBitmap.Height;
      if (LOrigW <= 0) or (LOrigH <= 0) then Exit;
      
      // 이미지 비율대로 420x360 박스 안에 딱 맞춤 (상하좌우 빈 공간 완전 제거)
      LScale := 1.0;
      if (LOrigW > 420) or (LOrigH > 360) then
      begin
        if (420 / LOrigW) < (360 / LOrigH) then
          LScale := 420 / LOrigW
        else
          LScale := 360 / LOrigH;
      end;
      
      LDispW := Round(LOrigW * LScale);
      LDispH := Round(LOrigH * LScale);
      if LDispW < 80 then LDispW := 80;
      if LDispH < 60 then LDispH := 60;
      
      FImage.Picture.Assign(LBitmap);
    finally
      LBitmap.Free;
    end;
    
    FPaintBoxText.SetBounds(-1000, -1000, 10, 10);
    FImage.SetBounds(1, 1, LDispW, LDispH);
    FImage.BringToFront;
    FImage.Invalidate;
    
    SetWindowPos(Self.Handle, HWND_TOPMOST, APos.X, APos.Y, LDispW + 2, LDispH + 2, SWP_NOACTIVATE or SWP_SHOWWINDOW);
  except
    HidePreview;
  end;
end;

procedure TPreviewForm.ShowTextPreview(const AText: string; const APos: TPoint);
begin
  try
    FCurrentText := AText;
    FImage.SetBounds(-1000, -1000, 10, 10);
    FPaintBoxText.SetBounds(1, 1, 378, 238);
    FPaintBoxText.BringToFront;
    FPaintBoxText.Invalidate;
    
    SetWindowPos(Self.Handle, HWND_TOPMOST, APos.X, APos.Y, 380, 240, SWP_NOACTIVATE or SWP_SHOWWINDOW);
  except
    HidePreview;
  end;
end;

function TPreviewForm.GetPreviewDimensions(const ARecord: TClipRecord; var AWidth, AHeight: Integer): Boolean;
var
  LImgPath: string;
  LBitmap: TBitmap;
  LOrigW, LOrigH: Integer;
  LScale: Double;
begin
  Result := True;
  if ARecord.ClipType = 'IMAGE' then
  begin
    LImgPath := TPath.Combine(ExtractFilePath(ParamStr(0)), 'Images', ARecord.Content);
    if TFile.Exists(LImgPath) then
    begin
      try
        LBitmap := TBitmap.Create;
        try
          LBitmap.LoadFromFile(LImgPath);
          LOrigW := LBitmap.Width;
          LOrigH := LBitmap.Height;
          if (LOrigW > 0) and (LOrigH > 0) then
          begin
            LScale := 1.0;
            if (LOrigW > 420) or (LOrigH > 360) then
            begin
              if (420 / LOrigW) < (360 / LOrigH) then
                LScale := 420 / LOrigW
              else
                LScale := 360 / LOrigH;
            end;
            AWidth := Round(LOrigW * LScale) + 2;
            AHeight := Round(LOrigH * LScale) + 2;
            if AWidth < 82 then AWidth := 82;
            if AHeight < 62 then AHeight := 62;
            Exit;
          end;
        finally
          LBitmap.Free;
        end;
      except
      end;
    end;
    AWidth := 200;
    AHeight := 150;
  end
  else
  begin
    AWidth := 380;
    AHeight := 240;
  end;
end;

procedure TPreviewForm.HidePreview;
begin
  if HandleAllocated and IsWindowVisible(Self.Handle) then
    ShowWindow(Self.Handle, SW_HIDE);
end;

{ THistoryPopupForm }

constructor THistoryPopupForm.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FPinned := False;
  FCurrentPage := 1;
  FPageSize := 10;
  FLastHoverIndex := -1;
  FIsManualResizing := False;
  FUserCustomWidth := 480;
  FUserCustomHeight := 0;
end;

procedure THistoryPopupForm.CreateParams(var Params: TCreateParams);
begin
  inherited CreateParams(Params);
  // 작업표시줄에 절대 아이콘이 뜨지 않도록 GetDesktopWindow 부모 및 WS_EX_TOOLWINDOW 설정
  Params.ExStyle := (Params.ExStyle or WS_EX_TOPMOST or WS_EX_TOOLWINDOW) and not WS_EX_APPWINDOW;
  Params.WndParent := GetDesktopWindow;
end;

// VCL 초록색 포커스 점선(DrawFocusRect) 및 세로 스크롤바 원천 차단 윈도우 프로시저 가로채기
procedure THistoryPopupForm.ListBoxClipsWndProc(var Msg: TMessage);
begin
  if Msg.Msg = CN_DRAWITEM then
  begin
    // ODS_FOCUS 플래그를 강제로 제거하여 VCL 내부의 DrawFocusRect 호출을 원천 차단!
    PDrawItemStruct(Msg.LParam)^.itemState := PDrawItemStruct(Msg.LParam)^.itemState and not ODS_FOCUS;
    PDrawItemStruct(Msg.LParam)^.itemAction := PDrawItemStruct(Msg.LParam)^.itemAction and not ODA_FOCUS;
  end
  else if (Msg.Msg = WM_NCCALCSIZE) or (Msg.Msg = WM_NCPAINT) or (Msg.Msg = WM_PAINT) or (Msg.Msg = WM_SIZE) then
  begin
    ShowScrollBar(ListBoxClips.Handle, SB_BOTH, False);
  end;
  FOldListBoxWndProc(Msg);
end;

procedure THistoryPopupForm.BtnMouseEnter(Sender: TObject);
begin
  if Sender is TSpeedButton then
  begin
    if (Sender = BtnPin) and FPinned then
      TSpeedButton(Sender).Font.Color := RGB(30, 120, 255)
    else
      TSpeedButton(Sender).Font.Color := RGB(60, 140, 240);
  end;
end;

procedure THistoryPopupForm.BtnMouseLeave(Sender: TObject);
begin
  if Sender is TSpeedButton then
  begin
    if (Sender = BtnPin) and FPinned then
      TSpeedButton(Sender).Font.Color := RGB(60, 140, 240)
    else if Assigned(ThemeManager) then
      TSpeedButton(Sender).Font.Color := ThemeManager.Theme.HistoryTextColor
    else
      TSpeedButton(Sender).Font.Color := RGB(160, 165, 175);
  end;
end;

procedure THistoryPopupForm.FormCreate(Sender: TObject);
begin
  LogMsg('THistoryPopupForm.FormCreate START');
  Self.BorderStyle := bsNone;
  Self.Color := RGB(33, 36, 42);
  Self.Width := 480;
  Self.DoubleBuffered := True;
  
  if Assigned(DBManager) and (DBManager.GetSetting('FavCleanInit_V2', '0') = '0') then
  begin
    DBManager.ClearAllFavorites;
    DBManager.SaveSetting('FavCleanInit_V2', '1');
  end;
  
  FPreviewForm := nil;
  
  // 포커스 점선 차단용 서브클래싱 연결
  FOldListBoxWndProc := ListBoxClips.WindowProc;
  ListBoxClips.WindowProc := ListBoxClipsWndProc;
  
  // 헤더 및 바 드래그 이동 (모든 빈 영역 지원)
  PanelHeader.OnMouseDown := HeaderMouseDown;
  LabelTitle.OnMouseDown := HeaderMouseDown;
  PanelHeaderBtns.OnMouseDown := HeaderMouseDown;
  PanelBottomBar.OnMouseDown := HeaderMouseDown;
  PanelPaging.OnMouseDown := HeaderMouseDown;
  LabelPageInfo.OnMouseDown := HeaderMouseDown;
  
  // 우측 상단 버튼 호버 이벤트 연결
  BtnPin.OnMouseEnter := BtnMouseEnter;
  BtnPin.OnMouseLeave := BtnMouseLeave;
  BtnSettings.OnMouseEnter := BtnMouseEnter;
  BtnSettings.OnMouseLeave := BtnMouseLeave;
  BtnClose.OnMouseEnter := BtnMouseEnter;
  BtnClose.OnMouseLeave := BtnMouseLeave;
  
  // 우측 하단 리사이즈 그립
  PaintBoxGrip.Cursor := crSizeNWSE;
  PaintBoxGrip.OnMouseDown := GripMouseDown;
  PaintBoxGrip.OnPaint := PaintBoxGripPaint;
  
  // 통합 오너드로우 리스트박스 설정
  ListBoxClips.Style := lbOwnerDrawFixed;
  ListBoxClips.ItemHeight := 25;
  ListBoxClips.DoubleBuffered := True;
  ListBoxClips.Color := RGB(33, 36, 42);
  
  // 헤더 디자인
  PanelHeader.Color := RGB(42, 46, 54);
  LabelTitle.Font.Color := RGB(220, 225, 235);
  LabelTitle.Font.Style := [];
  
  // 페이징 패널 디자인
  PanelPaging.Color := RGB(36, 40, 48);
  LabelPageInfo.Font.Color := RGB(150, 165, 185);
  LabelPageInfo.Font.Style := [];
  LabelBtnPrev.Font.Color := RGB(220, 225, 235);
  LabelBtnPrev.Font.Style := [];
  LabelBtnNext.Font.Color := RGB(220, 225, 235);
  LabelBtnNext.Font.Style := [];
  LabelBtnPrev.Cursor := crHandPoint;
  LabelBtnNext.Cursor := crHandPoint;
  
  PanelBottomBar.Color := RGB(33, 36, 42);
  
  // 마우스 감지 타이머
  TimerHoverCheck.Interval := 100;
  TimerHoverCheck.Enabled := True;
  
  ApplyTheme;
end;

procedure THistoryPopupForm.ApplyTheme;
var
  LBtnColor: TColor;
begin
  if not Assigned(ThemeManager) then Exit;
  
  Self.Color := ThemeManager.Theme.HistoryBgColor;
  PanelHeader.Color := ThemeManager.Theme.HistoryHeaderBgColor;
  PanelHeaderBtns.Color := ThemeManager.Theme.HistoryHeaderBgColor;
  PanelPaging.Color := ThemeManager.Theme.HistoryHeaderBgColor;
  PanelBottomBar.Color := ThemeManager.Theme.HistoryHeaderBgColor;
  
  ListBoxClips.Color := ThemeManager.Theme.HistoryBgColor;
  ListBoxClips.ItemHeight := ThemeManager.Theme.HistoryItemHeight;
  ListBoxClips.Font.Size := ThemeManager.Theme.HistoryFontSize;
  
  LabelTitle.Font.Color := ThemeManager.Theme.HistoryTextColor;
  LabelPageInfo.Font.Color := ThemeManager.Theme.HistoryTextColor;
  
  LBtnColor := ThemeManager.Theme.HistoryTextColor;
  
  // 우측 상단 아이콘 버튼들 확실한 초기화
  BtnPin.Font.Name := 'Segoe UI Symbol';
  BtnPin.Caption := '📌';
  if FPinned then
    BtnPin.Font.Color := RGB(60, 140, 240)
  else
    BtnPin.Font.Color := LBtnColor;
    
  BtnSettings.Font.Name := 'Segoe UI Symbol';
  BtnSettings.Caption := '⚙';
  BtnSettings.Font.Color := LBtnColor;
  
  BtnClose.Font.Name := 'Segoe UI Symbol';
  BtnClose.Caption := '✕';
  BtnClose.Font.Color := LBtnColor;
  
  ListBoxClips.Invalidate;
  AdjustWindowSize;
end;

procedure THistoryPopupForm.FormDestroy(Sender: TObject);
begin
  ListBoxClips.WindowProc := FOldListBoxWndProc;
  if Assigned(FPreviewForm) then
    FPreviewForm.Free;
end;

function THistoryPopupForm.GetPreviewForm: TPreviewForm;
begin
  if not Assigned(FPreviewForm) then
    FPreviewForm := TPreviewForm.Create(nil);
  Result := FPreviewForm;
end;

// Windows 표준 사선 삼각 리사이즈 그립 (///)
procedure THistoryPopupForm.PaintBoxGripPaint(Sender: TObject);
var
  C: TCanvas;
  W, H: Integer;
begin
  C := PaintBoxGrip.Canvas;
  W := PaintBoxGrip.Width;
  H := PaintBoxGrip.Height;
  
  C.Pen.Color := RGB(140, 140, 140);
  C.Pen.Width := 1;
  
  C.MoveTo(W - 4, H - 12); C.LineTo(W - 12, H - 4);
  C.MoveTo(W - 4, H - 8);  C.LineTo(W - 8, H - 4);
  C.MoveTo(W - 4, H - 4);  C.LineTo(W - 4, H - 4);
end;

procedure THistoryPopupForm.WMActivate(var Msg: TWMActivate);
begin
  inherited;
  if (Msg.Active = WA_INACTIVE) and not FPinned and not FIsManualResizing and not FIsEditingFav then
  begin
    HidePreview;
    Self.Hide;
  end;
end;

procedure THistoryPopupForm.CMMouseLeave(var Msg: TMessage);
begin
  inherited;
  HidePreview;
end;

procedure THistoryPopupForm.HeaderMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  if Button = mbLeft then
  begin
    ReleaseCapture;
    Perform(WM_SYSCOMMAND, $F012, 0);
  end;
end;

// 실시간 마우스 드래그 창 크기 조절
procedure THistoryPopupForm.GripMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  LStartMouse, LCurrentMouse: TPoint;
  LStartW, LStartH: Integer;
  LNewW, LNewH: Integer;
begin
  if Button <> mbLeft then Exit;
  
  FIsManualResizing := True;
  GetCursorPos(LStartMouse);
  LStartW := Self.Width;
  LStartH := Self.Height;
  
  SetCapture(Self.Handle);
  try
    while (GetAsyncKeyState(VK_LBUTTON) < 0) do
    begin
      Application.ProcessMessages;
      GetCursorPos(LCurrentMouse);
      
      LNewW := LStartW + (LCurrentMouse.X - LStartMouse.X);
      LNewH := LStartH + (LCurrentMouse.Y - LStartMouse.Y);
      
      if LNewW < 360 then LNewW := 360;
      if LNewH < 220 then LNewH := 220;
      
      if (Self.Width <> LNewW) or (Self.Height <> LNewH) then
      begin
        SetWindowPos(Self.Handle, 0, Self.Left, Self.Top, LNewW, LNewH, SWP_NOZORDER or SWP_NOACTIVATE);
        FUserCustomWidth := LNewW;
        FUserCustomHeight := LNewH;
        ListBoxClips.Invalidate;
      end;
      
      Sleep(10);
    end;
  finally
    ReleaseCapture;
    FIsManualResizing := False;
    ListBoxClips.Invalidate;
  end;
end;

// 스크롤바가 절대 생기지 않도록 여유 높이 계산 및 스크롤바 숨김
procedure THistoryPopupForm.AdjustWindowSize;
var
  LItemCount, LTotalH: Integer;
begin
  LItemCount := Length(FItems);
  if LItemCount < 1 then LItemCount := 1;
  if LItemCount > 16 then LItemCount := 16;
  
  // 항목 수에 맞춰 스크롤바가 전혀 생기지 않도록 25px 콤팩트 높이 설정
  LTotalH := PanelHeader.Height + PanelPaging.Height + (LItemCount * 25) + PanelBottomBar.Height + 2;
  
  if not FPinned and (FUserCustomHeight = 0) then
  begin
    Self.Width := FUserCustomWidth;
    Self.Height := LTotalH;
  end;
  
  // 윈도우 OS 스크롤바 강제 숨김
  if ListBoxClips.HandleAllocated then
    ShowScrollBar(ListBoxClips.Handle, SB_BOTH, False);
end;

// 최근 클립보드 내역(1~10)과 즐겨찾기(A~Z)를 단일 리스트로 완전 통합
procedure THistoryPopupForm.UpdateUnifiedList;
var
  LClips, LFavs: TArray<TClipRecord>;
  I, LIdx, LCount: Integer;
begin
  ListBoxClips.Items.BeginUpdate;
  try
    ListBoxClips.Items.Clear;
    SetLength(FItems, 0);
    
    // 1. 최근 클립보드 페이징 데이터 로드
    DBManager.GetPagedClipRecords(FCurrentPage, FPageSize, LClips, FTotalCount);
    
    if FTotalCount = 0 then
      FTotalPages := 1
    else
      FTotalPages := ((FTotalCount - 1) div FPageSize) + 1;
      
    LabelPageInfo.Caption := Format('%d / %d  (총 %d개)', [FCurrentPage, FTotalPages, FTotalCount]);
    LabelBtnPrev.Enabled := True;
    LabelBtnNext.Enabled := True;
    
    if FCurrentPage > 1 then 
      LabelBtnPrev.Font.Color := RGB(220, 225, 235) 
    else 
      LabelBtnPrev.Font.Color := RGB(80, 85, 95);
      
    if FCurrentPage < FTotalPages then 
      LabelBtnNext.Font.Color := RGB(220, 225, 235) 
    else 
      LabelBtnNext.Font.Color := RGB(80, 85, 95);
    
    // 2. 즐겨찾기 데이터 로드
    DBManager.GetFavoriteClipRecords(LFavs);
    
    LCount := Length(LClips);
    if Length(LFavs) > 0 then
      LCount := LCount + 1 + Length(LFavs);
      
    SetLength(FItems, LCount);
    LIdx := 0;
    
    // 3. 최근 항목 추가 (번호 1..10)
    for I := 0 to Length(LClips) - 1 do
    begin
      FItems[LIdx].IsFavHeader := False;
      FItems[LIdx].IsFavorite := LClips[I].IsFavorite;
      if I = 9 then
        FItems[LIdx].Badge := '0'
      else
        FItems[LIdx].Badge := IntToStr(I + 1);
      FItems[LIdx].ClipData := LClips[I];
      
      ListBoxClips.Items.Add(IntToStr(LIdx));
      Inc(LIdx);
    end;
    
    // 4. 즐겨찾기 구분 헤더 및 항목 추가 (알파벳 A..Z)
    if Length(LFavs) > 0 then
    begin
      FItems[LIdx].IsFavHeader := True;
      FItems[LIdx].IsFavorite := True;
      FItems[LIdx].Badge := '';
      ListBoxClips.Items.Add(IntToStr(LIdx));
      Inc(LIdx);
      
      for I := 0 to Length(LFavs) - 1 do
      begin
        FItems[LIdx].IsFavHeader := False;
        FItems[LIdx].IsFavorite := True;
        if I < 26 then
          FItems[LIdx].Badge := Chr(Ord('A') + I)
        else
          FItems[LIdx].Badge := '#';
        FItems[LIdx].ClipData := LFavs[I];
        
        ListBoxClips.Items.Add(IntToStr(LIdx));
        Inc(LIdx);
      end;
    end;
  finally
    ListBoxClips.Items.EndUpdate;
  end;
end;

// 통합 오너드로우: 모던 슬레이트 그레이, 볼드 제거, 정밀 패딩, 와이드 이미지 스트립
procedure THistoryPopupForm.ListBoxClipsDrawItem(Control: TWinControl; Index: Integer; Rect: TRect; State: TOwnerDrawState);
var
  LCanvas: TCanvas;
  LContent: string;
  LNumRect, LTextRect, LImgRect: TRect;
  LImgPath: string;
  LBitmap: TBitmap;
begin
  LCanvas := ListBoxClips.Canvas;
  
  if (Index < 0) or (Index >= Length(FItems)) then Exit;
  
  // 1. 즐겨찾기 구분 헤더
  if FItems[Index].IsFavHeader then
  begin
    LCanvas.Brush.Color := ThemeManager.Theme.HistoryFavHeaderBgColor;
    LCanvas.FillRect(Rect);
    
    LCanvas.Font.Name := 'Segoe UI';
    LCanvas.Font.Size := ThemeManager.Theme.HistoryFontSize;
    LCanvas.Font.Style := [];
    LCanvas.Font.Color := ThemeManager.Theme.HistoryTextColor;
    
    DrawText(LCanvas.Handle, PChar('즐겨찾기'), -1, Rect, DT_CENTER or DT_VCENTER or DT_SINGLELINE);
    Exit;
  end;
  
  // 2. 배경색 및 스타일별 아이템 렌더링
  LCanvas.Brush.Color := ThemeManager.Theme.HistoryBgColor;
  LCanvas.Brush.Style := bsSolid;
  LCanvas.FillRect(Rect);
  
  if odSelected in State then
  begin
    LCanvas.Brush.Color := ThemeManager.Theme.HistorySelectedBgColor;
    if ThemeManager.Theme.DesignStyle = 1 then // 모던 라운드: 둥근 캡슐 하이라이트
    begin
      LCanvas.Pen.Color := ThemeManager.Theme.HistorySelectedBgColor;
      LCanvas.RoundRect(Rect.Left + 2, Rect.Top + 1, Rect.Right - 2, Rect.Bottom - 1, 6, 6);
    end
    else if ThemeManager.Theme.DesignStyle = 2 then // 글래스 아크릴: 1px 세련된 보더 하이라이트
    begin
      LCanvas.FillRect(Rect);
      LCanvas.Pen.Color := RGB(180, 200, 230);
      LCanvas.Polyline([Point(Rect.Left, Rect.Top), Point(Rect.Right - 1, Rect.Top), 
                        Point(Rect.Right - 1, Rect.Bottom - 1), Point(Rect.Left, Rect.Bottom - 1), 
                        Point(Rect.Left, Rect.Top)]);
    end
    else if ThemeManager.Theme.DesignStyle = 3 then // 사이버 네온: 좌측 선명한 액센트 바
    begin
      LCanvas.FillRect(Rect);
      LCanvas.Brush.Color := RGB(80, 180, 255);
      LCanvas.FillRect(System.Classes.Rect(Rect.Left, Rect.Top, Rect.Left + 3, Rect.Bottom));
    end
    else
    begin
      LCanvas.FillRect(Rect); // 기본 모던 플랫
    end;
  end;
  
  // 3. 좌측 배지 (1..10, A..Z - 볼드 제거, 단정한 색상)
  LNumRect := Rect;
  LNumRect.Right := LNumRect.Left + 24;
  
  LCanvas.Font.Name := 'Segoe UI';
  LCanvas.Font.Size := ThemeManager.Theme.HistoryFontSize;
  LCanvas.Font.Style := [];
  if odSelected in State then
    LCanvas.Font.Color := ThemeManager.Theme.HistorySelectedTextColor
  else
    LCanvas.Font.Color := ThemeManager.Theme.QuickCardNumColor;
  DrawText(LCanvas.Handle, PChar(FItems[Index].Badge), -1, LNumRect, DT_CENTER or DT_VCENTER or DT_SINGLELINE);
  
  // 4. 이미지인 경우: 시간 텍스트 완전 제거, 가로로 길고 세로는 줄높이에 맞춘 와이드 파노라마 스트립 드로잉
  if FItems[Index].ClipData.ClipType = 'IMAGE' then
  begin
    LImgPath := TPath.Combine(ExtractFilePath(ParamStr(0)), 'Images', FItems[Index].ClipData.Content);
    LImgRect := Rect;
    LImgRect.Left := Rect.Left + 28;
    LImgRect.Right := Rect.Right - 8;
    LImgRect.Top := Rect.Top + 2;
    LImgRect.Bottom := Rect.Bottom - 2;
    
    if TFile.Exists(LImgPath) then
    begin
      try
        LBitmap := TBitmap.Create;
        try
          LBitmap.LoadFromFile(LImgPath);
          LCanvas.StretchDraw(LImgRect, LBitmap);
        finally
          LBitmap.Free;
        end;
      except
      end;
    end;
    Exit; // 이미지 옆 불필요한 시간 텍스트 소멸
  end;
  
  // 5. 텍스트 / 즐겨찾기 내용 텍스트
  LTextRect := Rect;
  LTextRect.Left := Rect.Left + 28;
  LTextRect.Right := Rect.Right - 8;
  
  // 고정된 항목인 경우 우측에 핀 표시
  if FItems[Index].ClipData.IsPinned then
  begin
    LImgRect := Rect;
    LImgRect.Left := Rect.Right - 20;
    LImgRect.Right := Rect.Right - 4;
    
    LCanvas.Font.Name := 'Segoe UI Symbol';
    LCanvas.Font.Size := 8;
    LCanvas.Font.Color := RGB(140, 185, 240);
    DrawText(LCanvas.Handle, PChar('📌'), -1, LImgRect, DT_CENTER or DT_VCENTER or DT_SINGLELINE);
    
    LTextRect.Right := Rect.Right - 22;
  end;
  
  LCanvas.Font.Name := 'Segoe UI';
  LCanvas.Font.Style := [];
  LCanvas.Font.Size := ThemeManager.Theme.HistoryFontSize;
  if odSelected in State then
    LCanvas.Font.Color := ThemeManager.Theme.HistorySelectedTextColor
  else
    LCanvas.Font.Color := ThemeManager.Theme.HistoryTextColor;
  
  if (FItems[Index].Badge <> '') and not CharInSet(FItems[Index].Badge[1], ['0'..'9']) then
  begin
    if Trim(FItems[Index].ClipData.Title) <> '' then
      LContent := FItems[Index].ClipData.Title
    else
      LContent := FItems[Index].ClipData.Content;
  end
  else
  begin
    LContent := FItems[Index].ClipData.Content;
  end;
    
  LContent := StringReplace(StringReplace(StringReplace(LContent, #13#10, ' ', [rfReplaceAll]), #10, ' ', [rfReplaceAll]), #9, ' ', [rfReplaceAll]);
  LContent := Trim(LContent);
  
  DrawText(LCanvas.Handle, PChar(LContent), -1, LTextRect, DT_LEFT or DT_VCENTER or DT_SINGLELINE or DT_END_ELLIPSIS);
end;

procedure THistoryPopupForm.UpdateDataOnly;
begin
  UpdateUnifiedList;
  AdjustWindowSize;
end;

procedure THistoryPopupForm.RefreshAndShow;
var
  LMousePos: TPoint;
begin
  FPrevActiveHWnd := GetForegroundWindow;
  
  UpdateUnifiedList;
  AdjustWindowSize;
  
  if not FPinned then
  begin
    GetCursorPos(LMousePos);
    Self.Left := LMousePos.X + 50;
    Self.Top := LMousePos.Y + 15;
    
    if Self.Left + Self.Width > Screen.DesktopWidth then
      Self.Left := LMousePos.X - Self.Width - 15;
    if Self.Top + Self.Height > Screen.DesktopHeight then
      Self.Top := Screen.DesktopHeight - Self.Height - 15;
  end;
    
  Self.Show;
  SetForegroundWindow(Self.Handle);
  
  if ListBoxClips.Items.Count > 0 then
  begin
    ListBoxClips.ItemIndex := 0;
    ListBoxClips.SetFocus;
  end;
end;

// 마우스와 창을 가리지 않는 독립 미리보기
procedure THistoryPopupForm.ShowPreviewForItem(const ARecord: TClipRecord; AItemScreenTop: Integer);
var
  LPreviewPos: TPoint;
  LPreviewW, LPreviewH: Integer;
begin
  GetPreviewForm.GetPreviewDimensions(ARecord, LPreviewW, LPreviewH);
  
  // 1. 기본 위치: 히스토리 창의 오른쪽 (간격 10px)
  LPreviewPos.X := Self.Left + Self.Width + 10;
  LPreviewPos.Y := AItemScreenTop - 20;
  
  // 2. 화면 오른쪽을 벗어나는 경우: 히스토리 창의 왼쪽 테두리에 딱 붙여서 띄움 (간격 10px)
  if LPreviewPos.X + LPreviewW > Screen.DesktopWidth then
  begin
    LPreviewPos.X := Self.Left - LPreviewW - 10;
  end;
  
  // 3. 화면 상하 경계선 방어
  if LPreviewPos.Y < 30 then 
    LPreviewPos.Y := 30;
  if LPreviewPos.Y + LPreviewH > Screen.DesktopHeight then
    LPreviewPos.Y := Screen.DesktopHeight - LPreviewH - 15;
    
  if ARecord.ClipType = 'IMAGE' then
    GetPreviewForm.ShowImagePreview(TPath.Combine(ExtractFilePath(ParamStr(0)), 'Images', ARecord.Content), LPreviewPos)
  else
    GetPreviewForm.ShowTextPreview(ARecord.Content, LPreviewPos);
end;

procedure THistoryPopupForm.HidePreview;
begin
  FLastHoverIndex := -1;
  if Assigned(FPreviewForm) then
    FPreviewForm.HidePreview;
end;

procedure THistoryPopupForm.ListBoxClipsMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
var
  LIdx: Integer;
  LItemRect: TRect;
  LScreenPt: TPoint;
begin
  LIdx := ListBoxClips.ItemAtPos(Point(X, Y), True);
  if (LIdx >= 0) and (LIdx < Length(FItems)) then
  begin
    if FItems[LIdx].IsFavHeader then
    begin
      HidePreview;
      Exit;
    end;
    
    if ListBoxClips.ItemIndex <> LIdx then
      ListBoxClips.ItemIndex := LIdx;
      
    if FLastHoverIndex <> LIdx then
    begin
      FLastHoverIndex := LIdx;
      LItemRect := ListBoxClips.ItemRect(LIdx);
      LScreenPt := ListBoxClips.ClientToScreen(Point(0, LItemRect.Top));
      ShowPreviewForItem(FItems[LIdx].ClipData, LScreenPt.Y);
    end;
  end
  else
  begin
    HidePreview;
  end;
end;

procedure THistoryPopupForm.ListBoxMouseLeave(Sender: TObject);
begin
  HidePreview;
end;

procedure THistoryPopupForm.TimerHoverCheckTimer(Sender: TObject);
var
  LMousePt: TPoint;
  LFormRect: TRect;
begin
  if not Self.Visible then
  begin
    HidePreview;
    Exit;
  end;
  
  if Assigned(FPreviewForm) and IsWindowVisible(FPreviewForm.Handle) then
  begin
    GetCursorPos(LMousePt);
    LFormRect := Self.BoundsRect;
    if not PtInRect(LFormRect, LMousePt) then
      HidePreview;
  end;
end;

procedure THistoryPopupForm.ListBoxClipsMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  LIdx: Integer;
  LPoint: TPoint;
begin
  if Button = mbRight then
  begin
    LIdx := ListBoxClips.ItemAtPos(Point(X, Y), True);
    if (LIdx >= 0) and (LIdx < Length(FItems)) and not FItems[LIdx].IsFavHeader then
    begin
      ListBoxClips.ItemIndex := LIdx;
      
      // 1. 상단 고정 토글 메뉴
      if FItems[LIdx].ClipData.IsPinned then
        MenuPinClip.Caption := '상단 고정 해제'
      else
        MenuPinClip.Caption := '상단 고정';
      
      // 2. 즐겨찾기 토글 및 편집 메뉴
      if FItems[LIdx].IsFavorite then
      begin
        MenuEditFav.Visible := True;
        MenuToggleFav.Caption := '즐겨찾기에서 해제';
      end
      else
      begin
        MenuEditFav.Visible := False;
        MenuToggleFav.Caption := '즐겨찾기로 등록';
      end;
        
      GetCursorPos(LPoint);
      PopupMenuClip.Popup(LPoint.X, LPoint.Y);
    end;
  end;
end;

procedure THistoryPopupForm.MenuPinClipClick(Sender: TObject);
var
  LIdx: Integer;
begin
  LIdx := ListBoxClips.ItemIndex;
  if (LIdx >= 0) and (LIdx < Length(FItems)) and not FItems[LIdx].IsFavHeader then
  begin
    DBManager.TogglePinClip(FItems[LIdx].ClipData.ID);
    UpdateDataOnly;
    
    if Assigned(QuickBarForm) and QuickBarForm.Visible then
      QuickBarForm.UpdateItems;
  end;
end;

procedure THistoryPopupForm.MenuEditFavClick(Sender: TObject);
var
  LIdx: Integer;
  LTitle, LContent: string;
begin
  LIdx := ListBoxClips.ItemIndex;
  if (LIdx >= 0) and (LIdx < Length(FItems)) and not FItems[LIdx].IsFavHeader and FItems[LIdx].IsFavorite then
  begin
    LTitle := FItems[LIdx].ClipData.Title;
    LContent := FItems[LIdx].ClipData.Content;
    if LTitle = '' then
    begin
      if FItems[LIdx].ClipData.ClipType = 'IMAGE' then
        LTitle := '이미지 즐겨찾기'
      else
        LTitle := Copy(Trim(LContent), 1, 20);
    end;
    
    FIsEditingFav := True;
    try
      if TFavEditForm.Execute(Self, LTitle, LContent) then
      begin
        DBManager.SaveFavoriteWithTitle(FItems[LIdx].ClipData.ID, LTitle, LContent);
        UpdateDataOnly;
        
        if Assigned(QuickBarForm) and QuickBarForm.Visible then
          QuickBarForm.UpdateItems;
      end;
    finally
      FIsEditingFav := False;
    end;
  end;
end;

procedure THistoryPopupForm.MenuToggleFavClick(Sender: TObject);
var
  LIdx: Integer;
  LTitle, LContent: string;
begin
  LIdx := ListBoxClips.ItemIndex;
  if (LIdx >= 0) and (LIdx < Length(FItems)) and not FItems[LIdx].IsFavHeader then
  begin
    if FItems[LIdx].IsFavorite then
    begin
      DBManager.ToggleFavorite(FItems[LIdx].ClipData.ID);
      UpdateDataOnly;
      
      if Assigned(QuickBarForm) and QuickBarForm.Visible then
        QuickBarForm.UpdateItems;
    end
    else
    begin
      LTitle := FItems[LIdx].ClipData.Title;
      LContent := FItems[LIdx].ClipData.Content;
      if LTitle = '' then
      begin
        if FItems[LIdx].ClipData.ClipType = 'IMAGE' then
          LTitle := '이미지 즐겨찾기'
        else
          LTitle := Copy(Trim(LContent), 1, 20);
      end;
      
      FIsEditingFav := True;
      try
        if TFavEditForm.Execute(Self, LTitle, LContent) then
        begin
          DBManager.SaveFavoriteWithTitle(FItems[LIdx].ClipData.ID, LTitle, LContent);
          UpdateDataOnly;
          
          if Assigned(QuickBarForm) and QuickBarForm.Visible then
            QuickBarForm.UpdateItems;
        end;
      finally
        FIsEditingFav := False;
      end;
    end;
  end;
end;

procedure THistoryPopupForm.MenuDeleteClipClick(Sender: TObject);
var
  LIdx: Integer;
begin
  LIdx := ListBoxClips.ItemIndex;
  if (LIdx >= 0) and (LIdx < Length(FItems)) and not FItems[LIdx].IsFavHeader then
  begin
    DBManager.DeleteClip(FItems[LIdx].ClipData.ID);
    UpdateDataOnly;
    
    if Assigned(QuickBarForm) and QuickBarForm.Visible then
      QuickBarForm.UpdateItems;
  end;
end;

procedure THistoryPopupForm.PasteText(const AText: string; ARestoreFocus: Boolean);
var
  LInput: array[0..3] of TInput;
begin
  HidePreview;
  Clipboard.AsText := AText;
  
  if not FPinned then
    Self.Hide;
    
  if ARestoreFocus and (FPrevActiveHWnd <> 0) then
  begin
    SetForegroundWindow(FPrevActiveHWnd);
    Sleep(50);
  end;
  
  Sleep(40);
  
  ZeroMemory(@LInput, SizeOf(LInput));
  
  LInput[0].Itype := INPUT_KEYBOARD;
  LInput[0].ki.wVk := VK_CONTROL;
  
  LInput[1].Itype := INPUT_KEYBOARD;
  LInput[1].ki.wVk := Ord('V');
  
  LInput[2].Itype := INPUT_KEYBOARD;
  LInput[2].ki.wVk := Ord('V');
  LInput[2].ki.dwFlags := KEYEVENTF_KEYUP;
  
  LInput[3].Itype := INPUT_KEYBOARD;
  LInput[3].ki.wVk := VK_CONTROL;
  LInput[3].ki.dwFlags := KEYEVENTF_KEYUP;
  
  SendInput(4, LInput[0], SizeOf(TInput));
end;

procedure THistoryPopupForm.PasteBitmap(const AFilePath: string; ARestoreFocus: Boolean);
var
  LBitmap: TBitmap;
  LInput: array[0..3] of TInput;
begin
  HidePreview;
  if not TFile.Exists(AFilePath) then Exit;
  
  LBitmap := TBitmap.Create;
  try
    LBitmap.LoadFromFile(AFilePath);
    Clipboard.Assign(LBitmap);
  finally
    LBitmap.Free;
  end;
  
  if not FPinned then
    Self.Hide;
    
  if ARestoreFocus and (FPrevActiveHWnd <> 0) then
  begin
    SetForegroundWindow(FPrevActiveHWnd);
    Sleep(50);
  end;
  
  Sleep(40);
  
  ZeroMemory(@LInput, SizeOf(LInput));
  
  LInput[0].Itype := INPUT_KEYBOARD;
  LInput[0].ki.wVk := VK_CONTROL;
  
  LInput[1].Itype := INPUT_KEYBOARD;
  LInput[1].ki.wVk := Ord('V');
  
  LInput[2].Itype := INPUT_KEYBOARD;
  LInput[2].ki.wVk := Ord('V');
  LInput[2].ki.dwFlags := KEYEVENTF_KEYUP;
  
  LInput[3].Itype := INPUT_KEYBOARD;
  LInput[3].ki.wVk := VK_CONTROL;
  LInput[3].ki.dwFlags := KEYEVENTF_KEYUP;
  
  SendInput(4, LInput[0], SizeOf(TInput));
end;

procedure THistoryPopupForm.PasteRecord(const ARecord: TClipRecord; ARestoreFocus: Boolean);
begin
  if Assigned(MainForm) then
    MainForm.PauseMonitoring(500);
    
  if ARecord.ClipType = 'IMAGE' then
    PasteBitmap(ARecord.Content, ARestoreFocus)
  else
    PasteText(ARecord.Content, ARestoreFocus);
end;

procedure THistoryPopupForm.ListBoxClipsKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
var
  LIndex, I: Integer;
  LTargetKey: string;
begin
  if Key = VK_RETURN then
  begin
    LIndex := ListBoxClips.ItemIndex;
    if (LIndex >= 0) and (LIndex < Length(FItems)) and not FItems[LIndex].IsFavHeader then
      PasteRecord(FItems[LIndex].ClipData);
    Key := 0;
  end
  else if Key = VK_ESCAPE then
  begin
    HidePreview;
    Self.Hide;
    Key := 0;
  end
  else if (Key = VK_LEFT) or (Key = Ord('P')) then
  begin
    LabelBtnPrevClick(Sender);
    Key := 0;
  end
  else if (Key = VK_RIGHT) or (Key = Ord('N')) then
  begin
    LabelBtnNextClick(Sender);
    Key := 0;
  end
  else if (Key >= Ord('0')) and (Key <= Ord('9')) and (Shift = []) then
  begin
    if Key = Ord('0') then
      LTargetKey := '0'
    else
      LTargetKey := Chr(Key);
      
    for I := 0 to Length(FItems) - 1 do
    begin
      if (FItems[I].Badge = LTargetKey) and not FItems[I].IsFavHeader then
      begin
        ListBoxClips.ItemIndex := I;
        PasteRecord(FItems[I].ClipData);
        Break;
      end;
    end;
    Key := 0;
  end
  else if (Key >= Ord('A')) and (Key <= Ord('Z')) and (Shift = []) then
  begin
    LTargetKey := Chr(Key);
    for I := 0 to Length(FItems) - 1 do
    begin
      if (FItems[I].Badge = LTargetKey) and not FItems[I].IsFavHeader then
      begin
        ListBoxClips.ItemIndex := I;
        PasteRecord(FItems[I].ClipData);
        Break;
      end;
    end;
    Key := 0;
  end;
end;

procedure THistoryPopupForm.ListBoxClipsDblClick(Sender: TObject);
var
  LIndex: Integer;
begin
  LIndex := ListBoxClips.ItemIndex;
  if (LIndex >= 0) and (LIndex < Length(FItems)) and not FItems[LIndex].IsFavHeader then
    PasteRecord(FItems[LIndex].ClipData);
end;

procedure THistoryPopupForm.LabelBtnPrevClick(Sender: TObject);
begin
  if FCurrentPage > 1 then
  begin
    Dec(FCurrentPage);
    UpdateUnifiedList;
    AdjustWindowSize;
    if ListBoxClips.Items.Count > 0 then
    begin
      ListBoxClips.ItemIndex := 0;
      ListBoxClips.SetFocus;
    end;
  end;
end;

procedure THistoryPopupForm.LabelBtnNextClick(Sender: TObject);
begin
  if FCurrentPage < FTotalPages then
  begin
    Inc(FCurrentPage);
    UpdateUnifiedList;
    AdjustWindowSize;
    if ListBoxClips.Items.Count > 0 then
    begin
      ListBoxClips.ItemIndex := 0;
      ListBoxClips.SetFocus;
    end;
  end;
end;

procedure THistoryPopupForm.FormDeactivate(Sender: TObject);
begin
  if not FPinned and not FIsManualResizing and not FIsEditingFav then
  begin
    HidePreview;
    Self.Hide;
  end;
end;

procedure THistoryPopupForm.BtnPinClick(Sender: TObject);
begin
  FPinned := not FPinned;
  BtnPin.Font.Name := 'Segoe UI Symbol';
  BtnPin.Caption := '📌';
  if FPinned then
    BtnPin.Font.Color := RGB(60, 140, 240)
  else if Assigned(ThemeManager) then
    BtnPin.Font.Color := ThemeManager.Theme.HistoryTextColor
  else
    BtnPin.Font.Color := RGB(160, 165, 175);
end;

procedure THistoryPopupForm.BtnSettingsClick(Sender: TObject);
begin
  if Assigned(MainForm) then
    MainForm.MenuShowSettingsClick(Sender);
end;

procedure THistoryPopupForm.BtnCloseClick(Sender: TObject);
begin
  HidePreview;
  Self.Hide;
end;

end.
