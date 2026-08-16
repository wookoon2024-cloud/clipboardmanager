unit uQuickBarForm;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants,
  System.Classes, System.IOUtils, Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs,
  Vcl.ExtCtrls, Vcl.StdCtrls, Vcl.Buttons, Vcl.Menus, Vcl.Imaging.pngimage, Vcl.Imaging.jpeg,
  uLog, uDatabase, Vcl.Clipbrd;

type
  TQuickBarForm = class(TForm)
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
  private
    FPanels: array[0..8] of TPanel;
    FLabels: array[0..8] of TLabel;
    FNumericLabels: array[0..8] of TLabel;
    FPinLabels: array[0..8] of TLabel;
    FImages: array[0..8] of TImage;
    FRecords: TArray<TClipRecord>;
    
    FPanelGuide: TPanel;
    FLGuideTitle: TLabel;
    FLGuideKey: TLabel;
    FBtnPin: TSpeedButton;
    FBtnClose: TSpeedButton;
    FPinned: Boolean;
    
    // 우클릭 컨텍스트 메뉴
    FPopupMenuClip: TPopupMenu;
    FMenuPin: TMenuItem;
    FMenuDelete: TMenuItem;
    FContextTargetIdx: Integer;
    
    procedure CreateQuickItems;
    procedure QuickItemClick(Sender: TObject);
    procedure QuickItemMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure QuickItemMouseEnter(Sender: TObject);
    procedure QuickItemMouseLeave(Sender: TObject);
    
    procedure MenuPinClick(Sender: TObject);
    procedure MenuDeleteClick(Sender: TObject);
    
    procedure BtnPinClick(Sender: TObject);
    procedure BtnCloseClick(Sender: TObject);
    function GetTaskbarTop: Integer;
  protected
    procedure CreateParams(var Params: TCreateParams); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure ShowBar;
    procedure HideBar;
    procedure ToggleVisibility;
    procedure RefreshAndShow;
    procedure UpdateItems;
    procedure PasteItem(AIndex: Integer);
    procedure UpdatePos;
    procedure ApplyTheme;
    property Pinned: Boolean read FPinned;
  end;

var
  QuickBarForm: TQuickBarForm;

implementation

uses
  uMainForm, uWindowSwitcherForm, uHistoryPopupForm, uThemeManager;

{$R *.dfm}

constructor TQuickBarForm.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FPinned := True;
  FContextTargetIdx := -1;
end;

destructor TQuickBarForm.Destroy;
begin
  inherited Destroy;
end;

procedure TQuickBarForm.CreateParams(var Params: TCreateParams);
begin
  inherited CreateParams(Params);
  Params.ExStyle := (Params.ExStyle or WS_EX_NOACTIVATE or WS_EX_TOPMOST or WS_EX_TOOLWINDOW) and not WS_EX_APPWINDOW;
  Params.WndParent := GetDesktopWindow;
end;

procedure TQuickBarForm.FormCreate(Sender: TObject);
begin
  Self.AlphaBlend := True;
  Self.AlphaBlendValue := 225;
  Self.Color := RGB(33, 36, 42);
  Self.BorderStyle := bsNone;
  Self.DoubleBuffered := True;
  
  Self.Left := 0;
  Self.Width := Screen.Width;
  Self.Height := 44;
  
  CreateQuickItems;
  ApplyTheme;
  Self.Visible := False;
end;

procedure TQuickBarForm.FormDestroy(Sender: TObject);
begin
end;

procedure TQuickBarForm.ApplyTheme;
var
  I: Integer;
  LStyle: Integer;
  LRgn: HRGN;
