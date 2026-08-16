unit uWindowSwitcherForm;

{$R-,Q-} // Range check 및 Overflow check 해제로 WinAPI 핸들 연산 안전 보장

interface

uses
  Winapi.Windows, Winapi.Messages, Winapi.ShellAPI, Winapi.PsAPI, Winapi.ShlObj, Winapi.ActiveX,
  System.SysUtils, System.Variants, System.Classes, System.Types, System.JSON, System.IOUtils, System.NetEncoding,
  System.Generics.Collections,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.ExtCtrls, Vcl.StdCtrls, Vcl.Buttons, Vcl.Menus, uLog;

type
  TAppWindowInfo = record
    HWnd: HWND;
    Title: string;
    IconHandle: HICON;
    IsPinned: Boolean;
  end;

  TWindowSwitcherForm = class(TForm)
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure FormDeactivate(Sender: TObject);
  private
    FWindows: TArray<TAppWindowInfo>;
    
    // 고정 9개 슬롯 컨트롤 (재사용 - 절대로 Free하지 않아 깜빡임 0%)
    FPanels: array[0..8] of TPanel;
    FNumericLabels: array[0..8] of TLabel;
    FTitles: array[0..8] of TLabel;
    FImages: array[0..8] of TImage;
    FPinIcons: array[0..8] of TLabel;
    
    FPanelGuide: TPanel;
    FLStaticGuideTitle: TLabel;
    FLStaticGuideKey: TLabel;
    FBtnPresets: array[1..3] of TSpeedButton;
    FBtnPin: TSpeedButton;
    FBtnClose: TSpeedButton;
    FPinned: Boolean;
    
    FPinnedHWnds: TList;
    FPopupCard: TPopupMenu;
    FMenuTogglePin: TMenuItem;
    FMenuCloseWindow: TMenuItem;
    FContextTargetIdx: Integer;
    
    // 바탕 우클릭 작업공간 프리셋 저장 팝업
    FPopupBar: TPopupMenu;
    FMenuSavePreset: TMenuItem;
    FMenuSaveSlot1: TMenuItem;
    FMenuSaveSlot2: TMenuItem;
    FMenuSaveSlot3: TMenuItem;
    FMenuClearPreset: TMenuItem;
    FMenuClearSlot1: TMenuItem;
    FMenuClearSlot2: TMenuItem;
    FMenuClearSlot3: TMenuItem;
    FMenuSepSettings: TMenuItem;
    FMenuSettings: TMenuItem;
    
    FTargetPID: DWORD;
    FTargetExeName: string;
    FLastActiveHWnd: HWND;
    FTimerWatch: TTimer;
    FFullScreenHidden: Boolean;
    FOverflowActive: Boolean;
    
    procedure CreateStaticControls;
    function GetProcessExeName(APID: DWORD): string;
    function GetProcessFullExePath(APID: DWORD): string;
    function GetWindowAppIcon(AHWnd: HWND): HICON;
    function GetRootWindow(AHWnd: HWND): HWND;
    function IsSystemShellWindow(AHWnd: HWND): Boolean;
    function IsForegroundWindowFullScreen: Boolean;
    function HasWindowsChanged: Boolean;
    function IsHWndPinned(AHWnd: HWND): Boolean;
    procedure TogglePinWindow(AHWnd: HWND);
    
    procedure CollectWindowsForActiveApp;
    procedure UpdateWindowCards;
    procedure UpdateActiveCardHighlight(AForcedActiveHWnd: HWND = 0);
    procedure WindowCardClick(Sender: TObject);
    procedure WindowCardContextPopup(Sender: TObject; MousePos: TPoint; var Handled: Boolean);
    procedure MenuTogglePinClick(Sender: TObject);
    procedure MenuCloseWindowClick(Sender: TObject);
    
    procedure FormContextPopup(Sender: TObject; MousePos: TPoint; var Handled: Boolean);
    procedure BtnPresetClick(Sender: TObject);
    procedure MenuSaveSlotClick(Sender: TObject);
    procedure MenuClearSlotClick(Sender: TObject);
    procedure MenuSettingsClick(Sender: TObject);
    procedure SavePresetToSlot(ASlot: Integer);
    procedure LoadAndRestorePreset(ASlot: Integer);
    procedure UpdatePresetButtonStyles;
    function GetDocumentPathFromWindow(AHWnd: HWND; const ATitle, AExePath: string): string;
    function GetBrowserCurrentUrl(AHWnd: HWND; const ATitle, AExePath: string): string;
    function GetExplorerFolderPath(AHWnd: HWND; const ATitle: string): string;
    
    procedure WindowCardMouseEnter(Sender: TObject);
    procedure WindowCardMouseLeave(Sender: TObject);
    procedure SwitchToWindow(AHWnd: HWND);
    
    procedure BtnPinClick(Sender: TObject);
    procedure BtnCloseClick(Sender: TObject);
    procedure TimerWatchTimer(Sender: TObject);
    function GetTaskbarTop: Integer;
  protected
    procedure CreateParams(var Params: TCreateParams); override;
  public
    procedure ShowBar;
    procedure HideBar;
    procedure ToggleVisibility;
    procedure RefreshAndShow;
    procedure UpdatePos;
    procedure SwitchToWindowByIndex(AIndex: Integer);
    procedure ApplyTheme;
    property Pinned: Boolean read FPinned write FPinned;
  end;

var
  WindowSwitcherForm: TWindowSwitcherForm;

implementation

uses
  uQuickBarForm, uDatabase, uMainForm, uThemeManager;

{$R *.dfm}

const
  GCL_HICON_VAL = -14;
  GCL_HICONSM_VAL = -34;

type
  PEnumData = ^TEnumData;
  TEnumData = record
    TargetExeName: string;
    MyPID: DWORD;
    List: TList;
  end;

function EnumWindowsProc(AHWnd: HWND; lParam: LPARAM): BOOL; stdcall;
var
  LPData: PEnumData;
  LPID: DWORD;
  LTitleLen: Integer;
  LTitle: array[0..511] of Char;
  LExStyle, LStyle: LongInt;
  LProcHandle: THandle;
  LModName: array[0..MAX_PATH] of Char;
  LExeName: string;
begin
  Result := True;
  LPData := PEnumData(lParam);
  
  if not IsWindow(AHWnd) or (not IsWindowVisible(AHWnd) and not IsIconic(AHWnd)) then Exit;
  
  GetWindowThreadProcessId(AHWnd, LPID);
  if (LPID = LPData^.MyPID) or (LPID = 0) then Exit;
  
  LExStyle := GetWindowLong(AHWnd, GWL_EXSTYLE);
  if (LExStyle and WS_EX_TOOLWINDOW) <> 0 then Exit;
  
  LStyle := GetWindowLong(AHWnd, GWL_STYLE);
  if (LStyle and WS_CHILD) <> 0 then Exit;
  
  if GetWindow(AHWnd, GW_OWNER) <> 0 then Exit;
  
  LTitleLen := GetWindowText(AHWnd, LTitle, 512);
  if LTitleLen <= 0 then Exit;
  
  LExeName := '';
  LProcHandle := OpenProcess(PROCESS_QUERY_INFORMATION or PROCESS_VM_READ, False, LPID);
  if LProcHandle <> 0 then
  begin
    try
      if GetModuleFileNameEx(LProcHandle, 0, LModName, MAX_PATH) > 0 then
        LExeName := ExtractFileName(string(LModName));
    finally
      CloseHandle(LProcHandle);
    end;
  end;
  
  if SameText(LExeName, 'explorer.exe') then Exit;
  
  if (LPData^.TargetExeName = '') or SameText(LExeName, LPData^.TargetExeName) then
  begin
    LPData^.List.Add(Pointer(AHWnd));
  end;
end;

{ TWindowSwitcherForm }

procedure TWindowSwitcherForm.CreateParams(var Params: TCreateParams);
begin
  inherited CreateParams(Params);
  Params.ExStyle := (Params.ExStyle or WS_EX_NOACTIVATE or WS_EX_TOPMOST or WS_EX_TOOLWINDOW) and not WS_EX_APPWINDOW;
  Params.WndParent := GetDesktopWindow;
end;

procedure TWindowSwitcherForm.FormCreate(Sender: TObject);
begin
  Self.AlphaBlend := True;
  Self.AlphaBlendValue := 225;
  // 세련된 모던 슬레이트 그레이 배경
  Self.Color := RGB(33, 36, 42);
  Self.BorderStyle := bsNone;
  Self.KeyPreview := True;
  Self.DoubleBuffered := True;
  
  Self.Left := 0;
  Self.Width := Screen.Width;
  Self.Height := 44;
  
  FPinned := True;
  Self.Visible := False;
  
  FPinnedHWnds := TList.Create;
  FContextTargetIdx := -1;
  
  // 우클릭 팝업 메뉴 초기화 (이모지 제거)
  FPopupCard := TPopupMenu.Create(Self);
  
  FMenuTogglePin := TMenuItem.Create(FPopupCard);
  FMenuTogglePin.Caption := '창 고정';
  FMenuTogglePin.OnClick := MenuTogglePinClick;
  FPopupCard.Items.Add(FMenuTogglePin);
  
  FMenuCloseWindow := TMenuItem.Create(FPopupCard);
  FMenuCloseWindow.Caption := '창 닫기';
  FMenuCloseWindow.OnClick := MenuCloseWindowClick;
  FPopupCard.Items.Add(FMenuCloseWindow);
  
  CreateStaticControls;
  Self.OnContextPopup := FormContextPopup;
  
  FTimerWatch := TTimer.Create(Self);
  FTimerWatch.Interval := 200;
  FTimerWatch.OnTimer := TimerWatchTimer;
  FTimerWatch.Enabled := False;
  
  ApplyTheme;
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