begin
  if not Assigned(ThemeManager) then Exit;
  
  LStyle := ThemeManager.Theme.DesignStyle;
  Self.Color := ThemeManager.Theme.QuickBarBgColor;
  
  if Assigned(FPanelGuide) then
  begin
    FPanelGuide.Color := ThemeManager.Theme.QuickCardGuideBgColor;
    FPanelGuide.BorderStyle := bsNone;
    if LStyle = 0 then // 0: 모던 네온 라운드 (기본)
    begin
      LRgn := CreateRoundRectRgn(0, 0, FPanelGuide.Width, FPanelGuide.Height, 8, 8);
      SetWindowRgn(FPanelGuide.Handle, LRgn, True);
    end
    else // 1: 클래식 플랫
    begin
      SetWindowRgn(FPanelGuide.Handle, 0, True);
    end;
  end;
    
  if Assigned(FLGuideTitle) then
    FLGuideTitle.Font.Color := ThemeManager.Theme.QuickCardNumColor;
  if Assigned(FLGuideKey) then
    FLGuideKey.Font.Color := ThemeManager.Theme.QuickCardTextColor;
    
  for I := 0 to 8 do
  begin
    if Assigned(FPanels[I]) then
    begin
      FPanels[I].Color := ThemeManager.Theme.QuickCardBgColor;
      FPanels[I].BorderStyle := bsNone;
      if LStyle = 0 then // 0: 모던 네온 라운드 (기본)
      begin
        LRgn := CreateRoundRectRgn(0, 0, FPanels[I].Width, FPanels[I].Height, 8, 8);
        SetWindowRgn(FPanels[I].Handle, LRgn, True);
      end
      else // 1: 클래식 플랫
      begin
        SetWindowRgn(FPanels[I].Handle, 0, True);
      end;
    end;
    
    if Assigned(FNumericLabels[I]) then
    begin
      FNumericLabels[I].Font.Color := ThemeManager.Theme.QuickCardNumColor;
      if LStyle = 0 then // 0: 모던 네온 라운드 (숫자 볼드 강조)
        FNumericLabels[I].Font.Style := [fsBold]
      else // 1: 클래식 플랫
        FNumericLabels[I].Font.Style := [];
    end;
    
    if Assigned(FLabels[I]) then
      FLabels[I].Font.Color := ThemeManager.Theme.QuickCardTextColor;
  end;
end;

procedure TQuickBarForm.CreateQuickItems;
var
  I: Integer;
  LPanel: TPanel;
  LLabelNum: TLabel;
  LLabelText: TLabel;
  LPinLabel: TLabel;
  LImage: TImage;
  LItemWidth: Integer;
  LStartX: Integer;
begin
  LItemWidth := 140;
  
  // 1. 우클릭 팝업 메뉴 생성
  FPopupMenuClip := TPopupMenu.Create(Self);
  
  FMenuPin := TMenuItem.Create(FPopupMenuClip);
  FMenuPin.Caption := '상단 고정';
  FMenuPin.OnClick := MenuPinClick;
  FPopupMenuClip.Items.Add(FMenuPin);
  
  FMenuDelete := TMenuItem.Create(FPopupMenuClip);
  FMenuDelete.Caption := '삭제';
  FMenuDelete.OnClick := MenuDeleteClick;
  FPopupMenuClip.Items.Add(FMenuDelete);
  
  // 2. 좌측 안내 뱃지
  FPanelGuide := TPanel.Create(Self);
  FPanelGuide.Parent := Self;
  FPanelGuide.SetBounds(8, 4, 88, 36);
  FPanelGuide.Color := RGB(42, 46, 54);
  FPanelGuide.ParentBackground := False;
  FPanelGuide.BevelOuter := bvNone;
  
  FLGuideTitle := TLabel.Create(Self);
  FLGuideTitle.Parent := FPanelGuide;
  FLGuideTitle.Align := alTop;
  FLGuideTitle.Alignment := taCenter;
  FLGuideTitle.Caption := '클립보드';
  FLGuideTitle.Font.Name := 'Segoe UI';
  FLGuideTitle.Font.Color := RGB(180, 190, 205);
  FLGuideTitle.Font.Size := 8;
  FLGuideTitle.Font.Style := [];
  FLGuideTitle.Transparent := True;
  
  FLGuideKey := TLabel.Create(Self);
  FLGuideKey.Parent := FPanelGuide;
  FLGuideKey.Align := alClient;
  FLGuideKey.Alignment := taCenter;
  FLGuideKey.Layout := tlCenter;
  FLGuideKey.Caption := 'Ctrl + 1~9';
  FLGuideKey.Font.Name := 'Segoe UI';
  FLGuideKey.Font.Color := RGB(220, 225, 235);
  FLGuideKey.Font.Size := 8;
  FLGuideKey.Font.Style := [];
  FLGuideKey.Transparent := True;
  
  LStartX := 104;
  
  // 3. 1~9번 클립보드 슬롯 카드 생성 (스위치 퀵바와 동일한 타이포그래피)
  for I := 0 to 8 do
  begin
    LPanel := TPanel.Create(Self);
    LPanel.Parent := Self;
    LPanel.SetBounds(LStartX + (I * (LItemWidth + 5)), 4, LItemWidth, 36);
    LPanel.Color := RGB(46, 50, 58);
    LPanel.ParentBackground := False;
    LPanel.BevelOuter := bvNone;
    LPanel.Tag := I;
    LPanel.Cursor := crHandPoint;
    LPanel.OnClick := QuickItemClick;
    LPanel.OnMouseDown := QuickItemMouseDown;
    LPanel.OnMouseEnter := QuickItemMouseEnter;
    LPanel.OnMouseLeave := QuickItemMouseLeave;
    FPanels[I] := LPanel;
    
    // 번호 (1..9)
    LLabelNum := TLabel.Create(Self);
    LLabelNum.Parent := LPanel;
    LLabelNum.SetBounds(6, 3, 16, 14);
    LLabelNum.Caption := IntToStr(I + 1);
    LLabelNum.Font.Name := 'Segoe UI';
    LLabelNum.Font.Color := RGB(150, 165, 185);
    LLabelNum.Font.Size := 8;
    LLabelNum.Font.Style := [];
    LLabelNum.Transparent := True;
    LLabelNum.Tag := I;
    LLabelNum.Cursor := crHandPoint;
    LLabelNum.OnClick := QuickItemClick;
    LLabelNum.OnMouseDown := QuickItemMouseDown;
    LLabelNum.OnMouseEnter := QuickItemMouseEnter;
    LLabelNum.OnMouseLeave := QuickItemMouseLeave;
    FNumericLabels[I] := LLabelNum;
    
    // 상단 고정 미니 표시 (스위치 퀵바와 동일한 모던 블루 도트 ●)
    LPinLabel := TLabel.Create(Self);
    LPinLabel.Parent := LPanel;
    LPinLabel.Caption := '●';
    LPinLabel.Font.Name := 'Segoe UI';
    LPinLabel.Font.Size := 7;
    LPinLabel.Font.Color := RGB(140, 185, 240);
    LPinLabel.Font.Style := [];
    LPinLabel.SetBounds(LItemWidth - 20, 3, 14, 14);
    LPinLabel.Visible := False;
    LPinLabel.Tag := I;
    LPinLabel.Cursor := crHandPoint;
    LPinLabel.OnClick := QuickItemClick;
    LPinLabel.OnMouseDown := QuickItemMouseDown;
    LPinLabel.OnMouseEnter := QuickItemMouseEnter;
    LPinLabel.OnMouseLeave := QuickItemMouseLeave;
    FPinLabels[I] := LPinLabel;
    
    // 이미지 썸네일
    LImage := TImage.Create(Self);
    LImage.Parent := LPanel;
    LImage.SetBounds(22, 3, 14, 14);
    LImage.Proportional := True;
    LImage.Stretch := True;
    LImage.Center := True;
    LImage.Visible := False;
    LImage.Tag := I;
    LImage.Cursor := crHandPoint;
    LImage.OnClick := QuickItemClick;
    LImage.OnMouseDown := QuickItemMouseDown;
    LImage.OnMouseEnter := QuickItemMouseEnter;
    LImage.OnMouseLeave := QuickItemMouseLeave;
    FImages[I] := LImage;
    
    // 텍스트 내용 라벨 (가운데 정렬 및 말줄임표 없이 클리핑)
    LLabelText := TLabel.Create(Self);
    LLabelText.Parent := LPanel;
    LLabelText.SetBounds(4, 17, LItemWidth - 8, 16);
    LLabelText.AutoSize := False;
    LLabelText.Caption := '';
    LLabelText.Font.Name := 'Segoe UI';
    LLabelText.Font.Color := RGB(225, 230, 238);
    LLabelText.Font.Size := 8;
    LLabelText.Font.Style := [];
    LLabelText.Transparent := True;
    LLabelText.ShowAccelChar := False;
    LLabelText.Alignment := taCenter;
    LLabelText.EllipsisPosition := epNone;
    LLabelText.Tag := I;
    LLabelText.Cursor := crHandPoint;
    LLabelText.OnClick := QuickItemClick;
    LLabelText.OnMouseDown := QuickItemMouseDown;
    LLabelText.OnMouseEnter := QuickItemMouseEnter;
    LLabelText.OnMouseLeave := QuickItemMouseLeave;
    FLabels[I] := LLabelText;
  end;
  
  // 4. 고정 핀 버튼
  FBtnPin := TSpeedButton.Create(Self);
  FBtnPin.Parent := Self;
  FBtnPin.SetBounds(Screen.Width - 72, 4, 32, 36);
  FBtnPin.Flat := True;
  FBtnPin.Font.Name := 'Segoe UI Symbol';
  FBtnPin.Font.Size := 10;
  FBtnPin.Caption := '📌';
  FBtnPin.Font.Color := RGB(140, 185, 240);
  FBtnPin.Cursor := crHandPoint;
  FBtnPin.OnClick := BtnPinClick;
  
  // 5. 닫기 버튼
  FBtnClose := TSpeedButton.Create(Self);
  FBtnClose.Parent := Self;
  FBtnClose.SetBounds(Screen.Width - 36, 4, 30, 36);
  FBtnClose.Flat := True;
  FBtnClose.Font.Name := 'Segoe UI Symbol';
  FBtnClose.Font.Size := 10;
  FBtnClose.Caption := '✕';
  FBtnClose.Font.Color := RGB(180, 185, 195);
  FBtnClose.Cursor := crHandPoint;
  FBtnClose.OnClick := BtnCloseClick;