procedure TWindowSwitcherForm.ApplyTheme;
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
    if LStyle = 0 then // 0: 모던 네온 라운드 (기본)
    begin
      LRgn := CreateRoundRectRgn(0, 0, FPanelGuide.Width, FPanelGuide.Height, 8, 8);
      SetWindowRgn(FPanelGuide.Handle, LRgn, True);
      FPanelGuide.BorderStyle := bsNone;
    end
    else if LStyle = 3 then // 3: 캡슐 미니멀
    begin
      LRgn := CreateRoundRectRgn(0, 0, FPanelGuide.Width, FPanelGuide.Height, 14, 14);
      SetWindowRgn(FPanelGuide.Handle, LRgn, True);
      FPanelGuide.BorderStyle := bsNone;
    end
    else
    begin
      SetWindowRgn(FPanelGuide.Handle, 0, True);
      if LStyle = 2 then // 2: 소프트 아크릴
        FPanelGuide.BorderStyle := bsSingle
      else // 1: 클래식 플랫
        FPanelGuide.BorderStyle := bsNone;
    end;
  end;
    
  if Assigned(FLStaticGuideTitle) then
    FLStaticGuideTitle.Font.Color := ThemeManager.Theme.QuickCardNumColor;
  if Assigned(FLStaticGuideKey) then
    FLStaticGuideKey.Font.Color := ThemeManager.Theme.QuickCardTextColor;
    
  for I := 0 to 8 do
  begin
    if Assigned(FPanels[I]) then
    begin
      FPanels[I].Color := ThemeManager.Theme.QuickCardBgColor;
      if LStyle = 0 then // 0: 모던 네온 라운드 (기본)
      begin
        LRgn := CreateRoundRectRgn(0, 0, FPanels[I].Width, FPanels[I].Height, 8, 8);
        SetWindowRgn(FPanels[I].Handle, LRgn, True);
        FPanels[I].BorderStyle := bsNone;
      end
      else if LStyle = 3 then // 3: 캡슐 미니멀
      begin
        LRgn := CreateRoundRectRgn(0, 0, FPanels[I].Width, FPanels[I].Height, 14, 14);
        SetWindowRgn(FPanels[I].Handle, LRgn, True);
        FPanels[I].BorderStyle := bsNone;
      end
      else
      begin
        SetWindowRgn(FPanels[I].Handle, 0, True);
        if LStyle = 2 then // 2: 소프트 아크릴
          FPanels[I].BorderStyle := bsSingle
        else // 1: 클래식 플랫
          FPanels[I].BorderStyle := bsNone;
      end;
    end;
    
    if Assigned(FNumericLabels[I]) then
    begin
      FNumericLabels[I].Font.Color := ThemeManager.Theme.QuickCardNumColor;
      if (LStyle = 0) or (LStyle = 3) then // 0: 모던 네온 라운드, 3: 캡슐 미니멀 (숫자 볼드 강조)
        FNumericLabels[I].Font.Style := [fsBold]
      else
        FNumericLabels[I].Font.Style := [];
    end;
    
    if Assigned(FTitles[I]) then
      FTitles[I].Font.Color := ThemeManager.Theme.QuickCardTextColor;
  end;
  
  UpdateActiveCardHighlight(FLastActiveHWnd);
  UpdatePresetButtonStyles;
end;

procedure TWindowSwitcherForm.FormDestroy(Sender: TObject);
begin
  FTimerWatch.Enabled := False;
  FPinnedHWnds.Free;
end;

procedure TWindowSwitcherForm.CreateStaticControls;
var
  I: Integer;
  LCardWidth, LStartX: Integer;
  LPanel: TPanel;
  LLabelNum, LLabelPinIcon: TLabel;
  LImage: TImage;
  LLabelTitle: TLabel;
begin
  LCardWidth := 140;
  LStartX := 102;
  
  // 1. 좌측 안내 배지 (이모지 없음, 레귤러 폰트)
  FPanelGuide := TPanel.Create(Self);
  FPanelGuide.Parent := Self;
  FPanelGuide.SetBounds(8, 4, 88, 36);
  FPanelGuide.Color := RGB(42, 46, 54);
  FPanelGuide.ParentBackground := False;
  FPanelGuide.BevelOuter := bvNone;
  
  FLStaticGuideTitle := TLabel.Create(Self);
  FLStaticGuideTitle.Parent := FPanelGuide;
  FLStaticGuideTitle.Align := alTop;
  FLStaticGuideTitle.Alignment := taCenter;
  FLStaticGuideTitle.Caption := '창전환';
  FLStaticGuideTitle.Font.Name := 'Segoe UI';
  FLStaticGuideTitle.Font.Color := RGB(180, 190, 205);
  FLStaticGuideTitle.Font.Size := 8;
  FLStaticGuideTitle.Font.Style := [];
  FLStaticGuideTitle.Transparent := True;
  
  FLStaticGuideKey := TLabel.Create(Self);
  FLStaticGuideKey.Parent := FPanelGuide;
  FLStaticGuideKey.Align := alClient;
  FLStaticGuideKey.Alignment := taCenter;
  FLStaticGuideKey.Layout := tlCenter;
  FLStaticGuideKey.Caption := 'Alt + 1~9';
  FLStaticGuideKey.Font.Name := 'Segoe UI';
  FLStaticGuideKey.Font.Color := RGB(220, 225, 235);
  FLStaticGuideKey.Font.Size := 8;
  FLStaticGuideKey.Font.Style := [];
  FLStaticGuideKey.Transparent := True;
  
  // 2. 9개 슬롯 카드 컨트롤 (모던 그레이 톤, 적절한 패딩, 볼드 제거)
  for I := 0 to 8 do
  begin
    LPanel := TPanel.Create(Self);
    LPanel.Parent := Self;
    LPanel.SetBounds(LStartX + (I * (LCardWidth + 5)), 4, LCardWidth, 36);
    LPanel.Color := RGB(46, 50, 58);
    LPanel.ParentBackground := False;
    LPanel.BevelOuter := bvNone;
    LPanel.Tag := I;
    LPanel.Cursor := crHandPoint;
    LPanel.OnClick := WindowCardClick;
    LPanel.OnContextPopup := WindowCardContextPopup;
    LPanel.OnMouseEnter := WindowCardMouseEnter;
    LPanel.OnMouseLeave := WindowCardMouseLeave;
    LPanel.Visible := False;
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
    LLabelNum.OnClick := WindowCardClick;
    LLabelNum.OnContextPopup := WindowCardContextPopup;
    FNumericLabels[I] := LLabelNum;
    
    // 아이콘 이미지
    LImage := TImage.Create(Self);
    LImage.Parent := LPanel;
    LImage.SetBounds(22, 3, 14, 14);
    LImage.Tag := I;
    LImage.OnClick := WindowCardClick;
    LImage.OnContextPopup := WindowCardContextPopup;
    LImage.Visible := False;
    FImages[I] := LImage;
    
    // 핀 고정 미니 표시 (간결한 텍스트 기호)
    LLabelPinIcon := TLabel.Create(Self);
    LLabelPinIcon.Parent := LPanel;
    LLabelPinIcon.SetBounds(LCardWidth - 20, 3, 14, 14);
    LLabelPinIcon.Caption := '●';
    LLabelPinIcon.Font.Name := 'Segoe UI';
    LLabelPinIcon.Font.Color := RGB(140, 185, 240);
    LLabelPinIcon.Font.Size := 7;
    LLabelPinIcon.Font.Style := [];
    LLabelPinIcon.Transparent := True;
    LLabelPinIcon.Tag := I;
    LLabelPinIcon.OnClick := WindowCardClick;
    LLabelPinIcon.OnContextPopup := WindowCardContextPopup;
    LLabelPinIcon.Visible := False;
    FPinIcons[I] := LLabelPinIcon;
    
    // 창 타이틀 라벨 (가운데 정렬 및 말줄임표 없이 클리핑)
    LLabelTitle := TLabel.Create(Self);
    LLabelTitle.Parent := LPanel;
    LLabelTitle.SetBounds(4, 17, LCardWidth - 8, 16);
    LLabelTitle.AutoSize := False;
    LLabelTitle.Caption := '';
    LLabelTitle.Font.Name := 'Segoe UI';
    LLabelTitle.Font.Color := RGB(225, 230, 238);
    LLabelTitle.Font.Size := 8;
    LLabelTitle.Font.Style := [];
    LLabelTitle.Transparent := True;
    LLabelTitle.Alignment := taCenter;
    LLabelTitle.EllipsisPosition := epNone;
    LLabelTitle.Tag := I;
    LLabelTitle.OnClick := WindowCardClick;
    LLabelTitle.OnContextPopup := WindowCardContextPopup;
    FTitles[I] := LLabelTitle;
  end;
  
  // 3. 우측 프리셋 버튼 1, 2, 3 (정사각형 크기 26x30)
  for I := 1 to 3 do
  begin
    FBtnPresets[I] := TSpeedButton.Create(Self);
    FBtnPresets[I].Parent := Self;
    // 1번: Screen.Width - 162, 2번: Screen.Width - 132, 3번: Screen.Width - 102
    FBtnPresets[I].SetBounds(Screen.Width - 192 + (I * 30), 7, 26, 30);
    FBtnPresets[I].Caption := IntToStr(I);
    FBtnPresets[I].Flat := True;
    FBtnPresets[I].Font.Name := 'Segoe UI';
    FBtnPresets[I].Font.Size := 9;
    FBtnPresets[I].Font.Style := [fsBold];
    FBtnPresets[I].Font.Color := RGB(150, 160, 175);
    FBtnPresets[I].Tag := I;
    FBtnPresets[I].OnClick := BtnPresetClick;
    FBtnPresets[I].ShowHint := True;
  end;
  
  // 4. 우측 핀 버튼
  FBtnPin := TSpeedButton.Create(Self);
  FBtnPin.Parent := Self;
  FBtnPin.SetBounds(Screen.Width - 72, 4, 32, 36);
  FBtnPin.Caption := '📌';
  FBtnPin.Flat := True;
  FBtnPin.Font.Name := 'Segoe UI Symbol';
  FBtnPin.Font.Color := RGB(140, 185, 240);
  FBtnPin.Font.Size := 10;
  FBtnPin.Font.Style := [];
  FBtnPin.OnClick := BtnPinClick;
  
  // 5. 우측 닫기 버튼
  FBtnClose := TSpeedButton.Create(Self);
  FBtnClose.Parent := Self;
  FBtnClose.SetBounds(Screen.Width - 36, 4, 30, 36);
  FBtnClose.Caption := '✕';
  FBtnClose.Flat := True;
  FBtnClose.Font.Name := 'Segoe UI Symbol';
  FBtnClose.Font.Color := RGB(180, 185, 195);
  FBtnClose.Font.Size := 10;
  FBtnClose.Font.Style := [];
  FBtnClose.OnClick := BtnCloseClick;
  
  // 6. 스위치바 바탕 우클릭 작업공간(세션) 팝업 메뉴
  FPopupBar := TPopupMenu.Create(Self);
  FPopupBar.AutoHotkeys := maManual;
  
  FMenuSavePreset := TMenuItem.Create(FPopupBar);
  FMenuSavePreset.AutoHotkeys := maManual;
  FMenuSavePreset.Caption := '현재 창 구성 저장';
  FPopupBar.Items.Add(FMenuSavePreset);
  
  FMenuSaveSlot1 := TMenuItem.Create(FPopupBar);
  FMenuSaveSlot1.AutoHotkeys := maManual;
  FMenuSaveSlot1.Caption := '1번에 저장';
  FMenuSaveSlot1.Tag := 1;
  FMenuSaveSlot1.OnClick := MenuSaveSlotClick;
  FMenuSavePreset.Add(FMenuSaveSlot1);
  
  FMenuSaveSlot2 := TMenuItem.Create(FPopupBar);
  FMenuSaveSlot2.AutoHotkeys := maManual;
  FMenuSaveSlot2.Caption := '2번에 저장';
  FMenuSaveSlot2.Tag := 2;
  FMenuSaveSlot2.OnClick := MenuSaveSlotClick;
  FMenuSavePreset.Add(FMenuSaveSlot2);
  
  FMenuSaveSlot3 := TMenuItem.Create(FPopupBar);
  FMenuSaveSlot3.AutoHotkeys := maManual;
  FMenuSaveSlot3.Caption := '3번에 저장';
  FMenuSaveSlot3.Tag := 3;
  FMenuSaveSlot3.OnClick := MenuSaveSlotClick;
  FMenuSavePreset.Add(FMenuSaveSlot3);
  
  FMenuClearPreset := TMenuItem.Create(FPopupBar);
  FMenuClearPreset.AutoHotkeys := maManual;
  FMenuClearPreset.Caption := '저장된 세션 초기화';
  FPopupBar.Items.Add(FMenuClearPreset);
  
  FMenuClearSlot1 := TMenuItem.Create(FPopupBar);
  FMenuClearSlot1.AutoHotkeys := maManual;
  FMenuClearSlot1.Caption := '1번 비우기';
  FMenuClearSlot1.Tag := 1;
  FMenuClearSlot1.OnClick := MenuClearSlotClick;
  FMenuClearPreset.Add(FMenuClearSlot1);
  
  FMenuClearSlot2 := TMenuItem.Create(FPopupBar);
  FMenuClearSlot2.AutoHotkeys := maManual;
  FMenuClearSlot2.Caption := '2번 비우기';
  FMenuClearSlot2.Tag := 2;
  FMenuClearSlot2.OnClick := MenuClearSlotClick;
  FMenuClearPreset.Add(FMenuClearSlot2);
  
  FMenuClearSlot3 := TMenuItem.Create(FPopupBar);
  FMenuClearSlot3.AutoHotkeys := maManual;
  FMenuClearSlot3.Caption := '3번 비우기';
  FMenuClearSlot3.Tag := 3;
  FMenuClearSlot3.OnClick := MenuClearSlotClick;
  FMenuClearPreset.Add(FMenuClearSlot3);
  
  FMenuSepSettings := TMenuItem.Create(FPopupBar);
  FMenuSepSettings.Caption := '-';
  FPopupBar.Items.Add(FMenuSepSettings);
  
  FMenuSettings := TMenuItem.Create(FPopupBar);
  FMenuSettings.Caption := '환경설정';
  FMenuSettings.OnClick := MenuSettingsClick;
  FPopupBar.Items.Add(FMenuSettings);
  
  UpdatePresetButtonStyles;