end;

function TQuickBarForm.GetTaskbarTop: Integer;
var
  HTray: HWND;
  R: TRect;
begin
  HTray := FindWindow('Shell_TrayWnd', nil);
  if (HTray <> 0) and GetWindowRect(HTray, R) and (R.Top > 100) then
    Result := R.Top
  else
    Result := Screen.Height - 48;
end;

procedure TQuickBarForm.UpdatePos;
var
  LTaskbarTop: Integer;
begin
  LTaskbarTop := GetTaskbarTop;
  Self.Left := 0;
  Self.Width := Screen.Width;
  Self.Height := 44;
  Self.Top := LTaskbarTop - 44;
  
  if HandleAllocated and Self.Visible then
  begin
    SetWindowPos(Self.Handle, HWND_TOPMOST, Self.Left, Self.Top, Self.Width, Self.Height, SWP_NOACTIVATE or SWP_SHOWWINDOW);
    BringWindowToTop(Self.Handle);
  end;
end;

function FitTextToWidth(ACanvas: TCanvas; const AText: string; AMaxWidth: Integer): string;
var
  LStr: string;
begin
  LStr := AText;
  if (AMaxWidth <= 0) or (LStr = '') then Exit('');
  
  ACanvas.Font.Name := 'Segoe UI';
  ACanvas.Font.Size := 8;
  ACanvas.Font.Style := [];
  
  while (Length(LStr) > 0) and (ACanvas.TextWidth(LStr) > AMaxWidth) do
  begin
    Delete(LStr, Length(LStr), 1);
  end;
  Result := LStr;
end;

procedure TQuickBarForm.UpdateItems;
var
  I: Integer;
  LVal, LImgFile: string;
  LImgDir: string;
  LItemWidth: Integer;
  LTotal: Integer;