end;

function TWindowSwitcherForm.IsHWndPinned(AHWnd: HWND): Boolean;
var
  I: Integer;
  LRoot: HWND;
begin
  Result := False;
  LRoot := GetRootWindow(AHWnd);
  for I := 0 to FPinnedHWnds.Count - 1 do
  begin
    if GetRootWindow(HWND(FPinnedHWnds[I])) = LRoot then
    begin
      Result := True;
      Exit;
    end;
  end;
end;

procedure TWindowSwitcherForm.TogglePinWindow(AHWnd: HWND);
var
  I: Integer;
  LRoot: HWND;
  LFound: Boolean;
begin
  LRoot := GetRootWindow(AHWnd);
  if not IsWindow(LRoot) then Exit;
  
  LFound := False;
  for I := FPinnedHWnds.Count - 1 downto 0 do
  begin
    if GetRootWindow(HWND(FPinnedHWnds[I])) = LRoot then
    begin
      FPinnedHWnds.Delete(I);
      LFound := True;
    end;
  end;
  
  if not LFound then
  begin
    FPinnedHWnds.Add(Pointer(LRoot));
  end;
  
  UpdateWindowCards;
end;

function TWindowSwitcherForm.GetProcessFullExePath(APID: DWORD): string;
var
  LProcHandle: THandle;
  LBuf: array[0..MAX_PATH] of Char;
begin
  Result := '';
  if APID = 0 then Exit;
  LProcHandle := OpenProcess(PROCESS_QUERY_INFORMATION or PROCESS_VM_READ, False, APID);
  if LProcHandle <> 0 then
  begin
    try
      if GetModuleFileNameEx(LProcHandle, 0, LBuf, MAX_PATH) > 0 then
        Result := string(LBuf);
    finally
      CloseHandle(LProcHandle);
    end;
  end;
end;

procedure TWindowSwitcherForm.FormContextPopup(Sender: TObject; MousePos: TPoint; var Handled: Boolean);
var
  LScreenPos: TPoint;
begin
  LScreenPos := ClientToScreen(MousePos);
  SetForegroundWindow(Self.Handle);
  if Assigned(FPopupBar) then
    FPopupBar.Popup(LScreenPos.X, LScreenPos.Y);
  Handled := True;
end;

procedure TWindowSwitcherForm.BtnPresetClick(Sender: TObject);
var
  LSlot: Integer;
begin
  if Sender is TSpeedButton then
  begin
    LSlot := TSpeedButton(Sender).Tag;
    LoadAndRestorePreset(LSlot);
  end;
end;

procedure TWindowSwitcherForm.MenuSaveSlotClick(Sender: TObject);
var
  LSlot: Integer;
begin
  if Sender is TMenuItem then
  begin
    LSlot := TMenuItem(Sender).Tag;
    SavePresetToSlot(LSlot);
  end;
end;

procedure TWindowSwitcherForm.MenuClearSlotClick(Sender: TObject);
var
  LSlot: Integer;
begin
  if Sender is TMenuItem then
  begin
    LSlot := TMenuItem(Sender).Tag;
    if Assigned(DBManager) then
    begin
      DBManager.SaveSetting('WindowPreset_' + IntToStr(LSlot), '');
      UpdatePresetButtonStyles;
      ShowMessage(Format('작업 공간 %d번 슬롯이 초기화되었습니다.', [LSlot]));
    end;
  end;
end;

procedure TWindowSwitcherForm.MenuSettingsClick(Sender: TObject);
begin
  if Assigned(MainForm) then
  begin
    MainForm.Show;
    MainForm.WindowState := wsNormal;
    MainForm.BringToFront;
    SetForegroundWindow(MainForm.Handle);
  end;
end;

function TWindowSwitcherForm.GetDocumentPathFromWindow(AHWnd: HWND; const ATitle, AExePath: string): string;
var
  LExeName, LCleanTitle, LRecentDir: string;
  LFiles: TArray<string>;
  LFile, LTargetFile: string;
  LRecentPath: array[0..MAX_PATH] of Char;
begin
  Result := '';
  LExeName := ExtractFileName(AExePath).ToLower;
  
  // 1. 타이틀에 이미 절대 경로가 포함된 경우
  if (Pos(':\', ATitle) > 0) or (Pos(':/', ATitle) > 0) then
  begin
    LCleanTitle := Trim(ATitle);
    if Pos(' - ', LCleanTitle) > 0 then
      LCleanTitle := Trim(Copy(LCleanTitle, 1, Pos(' - ', LCleanTitle) - 1));
    if FileExists(LCleanTitle) then
    begin
      Result := LCleanTitle;
      Exit;
    end;
  end;
  
  // 2. 문서/오피스 타이틀 파싱
  LCleanTitle := Trim(ATitle);
  if (LCleanTitle <> '') and (LCleanTitle[1] = '*') then
    LCleanTitle := Trim(Copy(LCleanTitle, 2, MaxInt));
    
  if Pos(' - ', LCleanTitle) > 0 then
    LCleanTitle := Trim(Copy(LCleanTitle, 1, Pos(' - ', LCleanTitle) - 1));
    
  if LCleanTitle = '' then Exit;
  
  // 3. Windows Recent 폴더에서 일치하는 실제 파일 조회
  if Succeeded(SHGetFolderPath(0, CSIDL_RECENT, 0, SHGFP_TYPE_CURRENT, LRecentPath)) then
  begin
    LRecentDir := string(LRecentPath);
    if DirectoryExists(LRecentDir) then
    begin
      try
        LFiles := TDirectory.GetFiles(LRecentDir, '*' + LCleanTitle + '*');
        for LFile in LFiles do
        begin
          LTargetFile := ChangeFileExt(LFile, '');
          if FileExists(LTargetFile) then
          begin
            Result := LTargetFile;
            Exit;
          end;
        end;
      except
      end;
    end;
  end;
  
  // 4. 일반 Documents / Desktop / Downloads 폴더 조회
  try
    LTargetFile := TPath.Combine(TPath.GetDocumentsPath, LCleanTitle);
    if FileExists(LTargetFile) then
    begin
      Result := LTargetFile;
      Exit;
    end;
    
    if Succeeded(SHGetFolderPath(0, CSIDL_DESKTOPDIRECTORY, 0, SHGFP_TYPE_CURRENT, LRecentPath)) then
    begin
      LTargetFile := TPath.Combine(string(LRecentPath), LCleanTitle);
      if FileExists(LTargetFile) then
      begin
        Result := LTargetFile;
        Exit;
      end;
    end;
    
    if Succeeded(SHGetFolderPath(0, CSIDL_PROFILE, 0, SHGFP_TYPE_CURRENT, LRecentPath)) then
    begin
      LTargetFile := TPath.Combine(TPath.Combine(string(LRecentPath), 'Downloads'), LCleanTitle);
      if FileExists(LTargetFile) then
      begin
        Result := LTargetFile;
        Exit;
      end;
    end;
  except
  end;
end;

type
  PFindUrlData = ^TFindUrlData;
  TFindUrlData = record
    FoundUrl: string;
  end;

function EnumBrowserChildForUrl(AHWnd: HWND; lParam: LPARAM): BOOL; stdcall;
var
  LBuf: array[0..1024] of Char;
  LText: string;
  LPData: PFindUrlData;
begin
  Result := True;
  LPData := PFindUrlData(lParam);
  
  if GetWindowText(AHWnd, LBuf, 1024) > 0 then
  begin
    LText := Trim(string(LBuf));
    if (Pos('http://', LText) = 1) or (Pos('https://', LText) = 1) or 
       ((Pos('.', LText) > 0) and (Pos(' ', LText) = 0) and ((Pos('.com', LText) > 0) or (Pos('.kr', LText) > 0) or (Pos('.net', LText) > 0))) then
    begin
      if (Pos('http://', LText) <> 1) and (Pos('https://', LText) <> 1) then
        LText := 'https://' + LText;
      LPData^.FoundUrl := LText;
      Result := False; // 찾음!
    end;
  end;
end;

function TWindowSwitcherForm.GetBrowserCurrentUrl(AHWnd: HWND; const ATitle, AExePath: string): string;
var
  LExeName, LCleanTitle: string;
  LUrlData: TFindUrlData;
begin
  Result := '';
  LExeName := ExtractFileName(AExePath).ToLower;
  
  if (Pos('chrome', LExeName) = 0) and (Pos('msedge', LExeName) = 0) and 
     (Pos('whale', LExeName) = 0) and (Pos('brave', LExeName) = 0) and 
     (Pos('firefox', LExeName) = 0) then Exit;
     
  // 1. 하위 컨트롤에서 실제 주소창 텍스트 탐색
  LUrlData.FoundUrl := '';
  EnumChildWindows(AHWnd, @EnumBrowserChildForUrl, LPARAM(@LUrlData));
  if LUrlData.FoundUrl <> '' then
  begin
    Result := LUrlData.FoundUrl;
    Exit;
  end;
     
  // 2. 창 타이틀에서 사이트명 분석
  LCleanTitle := Trim(ATitle);
  if Pos(' - ', LCleanTitle) > 0 then
    LCleanTitle := Trim(Copy(LCleanTitle, 1, LastDelimiter('-', LCleanTitle) - 1));
    
  if (Pos('http://', LCleanTitle) = 1) or (Pos('https://', LCleanTitle) = 1) then
  begin
    Result := LCleanTitle;
    Exit;
  end;
  
  if Pos('www.', LCleanTitle) = 1 then
  begin
    Result := 'https://' + LCleanTitle;
    Exit;
  end;
  
  if LCleanTitle <> '' then
  begin
    if SameText(LCleanTitle, '새 탭') or SameText(LCleanTitle, 'New Tab') then
      Result := 'about:blank'
    else if Pos('네이버', LCleanTitle) > 0 then
      Result := 'https://www.naver.com'
    else if Pos('Google', LCleanTitle) > 0 then
      Result := 'https://www.google.com'
    else if Pos('YouTube', LCleanTitle) > 0 then
      Result := 'https://www.youtube.com'
    else if Pos('ChatGPT', LCleanTitle) > 0 then
      Result := 'https://chatgpt.com'
    else if Pos('GitHub', LCleanTitle) > 0 then
      Result := 'https://github.com'
    else if Pos('다음', LCleanTitle) > 0 then
      Result := 'https://www.daum.net'
    else if (Pos('.', LCleanTitle) > 0) and (Pos(' ', LCleanTitle) = 0) then
      Result := 'https://' + LCleanTitle
    else
      Result := 'https://www.google.com/search?q=' + TNetEncoding.URL.Encode(LCleanTitle);
  end;
end;

function TWindowSwitcherForm.GetExplorerFolderPath(AHWnd: HWND; const ATitle: string): string;
var
  LCleanTitle: string;
  LPath: array[0..MAX_PATH] of Char;
begin
  Result := '';
  LCleanTitle := Trim(ATitle);
  
  if (Pos(':\', LCleanTitle) > 0) and DirectoryExists(LCleanTitle) then
  begin
    Result := LCleanTitle;
    Exit;
  end;
  
  if (SameText(LCleanTitle, '내 PC') or SameText(LCleanTitle, 'This PC')) then
  begin
    Result := 'shell:MyComputerFolder';
    Exit;
  end;
  
  if (SameText(LCleanTitle, '다운로드') or SameText(LCleanTitle, 'Downloads')) then
  begin
    if Succeeded(SHGetFolderPath(0, CSIDL_PROFILE, 0, SHGFP_TYPE_CURRENT, LPath)) then
      Result := TPath.Combine(string(LPath), 'Downloads');
    Exit;
  end;
  
  if (SameText(LCleanTitle, '문서') or SameText(LCleanTitle, 'Documents')) then
  begin
    Result := TPath.GetDocumentsPath;
    Exit;
  end;
  
  if (SameText(LCleanTitle, '바탕 화면') or SameText(LCleanTitle, 'Desktop')) then
  begin
    if Succeeded(SHGetFolderPath(0, CSIDL_DESKTOPDIRECTORY, 0, SHGFP_TYPE_CURRENT, LPath)) then
      Result := string(LPath);
    Exit;
  end;
end;

procedure TWindowSwitcherForm.SavePresetToSlot(ASlot: Integer);
var
  LArr: TJSONArray;
  LObj: TJSONObject;
  I: Integer;
  LHWnd, LRoot: HWND;
  LPID: DWORD;
  LExePath, LTitle, LDocPath, LUrl, LFolderPath: string;
  LTitleBuf: array[0..511] of Char;
  LIsPinned: Boolean;
  LSeenHWnds: TList;
begin
  if not Assigned(DBManager) then Exit;
  
  LArr := TJSONArray.Create;
  LSeenHWnds := TList.Create;
  try
    // 1. 고정된 창들 먼저 수집
    if Assigned(FPinnedHWnds) then
    begin
      for I := 0 to FPinnedHWnds.Count - 1 do
      begin
        LHWnd := HWND(FPinnedHWnds[I]);
        LRoot := GetRootWindow(LHWnd);
        if IsWindow(LRoot) and (LSeenHWnds.IndexOf(Pointer(LRoot)) < 0) then
        begin
          LSeenHWnds.Add(Pointer(LRoot));
          GetWindowThreadProcessId(LRoot, LPID);
          LExePath := GetProcessFullExePath(LPID);
          GetWindowText(LRoot, LTitleBuf, 512);
          LTitle := Trim(string(LTitleBuf));
          
          if LExePath <> '' then
          begin
            LDocPath := GetDocumentPathFromWindow(LRoot, LTitle, LExePath);
            LUrl := GetBrowserCurrentUrl(LRoot, LTitle, LExePath);
            LFolderPath := GetExplorerFolderPath(LRoot, LTitle);
            
            LObj := TJSONObject.Create;
            LObj.AddPair('exe', LExePath);
            LObj.AddPair('title', LTitle);
            LObj.AddPair('doc', LDocPath);
            LObj.AddPair('url', LUrl);
            LObj.AddPair('folder', LFolderPath);
            LObj.AddPair('pinned', TJSONBool.Create(True));
            LArr.AddElement(LObj);
          end;
        end;
      end;
    end;
    
    // 2. 현재 열린 스위치 윈도우들 수집
    for I := 0 to Length(FWindows) - 1 do
    begin
      LHWnd := FWindows[I].HWnd;
      LRoot := GetRootWindow(LHWnd);
      if IsWindow(LRoot) and (LSeenHWnds.IndexOf(Pointer(LRoot)) < 0) then
      begin
        LSeenHWnds.Add(Pointer(LRoot));
        GetWindowThreadProcessId(LRoot, LPID);
        LExePath := GetProcessFullExePath(LPID);
        LTitle := FWindows[I].Title;
        LIsPinned := FWindows[I].IsPinned;
        
        if LExePath <> '' then
        begin
          LDocPath := GetDocumentPathFromWindow(LRoot, LTitle, LExePath);
          LUrl := GetBrowserCurrentUrl(LRoot, LTitle, LExePath);
          LFolderPath := GetExplorerFolderPath(LRoot, LTitle);
          
          LObj := TJSONObject.Create;
          LObj.AddPair('exe', LExePath);
          LObj.AddPair('title', LTitle);
          LObj.AddPair('doc', LDocPath);
          LObj.AddPair('url', LUrl);
          LObj.AddPair('folder', LFolderPath);
          LObj.AddPair('pinned', TJSONBool.Create(LIsPinned));
          LArr.AddElement(LObj);
        end;
      end;
    end;
    
    if LArr.Count = 0 then
    begin
      ShowMessage('저장할 실행 중인 창이 없습니다.');
      Exit;
    end;
    
    DBManager.SaveSetting('WindowPreset_' + IntToStr(ASlot), LArr.ToString);
    UpdatePresetButtonStyles;
    ShowMessage(Format('현재 창 구성(%d개)이 작업 공간 %d번에 성공적으로 저장되었습니다!' + #13#10 + '(열려 있던 문서 및 웹사이트 정보 포함)', [LArr.Count, ASlot]));
  finally
    LSeenHWnds.Free;
    LArr.Free;
  end;
end;

type
  PFindTargetData = ^TFindTargetData;
  TFindTargetData = record
    TargetExe: string;
    TargetTitle: string;
    FoundHWnd: HWND;
  end;

function FindWindowByExeAndTitleProc(AHWnd: HWND; lParam: LPARAM): BOOL; stdcall;
var
  LPData: PFindTargetData;
  LPID: DWORD;
  LExeName: string;
  LTitleBuf: array[0..511] of Char;
  LTitle: string;
begin
  Result := True;
  if not IsWindowVisible(AHWnd) then Exit;
  
  LPData := PFindTargetData(lParam);
  GetWindowThreadProcessId(AHWnd, LPID);
  
  if Assigned(WindowSwitcherForm) then
    LExeName := WindowSwitcherForm.GetProcessExeName(LPID);
    
  if (LPData^.TargetExe <> '') and (SameText(ExtractFileName(LPData^.TargetExe), LExeName)) then
  begin
    GetWindowText(AHWnd, LTitleBuf, 512);
    LTitle := Trim(string(LTitleBuf));
    
    if (LPData^.TargetTitle = '') or (Pos(LPData^.TargetTitle.ToLower, LTitle.ToLower) > 0) or (Pos(LTitle.ToLower, LPData^.TargetTitle.ToLower) > 0) then
    begin
      LPData^.FoundHWnd := AHWnd;
      Result := False; // 찾음!
    end;
  end;
end;

procedure TWindowSwitcherForm.LoadAndRestorePreset(ASlot: Integer);
var
  LJsonStr: string;
  LVal: TJSONValue;
  LArr: TJSONArray;
  LObj: TJSONObject;
  I: Integer;
  LExe, LTitle, LDoc, LUrl, LFolder: string;
  LIsPinned: Boolean;
  LFindData: TFindTargetData;
  LHWnd: HWND;
begin
  if not Assigned(DBManager) then Exit;
  
  LJsonStr := DBManager.GetSetting('WindowPreset_' + IntToStr(ASlot), '');
  if Trim(LJsonStr) = '' then
  begin
    ShowMessage(Format('작업 공간 %d번에 저장된 창 구성이 없습니다.' + #13#10 + '스위치바 빈 곳을 우클릭하여 현재 창들을 저장해 보세요.', [ASlot]));
    Exit;
  end;
  
  LVal := TJSONObject.ParseJSONValue(LJsonStr);
  if not (LVal is TJSONArray) then
  begin
    if Assigned(LVal) then LVal.Free;
    Exit;
  end;
  
  LArr := TJSONArray(LVal);
  try
    for I := 0 to LArr.Count - 1 do
    begin
      if LArr.Items[I] is TJSONObject then
      begin
        LObj := TJSONObject(LArr.Items[I]);
        LExe := LObj.GetValue<string>('exe', '');
        LTitle := LObj.GetValue<string>('title', '');
        LDoc := LObj.GetValue<string>('doc', '');
        LUrl := LObj.GetValue<string>('url', '');
        LFolder := LObj.GetValue<string>('folder', '');
        LIsPinned := LObj.GetValue<Boolean>('pinned', False);
        
        // 1. 현재 이미 실행 중인 창이 있는지 검색
        LFindData.TargetExe := LExe;
        LFindData.TargetTitle := LTitle;
        LFindData.FoundHWnd := 0;
        EnumWindows(@FindWindowByExeAndTitleProc, LPARAM(@LFindData));
        
        if LFindData.FoundHWnd <> 0 then
        begin
          LHWnd := GetRootWindow(LFindData.FoundHWnd);
          if IsIconic(LHWnd) then
            ShowWindow(LHWnd, SW_RESTORE)
          else
            ShowWindow(LHWnd, SW_SHOW);
          BringWindowToTop(LHWnd);
          SetForegroundWindow(LHWnd);
          
          if LIsPinned and not IsHWndPinned(LHWnd) then
            FPinnedHWnds.Add(Pointer(LHWnd));
        end
        else
        begin
          // 2. 실행 중이지 않은 경우: 문서, 독립된 새 창 URL, 폴더 또는 Exe 실행!
          if (LDoc <> '') and FileExists(LDoc) then
            ShellExecute(0, 'open', PChar(LDoc), nil, nil, SW_SHOWNORMAL)
          else if (LUrl <> '') and (LUrl <> 'about:blank') then
          begin
            if LExe <> '' then
            begin
              // 브라우저 탭으로 합쳐지지 않고 독립된 별도 창으로 띄움!
              ShellExecute(0, 'open', PChar(LExe), PChar('--new-window "' + LUrl + '"'), nil, SW_SHOWNORMAL);
            end
            else
              ShellExecute(0, 'open', PChar(LUrl), nil, nil, SW_SHOWNORMAL);
          end
          else if (LFolder <> '') then
            ShellExecute(0, 'open', 'explorer.exe', PChar(LFolder), nil, SW_SHOWNORMAL)
          else if LExe <> '' then
          begin
            // 브라우저인 경우 빈 새 창으로 띄움
            if (Pos('chrome', ExtractFileName(LExe).ToLower) > 0) or 
               (Pos('msedge', ExtractFileName(LExe).ToLower) > 0) or 
               (Pos('whale', ExtractFileName(LExe).ToLower) > 0) then
              ShellExecute(0, 'open', PChar(LExe), '--new-window', nil, SW_SHOWNORMAL)
            else
              ShellExecute(0, 'open', PChar(LExe), nil, nil, SW_SHOWNORMAL);
          end;
        end;
      end;
    end;
    
    UpdateWindowCards;
  finally
    LArr.Free;
  end;
end;

procedure TWindowSwitcherForm.UpdatePresetButtonStyles;
var
  I: Integer;
  LJsonStr: string;
  LVal: TJSONValue;
  LArr: TJSONArray;
  LSummary: string;
  J: Integer;
  LExeName, LDocName: string;
  LObj: TJSONObject;
begin
  if not Assigned(DBManager) then Exit;
  
  for I := 1 to 3 do
  begin
    if not Assigned(FBtnPresets[I]) then Continue;
    
    LJsonStr := DBManager.GetSetting('WindowPreset_' + IntToStr(I), '');
    if Trim(LJsonStr) <> '' then
    begin
      LVal := TJSONObject.ParseJSONValue(LJsonStr);
      if LVal is TJSONArray then
      begin
        LArr := TJSONArray(LVal);
        LSummary := '';
        for J := 0 to LArr.Count - 1 do
        begin
          if LArr.Items[J] is TJSONObject then
          begin
            LObj := TJSONObject(LArr.Items[J]);
            LDocName := ExtractFileName(LObj.GetValue<string>('doc', ''));
            LExeName := ExtractFileName(LObj.GetValue<string>('exe', ''));
            
            if LSummary <> '' then LSummary := LSummary + ', ';
            if LDocName <> '' then
              LSummary := LSummary + LDocName
            else
              LSummary := LSummary + ChangeFileExt(LExeName, '');
          end;
        end;
        
        // 저장된 슬롯: 또렷한 파란색 하이라이트 & 상세 힌트
        FBtnPresets[I].Font.Color := RGB(140, 185, 240);
        FBtnPresets[I].Hint := Format('[작업 공간 %d번 원클릭 복원]'#13#10'저장된 문서/앱: %s'#13#10'(클릭 시 즉시 실행 및 전환)', [I, LSummary]);
        LArr.Free;
      end
      else
      begin
        if Assigned(LVal) then LVal.Free;
        FBtnPresets[I].Font.Color := RGB(120, 125, 135);
        FBtnPresets[I].Hint := Format('작업 공간 %d (비어있음)'#13#10'스위치바 빈 곳 우클릭으로 저장', [I]);
      end;
    end
    else
    begin
      // 비어있는 슬롯: 다크 그레이 톤
      FBtnPresets[I].Font.Color := RGB(120, 125, 135);
      FBtnPresets[I].Hint := Format('작업 공간 %d (비어있음)'#13#10'스위치바 빈 곳 우클릭으로 저장', [I]);
    end;
  end;
end;

function TWindowSwitcherForm.IsSystemShellWindow(AHWnd: HWND): Boolean;
var
  LClassName: array[0..255] of Char;
  LClassStr: string;
begin
  Result := False;
  if not IsWindow(AHWnd) then Exit;
  
  if GetClassName(AHWnd, LClassName, 255) > 0 then
  begin
    LClassStr := string(LClassName);
    if SameText(LClassStr, 'Shell_TrayWnd') or 
       SameText(LClassStr, 'Shell_SecondaryTrayWnd') or 
       SameText(LClassStr, 'Progman') or 
       SameText(LClassStr, 'WorkerW') or
       SameText(LClassStr, 'Windows.UI.Core.CoreWindow') or
       SameText(LClassStr, 'NotifyIconOverflowWindow') or
       SameText(LClassStr, 'TopLevelWindowForOverflowList') or
       SameText(LClassStr, 'TaskListThumbnailWnd') or
       SameText(LClassStr, 'XamlExplorerHostIslandWindow') or
       (Pos('Taskbar', LClassStr) > 0) or
       (Pos('Thumbnail', LClassStr) > 0) or
       SameText(LClassStr, '#32768') then
    begin
      Result := True;
    end;
  end;
end;

function TWindowSwitcherForm.IsForegroundWindowFullScreen: Boolean;
var
  HW, LRoot: HWND;
  R: TRect;
  LMon: TMonitor;
begin
  Result := False;
  HW := GetForegroundWindow;
  if (HW = 0) or (HW = GetDesktopWindow) then Exit;
  if (HW = Self.Handle) then Exit;
  if Assigned(QuickBarForm) and (HW = QuickBarForm.Handle) then Exit;
  if Assigned(MainForm) and (HW = MainForm.Handle) then Exit;
  
  LRoot := GetRootWindow(HW);
  if IsSystemShellWindow(HW) or IsSystemShellWindow(LRoot) then Exit;
  
  if GetWindowRect(LRoot, R) then
  begin
    LMon := Screen.MonitorFromWindow(LRoot);
    if Assigned(LMon) then
    begin
      if (R.Left <= LMon.Left) and (R.Top <= LMon.Top) and
         (R.Right >= LMon.Left + LMon.Width) and (R.Bottom >= LMon.Top + LMon.Height) then
      begin
        Result := True;
      end;
    end;
  end;
end;

function TWindowSwitcherForm.GetRootWindow(AHWnd: HWND): HWND;
var
  LRoot: HWND;
begin
  if not IsWindow(AHWnd) then
  begin
    Result := 0;
    Exit;
  end;
  LRoot := GetAncestor(AHWnd, GA_ROOTOWNER);
  if (LRoot <> 0) and IsWindowVisible(LRoot) then
    Result := LRoot
  else
  begin
    LRoot := GetAncestor(AHWnd, GA_ROOT);
    if (LRoot <> 0) and IsWindowVisible(LRoot) then
      Result := LRoot
    else
      Result := AHWnd;
  end;
end;

function TWindowSwitcherForm.GetProcessExeName(APID: DWORD): string;
var
  LProcHandle: THandle;
  LModName: array[0..MAX_PATH] of Char;
begin
  Result := '';
  if APID = 0 then Exit;
  LProcHandle := OpenProcess(PROCESS_QUERY_INFORMATION or PROCESS_VM_READ, False, APID);
  if LProcHandle <> 0 then
  begin
    try
      if GetModuleFileNameEx(LProcHandle, 0, LModName, MAX_PATH) > 0 then
        Result := ExtractFileName(string(LModName));
    finally
      CloseHandle(LProcHandle);
    end;
  end;
end;

function TWindowSwitcherForm.GetWindowAppIcon(AHWnd: HWND): HICON;
var
  LRes: NativeInt;
begin
  try
    LRes := SendMessage(AHWnd, WM_GETICON, ICON_SMALL2, 0);
    if LRes = 0 then
      LRes := SendMessage(AHWnd, WM_GETICON, ICON_SMALL, 0);
    if LRes = 0 then
      LRes := SendMessage(AHWnd, WM_GETICON, ICON_BIG, 0);
    if LRes = 0 then
      LRes := NativeInt(GetClassLong(AHWnd, GCL_HICONSM_VAL));
    if LRes = 0 then
      LRes := NativeInt(GetClassLong(AHWnd, GCL_HICON_VAL));
      
    Result := HICON(LRes);
  except
    Result := 0;
  end;
end;

function TWindowSwitcherForm.HasWindowsChanged: Boolean;
var
  LData: TEnumData;
  LList: TList;
  LMergedList: TList;
  I: Integer;
  LHWnd: HWND;
  LTargetCount: Integer;
begin
  Result := False;
  if FTargetExeName = '' then Exit;
  
  LList := TList.Create;
  LMergedList := TList.Create;
  try
    for I := 0 to FPinnedHWnds.Count - 1 do
    begin
      LHWnd := HWND(FPinnedHWnds[I]);
      if IsWindow(LHWnd) then
      begin
        if LMergedList.IndexOf(Pointer(LHWnd)) < 0 then
          LMergedList.Add(Pointer(LHWnd));
      end;
    end;
    
    LData.TargetExeName := FTargetExeName;
    LData.MyPID := GetCurrentProcessId;
    LData.List := LList;
    EnumWindows(@EnumWindowsProc, LPARAM(@LData));
    
    // 이전에 있던 창들 원래 슬롯 순서 유지
    for I := 0 to Length(FWindows) - 1 do
    begin
      LHWnd := FWindows[I].HWnd;
      if (not IsHWndPinned(LHWnd)) and (LList.IndexOf(Pointer(LHWnd)) >= 0) and (LMergedList.IndexOf(Pointer(LHWnd)) < 0) then
        LMergedList.Add(Pointer(LHWnd));
    end;
    
    // 신규 생성된 창만 뒤에 추가
    for I := 0 to LList.Count - 1 do
    begin
      LHWnd := HWND(LList[I]);
      if LMergedList.IndexOf(Pointer(LHWnd)) < 0 then
        LMergedList.Add(Pointer(LHWnd));
    end;
    
    if LMergedList.Count > 9 then
      LTargetCount := 9
    else
      LTargetCount := LMergedList.Count;
      
    if LTargetCount <> Length(FWindows) then
    begin
      Result := True;
      Exit;
    end;
    
    for I := 0 to LTargetCount - 1 do
    begin
      if FWindows[I].HWnd <> HWND(LMergedList[I]) then
      begin
        Result := True;
        Exit;
      end;
    end;
  finally
    LMergedList.Free;
    LList.Free;
  end;
end;

procedure TWindowSwitcherForm.TimerWatchTimer(Sender: TObject);
var
  LActiveHWnd, LRootFore: HWND;
  LPID: DWORD;
  LExeName, LTitleStr, LCleanTitle: string;
  HOverflow, HMenu: HWND;
  LOverflowVisible: Boolean;
  I: Integer;
  LTitleBuf: array[0..511] of Char;
begin
  // 1. Windows 11 & Windows 10 트레이 오버플로우 창 및 트레이 우클릭 팝업 메뉴 감지
  HOverflow := FindWindow('TopLevelWindowForOverflowList', nil);
  if HOverflow = 0 then
    HOverflow := FindWindow('NotifyIconOverflowWindow', nil);
    
  HMenu := FindWindow('#32768', nil); // 우클릭 팝업 메뉴
    
  LOverflowVisible := (HOverflow <> 0) and IsWindowVisible(HOverflow);
  
  if LOverflowVisible or ((HMenu <> 0) and IsWindowVisible(HMenu)) then
  begin
    FOverflowActive := True;
    
    // 시스템 트레이 창 및 우클릭 메뉴를 화면 맨 위(최상위 Z-Order)로 강제 승격 및 유지!
    if (HOverflow <> 0) and IsWindowVisible(HOverflow) then
      SetWindowPos(HOverflow, HWND_TOPMOST, 0, 0, 0, 0, SWP_NOMOVE or SWP_NOSIZE or SWP_NOACTIVATE);
    if (HMenu <> 0) and IsWindowVisible(HMenu) then
      SetWindowPos(HMenu, HWND_TOPMOST, 0, 0, 0, 0, SWP_NOMOVE or SWP_NOSIZE or SWP_NOACTIVATE);
      
    // 퀵바를 일시적으로 NOTOPMOST로 내려 트레이 창 및 팝업 메뉴가 퀵바 위로 완벽하게 덮도록 지속 보장!
    SetWindowPos(Self.Handle, HWND_NOTOPMOST, Self.Left, Self.Top, Self.Width, Self.Height, SWP_NOACTIVATE or SWP_SHOWWINDOW);
    if Assigned(QuickBarForm) and QuickBarForm.Visible then
      SetWindowPos(QuickBarForm.Handle, HWND_NOTOPMOST, QuickBarForm.Left, QuickBarForm.Top, QuickBarForm.Width, QuickBarForm.Height, SWP_NOACTIVATE or SWP_SHOWWINDOW);
      
    Exit; // 트레이 조작 중에는 퀵바 스위칭 동작을 일시 대기하여 트레이 창 뒤에 안정적으로 머뭄!
  end
  else if FOverflowActive then
  begin
    FOverflowActive := False;
    // 트레이 창과 우클릭 메뉴가 모두 완전히 닫혔을 때만 핀 설정에 따라 TOPMOST 즉시 복원
    if FPinned and Self.Visible then
      SetWindowPos(Self.Handle, HWND_TOPMOST, Self.Left, Self.Top, Self.Width, Self.Height, SWP_NOACTIVATE or SWP_SHOWWINDOW);
    if Assigned(QuickBarForm) and QuickBarForm.Visible and QuickBarForm.Pinned then
      SetWindowPos(QuickBarForm.Handle, HWND_TOPMOST, QuickBarForm.Left, QuickBarForm.Top, QuickBarForm.Width, QuickBarForm.Height, SWP_NOACTIVATE or SWP_SHOWWINDOW);
  end;

  // 2. 전체화면 동영상/앱 감지 시 작업표시줄처럼 퀵바 일시 숨김 & 복귀 시 자동 복원
  if IsForegroundWindowFullScreen then
  begin
    if not FFullScreenHidden then
    begin
      FFullScreenHidden := True;
      if HandleAllocated and IsWindowVisible(Self.Handle) then
        ShowWindow(Self.Handle, SW_HIDE);
      if Assigned(QuickBarForm) and QuickBarForm.HandleAllocated and IsWindowVisible(QuickBarForm.Handle) then
        ShowWindow(QuickBarForm.Handle, SW_HIDE);
    end;
    Exit;
  end
  else
  begin
    if FFullScreenHidden then
    begin
      FFullScreenHidden := False;
      if Self.Visible then
      begin
        ShowWindow(Self.Handle, SW_SHOWNOACTIVATE);
        UpdatePos;
      end;
      if Assigned(QuickBarForm) and QuickBarForm.Visible then
      begin
        ShowWindow(QuickBarForm.Handle, SW_SHOWNOACTIVATE);
        QuickBarForm.UpdatePos;
      end;
      UpdateAppWorkArea;
    end;
  end;
  
  if not Self.Visible then Exit;
  
  // 3. 현재 퀵바에 표시 중인 창들 중 실제로 종료/닫힌 창이 있는지 실시간 검사 (마지막 창 닫힘 즉시 감지!)
  for I := 0 to Length(FWindows) - 1 do
  begin
    if (FWindows[I].HWnd <> 0) and not IsWindow(FWindows[I].HWnd) then
    begin
      UpdateWindowCards;
      Exit;
    end;
  end;
  
  // 4. 고정된 창 목록 중 실제로 종료/닫힌 창 실시간 정리
  for I := FPinnedHWnds.Count - 1 downto 0 do
  begin
    if not IsWindow(HWND(FPinnedHWnds[I])) then
    begin
      FPinnedHWnds.Delete(I);
      UpdateWindowCards;
      Exit;
    end;
  end;
  
  // 5. 현재 표시 중인 카드들의 실제 윈도우 타이틀 실시간 동기화 (웹페이지 이동, 문서 저장 등 즉각 반영!)
  for I := 0 to Length(FWindows) - 1 do
  begin
    if (FWindows[I].HWnd <> 0) and IsWindow(FWindows[I].HWnd) then
    begin
      GetWindowText(FWindows[I].HWnd, LTitleBuf, 512);
      LTitleStr := Trim(string(LTitleBuf));
      if LTitleStr <> FWindows[I].Title then
      begin
        FWindows[I].Title := LTitleStr;
        LCleanTitle := LTitleStr;
        if (LCleanTitle <> '') and (LCleanTitle[1] = '*') then
          LCleanTitle := Trim(Copy(LCleanTitle, 2, MaxInt));
        if Pos(' - ', LCleanTitle) > 0 then
          LCleanTitle := Trim(Copy(LCleanTitle, 1, LastDelimiter('-', LCleanTitle) - 1));
          
        if Assigned(FTitles[I]) then
        begin
          FTitles[I].Caption := FitTextToWidth(Self.Canvas, LCleanTitle, FTitles[I].Width);
          FTitles[I].Hint := LTitleStr;
        end;
        if Assigned(FPanels[I]) then
          FPanels[I].Hint := LTitleStr;
      end;
    end;
  end;
  
  LActiveHWnd := GetForegroundWindow;
  if (LActiveHWnd = 0) or (LActiveHWnd = Self.Handle) then Exit;
  if Assigned(QuickBarForm) and (LActiveHWnd = QuickBarForm.Handle) then Exit;
  
  if IsSystemShellWindow(LActiveHWnd) then Exit;
  
  LRootFore := GetRootWindow(LActiveHWnd);
  if IsSystemShellWindow(LRootFore) then Exit;
  
  GetWindowThreadProcessId(LRootFore, LPID);
  if (LPID = GetCurrentProcessId) or (LPID = 0) then Exit;
  
  LExeName := GetProcessExeName(LPID);
  if SameText(LExeName, 'explorer.exe') then Exit;
  
  if (LExeName <> '') and (not SameText(LExeName, FTargetExeName)) then
  begin
    FLastActiveHWnd := LRootFore;
    UpdateWindowCards;
  end
  else if (LExeName <> '') and SameText(LExeName, FTargetExeName) then
  begin
    if HasWindowsChanged then
    begin
      FLastActiveHWnd := LRootFore;
      UpdateWindowCards;
    end
    else if LRootFore <> FLastActiveHWnd then
    begin
      FLastActiveHWnd := LRootFore;
      UpdateActiveCardHighlight(LRootFore);
    end;
  end;
end;

function TWindowSwitcherForm.GetTaskbarTop: Integer;
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

procedure TWindowSwitcherForm.UpdatePos;
var
  LTaskbarTop: Integer;
  LHasQuickBar: Boolean;
begin
  LTaskbarTop := GetTaskbarTop;
  Self.Left := 0;
  Self.Width := Screen.Width;
  Self.Height := 44;
  
  LHasQuickBar := Assigned(QuickBarForm) and QuickBarForm.Visible;
  if LHasQuickBar then
    Self.Top := LTaskbarTop - 88 // 44 + 44
  else
    Self.Top := LTaskbarTop - 44;
    
  if HandleAllocated and Self.Visible then
  begin
    if not FOverflowActive then
    begin
      SetWindowPos(Self.Handle, HWND_TOPMOST, Self.Left, Self.Top, Self.Width, Self.Height, SWP_NOACTIVATE or SWP_SHOWWINDOW);
      BringWindowToTop(Self.Handle);
    end;
  end;
end;

procedure TWindowSwitcherForm.CollectWindowsForActiveApp;
var
  LActiveHWnd, LCurHWnd, LRootFore: HWND;
  LData: TEnumData;
  LList: TList;
  I: Integer;
  LHWnd: HWND;
  LTitleBuf: array[0..511] of Char;
  LCurPID, LMyPID: DWORD;
  LNewExeName: string;
  LMergedList: TList;
  LPinnedList: TList;
  LMaxCount: Integer;
begin
  LMyPID := GetCurrentProcessId;
  LActiveHWnd := GetForegroundWindow;
  
  if (LActiveHWnd <> 0) and not IsSystemShellWindow(LActiveHWnd) then
  begin
    LRootFore := GetRootWindow(LActiveHWnd);
    if (LRootFore <> 0) and not IsSystemShellWindow(LRootFore) then
    begin
      GetWindowThreadProcessId(LRootFore, FTargetPID);
      if (FTargetPID <> LMyPID) and (FTargetPID <> 0) then
      begin
        LNewExeName := GetProcessExeName(FTargetPID);
        if (LNewExeName <> '') and not SameText(LNewExeName, 'explorer.exe') then
        begin
          FTargetExeName := LNewExeName;
        end;
      end;
    end;
  end;
  
  // FTargetExeName이 아직 없으면 화면의 첫 번째 일반 앱 창 탐색
  if FTargetExeName = '' then
  begin
    LCurHWnd := GetWindow(GetDesktopWindow, GW_CHILD);
    while LCurHWnd <> 0 do
    begin
      if (not IsSystemShellWindow(LCurHWnd)) and (GetWindowTextLength(LCurHWnd) > 0) then
      begin
        GetWindowThreadProcessId(LCurHWnd, LCurPID);
        if (LCurPID <> LMyPID) and (LCurPID <> 0) then
        begin
          LNewExeName := GetProcessExeName(LCurPID);
          if (LNewExeName <> '') and not SameText(LNewExeName, 'explorer.exe') then
          begin
            FTargetExeName := LNewExeName;
            Break;
          end;
        end;
      end;
      LCurHWnd := GetWindow(LCurHWnd, GW_HWNDNEXT);
    end;
  end;
  
  LList := TList.Create;
  LMergedList := TList.Create;
  LPinnedList := TList.Create;
  try
    // 1) 닫힌 창은 FPinnedHWnds에서 즉시 완전 삭제!
    for I := FPinnedHWnds.Count - 1 downto 0 do
    begin
      LHWnd := HWND(FPinnedHWnds[I]);
      if not IsWindow(LHWnd) then
        FPinnedHWnds.Delete(I);
    end;
    
    // 2) 먼저 고정한 창이 1번, 나중에 추가 고정한 창이 2번, 3번... 순서대로 배치
    for I := 0 to FPinnedHWnds.Count - 1 do
    begin
      LHWnd := HWND(FPinnedHWnds[I]);
      if LPinnedList.IndexOf(Pointer(LHWnd)) < 0 then
        LPinnedList.Add(Pointer(LHWnd));
    end;
    
    if FTargetExeName <> '' then
    begin
      LData.TargetExeName := FTargetExeName;
      LData.MyPID := LMyPID;
      LData.List := LList;
      EnumWindows(@EnumWindowsProc, LPARAM(@LData));
    end;
    
    for I := 0 to LPinnedList.Count - 1 do
    begin
      LMergedList.Add(LPinnedList[I]);
    end;
    
    // 3) 이전에 FWindows에 이미 등록되어 있던 창들 중 살아있는 창들을 원래 슬롯 순서 그대로 영구 보존!
    for I := 0 to Length(FWindows) - 1 do
    begin
      LHWnd := FWindows[I].HWnd;
      if (not IsHWndPinned(LHWnd)) and (LList.IndexOf(Pointer(LHWnd)) >= 0) and (LMergedList.IndexOf(Pointer(LHWnd)) < 0) then
      begin
        LMergedList.Add(Pointer(LHWnd));
      end;
    end;
    
    // 4) 새로 추가로 열린 신규 창만 맨 뒤 슬롯에 추가!
    for I := 0 to LList.Count - 1 do
    begin
      LHWnd := HWND(LList[I]);
      if LMergedList.IndexOf(Pointer(LHWnd)) < 0 then
      begin
        LMergedList.Add(Pointer(LHWnd));
      end;
    end;
    
    // 시스템 셸/작업표시줄 조작 중 일시적으로 창이 안 잡히더라도 기존 FWindows가 유효하다면 보존!
    if (LMergedList.Count = 0) and (Length(FWindows) > 0) then
    begin
      for I := 0 to Length(FWindows) - 1 do
      begin
        if (FWindows[I].HWnd <> 0) and IsWindow(FWindows[I].HWnd) then
        begin
          if LMergedList.IndexOf(Pointer(FWindows[I].HWnd)) < 0 then
            LMergedList.Add(Pointer(FWindows[I].HWnd));
        end;
      end;
    end;
    
    LMaxCount := LMergedList.Count;
    if LMaxCount > 9 then LMaxCount := 9;
    
    SetLength(FWindows, LMaxCount);
    for I := 0 to LMaxCount - 1 do
    begin
      LHWnd := HWND(LMergedList[I]);
      FWindows[I].HWnd := LHWnd;
      FWindows[I].IsPinned := IsHWndPinned(LHWnd);
      
      GetWindowText(LHWnd, LTitleBuf, 512);
      FWindows[I].Title := Trim(string(LTitleBuf));
      FWindows[I].IconHandle := GetWindowAppIcon(LHWnd);
    end;
  finally
    LPinnedList.Free;
    LMergedList.Free;
    LList.Free;
  end;
end;

procedure TWindowSwitcherForm.UpdateWindowCards;
var
  I: Integer;
  LIcon: TIcon;
  LGuideTitleText: string;
  LCurForeHWnd, LRootFore, LCardRoot: HWND;
  LIsCurrentActive: Boolean;
begin
  CollectWindowsForActiveApp;
  
  LCurForeHWnd := GetForegroundWindow;
  LRootFore := GetRootWindow(LCurForeHWnd);
  
  // 1. 좌측 뱃지 갱신
  if FTargetExeName <> '' then
    LGuideTitleText := ChangeFileExt(FTargetExeName, '')
  else
    LGuideTitleText := '창전환';
    
  FLStaticGuideTitle.Caption := LGuideTitleText;
  if Assigned(ThemeManager) then
  begin
    FPanelGuide.Color := ThemeManager.Theme.QuickCardGuideBgColor;
    FLStaticGuideTitle.Font.Color := ThemeManager.Theme.QuickCardNumColor;
    FLStaticGuideKey.Font.Color := ThemeManager.Theme.QuickCardTextColor;
  end;
  
  // 2. 9개 슬롯 내용 및 가시성 갱신
  for I := 0 to 8 do
  begin
    if I < Length(FWindows) then
    begin
      LCardRoot := GetRootWindow(FWindows[I].HWnd);
      LIsCurrentActive := (FWindows[I].HWnd = LCurForeHWnd) or 
                          (LCardRoot = LRootFore) or 
                          (FWindows[I].HWnd = LRootFore);
      
      if LIsCurrentActive then
      begin
        if Assigned(ThemeManager) then
        begin
          FPanels[I].Color := ThemeManager.Theme.QuickCardActiveBgColor;
          FNumericLabels[I].Font.Color := ThemeManager.Theme.QuickCardTextColor;
        end
        else
        begin
          FPanels[I].Color := RGB(58, 76, 98);
          FNumericLabels[I].Font.Color := RGB(220, 235, 255);
        end;
      end
      else
      begin
        if Assigned(ThemeManager) then
        begin
          FPanels[I].Color := ThemeManager.Theme.QuickCardBgColor;
          FNumericLabels[I].Font.Color := ThemeManager.Theme.QuickCardNumColor;
        end
        else
        begin
          FPanels[I].Color := RGB(46, 50, 58);
          FNumericLabels[I].Font.Color := RGB(150, 165, 185);
        end;
      end;
      
      // 아이콘
      if FWindows[I].IconHandle <> 0 then
      begin
        LIcon := TIcon.Create;
        try
          LIcon.Handle := FWindows[I].IconHandle;
          FImages[I].Picture.Assign(LIcon);
        finally
          LIcon.ReleaseHandle;
          LIcon.Free;
        end;
        FImages[I].Visible := True;
      end
      else
      begin
        FImages[I].Picture := nil;
        FImages[I].Visible := False;
      end;
      
      // 핀 표시
      FPinIcons[I].Visible := FWindows[I].IsPinned;
      
      // 제목 (너비에 맞게 자른 뒤 가운데 정렬)
      FTitles[I].Caption := FitTextToWidth(Self.Canvas, FWindows[I].Title, FTitles[I].Width);
      if Assigned(ThemeManager) then
        FTitles[I].Font.Color := ThemeManager.Theme.QuickCardTextColor;
      
      FPanels[I].Visible := True;
    end
    else
    begin
      FPanels[I].Visible := False;
    end;
  end;
  
  UpdatePos;
end;

procedure TWindowSwitcherForm.UpdateActiveCardHighlight(AForcedActiveHWnd: HWND = 0);
var
  I: Integer;
  LTargetHWnd, LTargetRoot, LCardRoot: HWND;
  LIsCurrentActive: Boolean;
begin
  if AForcedActiveHWnd <> 0 then
    LTargetHWnd := AForcedActiveHWnd
  else
    LTargetHWnd := GetForegroundWindow;
    
  LTargetRoot := GetRootWindow(LTargetHWnd);
  
  for I := 0 to 8 do
  begin
    if (I < Length(FWindows)) and FPanels[I].Visible then
    begin
      LCardRoot := GetRootWindow(FWindows[I].HWnd);
      LIsCurrentActive := (FWindows[I].HWnd = LTargetHWnd) or 
                          (LCardRoot = LTargetRoot) or 
                          (FWindows[I].HWnd = LTargetRoot);
      
      if LIsCurrentActive then
      begin
        if Assigned(ThemeManager) then
        begin
          FPanels[I].Color := ThemeManager.Theme.QuickCardActiveBgColor;
          FNumericLabels[I].Font.Color := ThemeManager.Theme.QuickCardTextColor;
        end
        else
        begin
          FPanels[I].Color := RGB(58, 76, 98);
          FNumericLabels[I].Font.Color := RGB(220, 235, 255);
        end;
      end
      else
      begin
        if Assigned(ThemeManager) then
        begin
          FPanels[I].Color := ThemeManager.Theme.QuickCardBgColor;
          FNumericLabels[I].Font.Color := ThemeManager.Theme.QuickCardNumColor;
        end
        else
        begin
          FPanels[I].Color := RGB(46, 50, 58);
          FNumericLabels[I].Font.Color := RGB(150, 165, 185);
        end;
      end;
    end;
  end;
end;

procedure TWindowSwitcherForm.WindowCardContextPopup(Sender: TObject; MousePos: TPoint; var Handled: Boolean);
var
  LIdx: Integer;
  LScreenPos: TPoint;
begin
  Handled := True;
  if Sender is TComponent then
  begin
    LIdx := TComponent(Sender).Tag;
    if (LIdx >= 0) and (LIdx < Length(FWindows)) then
    begin
      FContextTargetIdx := LIdx;
      if FWindows[LIdx].IsPinned then
        FMenuTogglePin.Caption := '창 고정 해제'
      else
        FMenuTogglePin.Caption := '창 고정';
        
      GetCursorPos(LScreenPos);
      FPopupCard.Popup(LScreenPos.X, LScreenPos.Y);
    end;
  end;
end;

procedure TWindowSwitcherForm.MenuTogglePinClick(Sender: TObject);
begin
  if (FContextTargetIdx >= 0) and (FContextTargetIdx < Length(FWindows)) then
  begin
    TogglePinWindow(FWindows[FContextTargetIdx].HWnd);
  end;
end;

procedure TWindowSwitcherForm.MenuCloseWindowClick(Sender: TObject);
var
  LHWnd: HWND;
  LIdx: Integer;
begin
  if (FContextTargetIdx >= 0) and (FContextTargetIdx < Length(FWindows)) then
  begin
    LHWnd := FWindows[FContextTargetIdx].HWnd;
    LIdx := FPinnedHWnds.IndexOf(Pointer(LHWnd));
    if LIdx >= 0 then
      FPinnedHWnds.Delete(LIdx);
      
    if IsWindow(LHWnd) then
      PostMessage(LHWnd, WM_CLOSE, 0, 0);
      
    UpdateWindowCards;
  end;
end;

procedure TWindowSwitcherForm.WindowCardMouseEnter(Sender: TObject);
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

procedure TWindowSwitcherForm.WindowCardMouseLeave(Sender: TObject);
begin
  UpdateActiveCardHighlight(FLastActiveHWnd);
end;

procedure TWindowSwitcherForm.WindowCardClick(Sender: TObject);
var
  LIdx: Integer;
begin
  if Sender is TComponent then
  begin
    LIdx := TComponent(Sender).Tag;
    SwitchToWindowByIndex(LIdx);
  end;
end;

procedure TWindowSwitcherForm.SwitchToWindowByIndex(AIndex: Integer);
begin
  if (AIndex >= 0) and (AIndex < Length(FWindows)) then
    SwitchToWindow(FWindows[AIndex].HWnd);
end;

procedure TWindowSwitcherForm.SwitchToWindow(AHWnd: HWND);
var
  LRoot: HWND;
begin
  if not FPinned then
    HideBar;
    
  LRoot := GetRootWindow(AHWnd);
  if IsWindow(LRoot) then
  begin
    if IsIconic(LRoot) then
      ShowWindow(LRoot, SW_RESTORE)
    else
      ShowWindow(LRoot, SW_SHOW);
      
    BringWindowToTop(LRoot);
    SetForegroundWindow(LRoot);
    
    FLastActiveHWnd := LRoot;
    UpdateActiveCardHighlight(LRoot);
  end;
end;

procedure TWindowSwitcherForm.BtnPinClick(Sender: TObject);
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

procedure TWindowSwitcherForm.BtnCloseClick(Sender: TObject);
begin
  HideBar;
end;

procedure TWindowSwitcherForm.ShowBar;
begin
  ApplyTheme;
  if Assigned(DBManager) then
  begin
    Self.AlphaBlendValue := StrToIntDef(DBManager.GetSetting('QuickBarAlpha', '225'), 225);
    Self.AlphaBlend := (Self.AlphaBlendValue < 255);
  end;
  
  UpdateWindowCards;
  UpdatePresetButtonStyles;
  UpdatePos;
  Self.Visible := True;
  SetWindowPos(Self.Handle, HWND_TOPMOST, Self.Left, Self.Top, Self.Width, Self.Height, SWP_SHOWWINDOW or SWP_NOACTIVATE);
  BringWindowToTop(Self.Handle);
  
  if Assigned(QuickBarForm) and QuickBarForm.Visible then
    QuickBarForm.UpdatePos;
    
  UpdateAppWorkArea;
  FTimerWatch.Enabled := True;
  
  if Assigned(DBManager) then
    DBManager.SaveSetting('WindowSwitcherVisible', '1');
end;

procedure TWindowSwitcherForm.HideBar;
begin
  FTimerWatch.Enabled := False;
  Self.Visible := False;
  ShowWindow(Self.Handle, SW_HIDE);
  
  if Assigned(QuickBarForm) and QuickBarForm.Visible then
    QuickBarForm.UpdatePos;
    
  UpdateAppWorkArea;
  
  if Assigned(DBManager) then
    DBManager.SaveSetting('WindowSwitcherVisible', '0');
end;

procedure TWindowSwitcherForm.RefreshAndShow;
begin
  ShowBar;
end;

procedure TWindowSwitcherForm.ToggleVisibility;
begin
  if Self.Visible then
    HideBar
  else
    ShowBar;
end;

procedure TWindowSwitcherForm.FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
var
  LIdx: Integer;
begin
  if Key = VK_ESCAPE then
  begin
    if not FPinned then
      HideBar;
    Key := 0;
  end
  else if (Key >= Ord('1')) and (Key <= Ord('9')) and (Shift = []) then
  begin
    LIdx := Key - Ord('1');
    SwitchToWindowByIndex(LIdx);
    Key := 0;
  end;
end;

procedure TWindowSwitcherForm.FormDeactivate(Sender: TObject);
begin
  // 하단 독 바는 비활성화되어도 사라지지 않고 유지됨
end;

end.