begin
  if not Assigned(DBManager) then Exit;
  
  // 상단 고정(is_pinned = 1) 항목을 최우선으로 9개 로드
  DBManager.GetPagedClipRecords(1, 9, FRecords, LTotal);
  LItemWidth := 140;
  
  LImgDir := TPath.Combine(ExtractFilePath(ParamStr(0)), 'Images');
  
  if Assigned(ThemeManager) then
  begin
    FPanelGuide.Color := ThemeManager.Theme.QuickCardGuideBgColor;
    FLGuideTitle.Font.Color := ThemeManager.Theme.QuickCardNumColor;
    FLGuideKey.Font.Color := ThemeManager.Theme.QuickCardTextColor;
  end;
  
  for I := 0 to 8 do
  begin
    if I < Length(FRecords) then
    begin
      // 상단 고정 핀 표시
      FPinLabels[I].Visible := FRecords[I].IsPinned;
      
      if FRecords[I].ClipType = 'IMAGE' then
      begin
        LImgFile := Trim(FRecords[I].Content);
        if (LImgFile <> '') and TFile.Exists(TPath.Combine(LImgDir, LImgFile)) then
        begin
          try
            FImages[I].Picture.LoadFromFile(TPath.Combine(LImgDir, LImgFile));
            FImages[I].SetBounds(6, 16, LItemWidth - 12, 17);
            FImages[I].Visible := True;
          except
            FImages[I].Visible := False;
          end;
        end
        else
          FImages[I].Visible := False;
          
        FLabels[I].Caption := '';
        FLabels[I].Visible := False;
      end
      else
      begin
        FImages[I].Visible := False;
        FLabels[I].Visible := True;
        FLabels[I].SetBounds(4, 17, LItemWidth - 8, 16);
        
        if Trim(FRecords[I].Title) <> '' then
          LVal := FRecords[I].Title
        else
          LVal := FRecords[I].Content;
          
        LVal := StringReplace(StringReplace(StringReplace(LVal, #13#10, ' ', [rfReplaceAll]), #10, ' ', [rfReplaceAll]), #9, ' ', [rfReplaceAll]);
        FLabels[I].Caption := FitTextToWidth(Self.Canvas, Trim(LVal), FLabels[I].Width);
        if Assigned(ThemeManager) then
          FLabels[I].Font.Color := ThemeManager.Theme.QuickCardTextColor
        else
          FLabels[I].Font.Color := RGB(225, 230, 238);
      end;
      
      if Assigned(ThemeManager) then
        FPanels[I].Color := ThemeManager.Theme.QuickCardBgColor
      else
        FPanels[I].Color := RGB(46, 50, 58);
      FPanels[I].Enabled := True;
    end
    else
    begin
      FPinLabels[I].Visible := False;
      FImages[I].Visible := False;
      FLabels[I].SetBounds(6, 17, LItemWidth - 12, 16);
      FLabels[I].Caption := '(빈 슬롯)';
      FLabels[I].Font.Color := RGB(105, 115, 128);
      if Assigned(ThemeManager) then
        FPanels[I].Color := ThemeManager.Theme.QuickBarBgColor
      else
        FPanels[I].Color := RGB(38, 41, 48);
      FPanels[I].Enabled := False;
    end;
  end;
end;

procedure TQuickBarForm.QuickItemMouseEnter(Sender: TObject);
var
  LPanel: TPanel;
begin
  if Sender is TPanel then
    LPanel := TPanel(Sender)
  else if (Sender is TControl) and (TControl(Sender).Parent is TPanel) then
    LPanel := TPanel(TControl(Sender).Parent)
  else
    Exit;
    
  if Assigned(ThemeManager) then
    LPanel.Color := ThemeManager.Theme.QuickCardActiveBgColor
  else
    LPanel.Color := RGB(60, 66, 76);
end;

procedure TQuickBarForm.QuickItemMouseLeave(Sender: TObject);
var
  LPanel: TPanel;
begin
  if Sender is TPanel then
    LPanel := TPanel(Sender)
  else if (Sender is TControl) and (TControl(Sender).Parent is TPanel) then
    LPanel := TPanel(TControl(Sender).Parent)
  else
    Exit;
    
  if Assigned(ThemeManager) then
    LPanel.Color := ThemeManager.Theme.QuickCardBgColor
  else
    LPanel.Color := RGB(46, 50, 58);
end;

procedure TQuickBarForm.QuickItemClick(Sender: TObject);
var
  LIdx: Integer;
begin
  if Sender is TComponent then
  begin
    LIdx := TComponent(Sender).Tag;
    PasteItem(LIdx);
  end;
end;

procedure TQuickBarForm.QuickItemMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  LIdx: Integer;
  LPoint: TPoint;
begin
  if (Button = mbRight) and (Sender is TComponent) then
  begin
    LIdx := TComponent(Sender).Tag;
    if (LIdx >= 0) and (LIdx < Length(FRecords)) then
    begin
      FContextTargetIdx := LIdx;
      
      if FRecords[LIdx].IsPinned then
        FMenuPin.Caption := '상단 고정 해제'
      else
        FMenuPin.Caption := '상단 고정';
        
      GetCursorPos(LPoint);
      FPopupMenuClip.Popup(LPoint.X, LPoint.Y);
    end;
  end;
end;

procedure TQuickBarForm.MenuPinClick(Sender: TObject);
begin
  if (FContextTargetIdx >= 0) and (FContextTargetIdx < Length(FRecords)) and Assigned(DBManager) then
  begin
    DBManager.TogglePinClip(FRecords[FContextTargetIdx].ID);
    UpdateItems;
    
    if Assigned(HistoryPopupForm) and HistoryPopupForm.Visible then
      HistoryPopupForm.UpdateDataOnly;
  end;
end;

procedure TQuickBarForm.MenuDeleteClick(Sender: TObject);
begin
  if (FContextTargetIdx >= 0) and (FContextTargetIdx < Length(FRecords)) and Assigned(DBManager) then
  begin
    DBManager.DeleteClip(FRecords[FContextTargetIdx].ID);
    UpdateItems;
    
    if Assigned(HistoryPopupForm) and HistoryPopupForm.Visible then
      HistoryPopupForm.UpdateDataOnly;
  end;
end;

procedure TQuickBarForm.PasteItem(AIndex: Integer);
begin
  if not FPinned then
    HideBar;
    
  if Assigned(MainForm) then
    MainForm.DirectPaste(AIndex);
end;

procedure TQuickBarForm.BtnPinClick(Sender: TObject);
begin
  FPinned := not FPinned;
  if FPinned then
    FBtnPin.Font.Color := RGB(140, 185, 240)
  else
    FBtnPin.Font.Color := RGB(160, 165, 175);
    
  SetWindowPos(Self.Handle, HWND_TOPMOST, Self.Left, Self.Top, Self.Width, Self.Height, SWP_SHOWWINDOW or SWP_NOACTIVATE);
  BringWindowToTop(Self.Handle);
  UpdateAppWorkArea;
end;

procedure TQuickBarForm.BtnCloseClick(Sender: TObject);
begin
  HideBar;
end;

procedure TQuickBarForm.ShowBar;
begin
  ApplyTheme;
  if Assigned(DBManager) then
  begin
    Self.AlphaBlendValue := StrToIntDef(DBManager.GetSetting('QuickBarAlpha', '225'), 225);
    Self.AlphaBlend := (Self.AlphaBlendValue < 255);
  end;
  
  UpdateItems;
  UpdatePos;
  Self.Visible := True;
  SetWindowPos(Self.Handle, HWND_TOPMOST, Self.Left, Self.Top, Self.Width, Self.Height, SWP_SHOWWINDOW or SWP_NOACTIVATE);
  BringWindowToTop(Self.Handle);
  
  if Assigned(WindowSwitcherForm) and WindowSwitcherForm.Visible then
    WindowSwitcherForm.UpdatePos;
    
  UpdateAppWorkArea;
  
  if Assigned(DBManager) then
    DBManager.SaveSetting('QuickBarVisible', '1');
end;

procedure TQuickBarForm.HideBar;
begin
  Self.Visible := False;
  ShowWindow(Self.Handle, SW_HIDE);
  
  if Assigned(WindowSwitcherForm) and WindowSwitcherForm.Visible then
    WindowSwitcherForm.UpdatePos;
    
  UpdateAppWorkArea;
  
  if Assigned(DBManager) then
    DBManager.SaveSetting('QuickBarVisible', '0');
end;

procedure TQuickBarForm.RefreshAndShow;
begin
  ShowBar;
end;

procedure TQuickBarForm.ToggleVisibility;
begin
  if Self.Visible then
    HideBar
  else
    ShowBar;
end;

end.
