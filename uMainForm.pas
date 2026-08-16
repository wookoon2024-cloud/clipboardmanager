unit uMainForm;

interface

uses
  Winapi.Windows, Winapi.Messages, Winapi.ShellAPI, Winapi.ShlObj, Winapi.ActiveX,
  System.SysUtils, System.Variants, System.Classes,
  System.IOUtils, System.Win.Registry, System.UITypes, Vcl.Graphics, Vcl.Controls, Vcl.Forms,
  Vcl.Dialogs, Vcl.ExtCtrls, Vcl.Menus, Vcl.StdCtrls, Vcl.ComCtrls, Vcl.Clipbrd,
  uLog, uDatabase, uClipboardMonitor, uHotkeyManager, uQuickBarForm, uHistoryPopupForm, uWindowSwitcherForm, uThemeManager;

type
  TMainForm = class(TForm)
    TrayIcon: TTrayIcon;
    TrayMenu: TPopupMenu;
    MenuShowSettings: TMenuItem;
    MenuExit: TMenuItem;
    ColorDialog1: TColorDialog;
    
    // 메인 레이아웃 패널
    PanelLeft: TPanel;
    TreeViewNav: TTreeView;
    PanelBottom: TPanel;
    BtnApply: TButton;
    BtnSave: TButton;
    BtnCancel: TButton;
    
    // 설정 컨텐츠 패널들
    PanelContent: TPanel;
    
    // 1. 단축키 패널
    PanelTabHotkeys: TPanel;
    LabelTitleHotkeys: TLabel;
    LabelHotkeyPopup: TLabel;
    EditHotkeyPopup: TEdit;
    LabelStatusPopup: TLabel;
    LabelHotkeyQuickBar: TLabel;
    EditHotkeyQuickBar: TEdit;
    LabelStatusQuickBar: TLabel;
    LabelHotkeySwitcher: TLabel;
    EditHotkeySwitcher: TEdit;
    LabelStatusSwitcher: TLabel;
    LabelHotkeyQuickPaste: TLabel;
    EditHotkeyQuickPaste: TEdit;
    LabelStatusQuickPaste: TLabel;
    LabelHotkeySwitchPrefix: TLabel;
    EditHotkeySwitchPrefix: TEdit;
    LabelStatusSwitchPrefix: TLabel;
    LabelHotkeyTip: TLabel;
    
    // 2. 클립보드 패널
    PanelTabClipboard: TPanel;
    LabelTitleClipboard: TLabel;
    ChkEnableMonitoring: TCheckBox;
    ChkCaptureImages: TCheckBox;
    ChkIgnoreDuplicates: TCheckBox;
    LabelMaxClips: TLabel;
    EditMaxClips: TEdit;
    
    // 3. 외형/UI 패널
    PanelTabAppearance: TPanel;
    LabelTitleAppearance: TLabel;
    LabelSkinPreset: TLabel;
    ComboSkinPreset: TComboBox;
    LabelDesignStyle: TLabel;
    ComboDesignStyle: TComboBox;
    LabelHistItemHeight: TLabel;
    EditHistItemHeight: TEdit;
    LabelHistFontSize: TLabel;
    EditHistFontSize: TEdit;
    GroupBoxColors: TGroupBox;
    BtnColorHistBg: TButton;
    PanelColorHistBg: TPanel;
    BtnColorHistSelBg: TButton;
    PanelColorHistSelBg: TPanel;
    BtnColorHistText: TButton;
    PanelColorHistText: TPanel;
    BtnColorHistSelText: TButton;
    PanelColorHistSelText: TPanel;
    BtnColorBarBg: TButton;
    PanelColorBarBg: TPanel;
    BtnColorCardBg: TButton;
    PanelColorCardBg: TPanel;
    BtnColorCardActiveBg: TButton;
    PanelColorCardActiveBg: TPanel;
    
    LabelQuickbarAlpha: TLabel;
    TrackBarAlpha: TTrackBar;
    LabelAlphaValue: TLabel;
    ChkShowTooltips: TCheckBox;
    
    // 4. 일반 설정 패널
    PanelTabGeneral: TPanel;
    LabelTitleGeneral: TLabel;
    ChkAutoStart: TCheckBox;
    BtnClearDB: TButton;
    LabelClearInfo: TLabel;
    
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure MenuShowSettingsClick(Sender: TObject);
    procedure MenuExitClick(Sender: TObject);
    procedure BtnApplyClick(Sender: TObject);
    procedure BtnSaveClick(Sender: TObject);
    procedure BtnCancelClick(Sender: TObject);
    procedure TrayIconDblClick(Sender: TObject);
    procedure TreeViewNavChange(Sender: TObject; Node: TTreeNode);
    procedure TreeViewNavAdvancedCustomDrawItem(Sender: TCustomTreeView; Node: TTreeNode;
      State: TCustomDrawState; Stage: TCustomDrawStage; var PaintImages, DefaultDraw: Boolean);
    procedure TrackBarAlphaChange(Sender: TObject);
    procedure BtnClearDBClick(Sender: TObject);
    
    procedure HotkeyEditEnter(Sender: TObject);
    procedure HotkeyEditExit(Sender: TObject);
    procedure HotkeyEditKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure HotkeyPrefixEditKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure HotkeyEditKeyUp(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure BackgroundPanelMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    
    procedure ComboSkinPresetChange(Sender: TObject);
    procedure ComboDesignStyleChange(Sender: TObject);
    procedure BtnColorHistBgClick(Sender: TObject);
    procedure BtnColorHistSelBgClick(Sender: TObject);
    procedure BtnColorHistTextClick(Sender: TObject);
    procedure BtnColorHistSelTextClick(Sender: TObject);
    procedure BtnColorBarBgClick(Sender: TObject);
    procedure BtnColorCardBgClick(Sender: TObject);
    procedure BtnColorCardActiveBgClick(Sender: TObject);
  private
    FClipMonitor: TClipboardMonitor;
    FHotkeyMgr: THotkeyManager;
    FIsReallyExit: Boolean;
    FTempTheme: TThemeData;
    FIgnoreClipUntilTick: DWORD;
    FLastImageCaptureTick: DWORD;
    
    procedure InitTreeNav;
    procedure ShowConfigPanel(AIndex: Integer);
    procedure LoadAllSettings;
    procedure SaveAllSettings;
    procedure UpdateThemeUIFromData;
    procedure ValidateAllHotkeys;
    procedure RegisterGlobalHotkeys;
    procedure ClipboardChanged(Sender: TObject; const AText: string);
    procedure ClipboardImageChanged(Sender: TObject; ABitmap: TBitmap);
    procedure HotkeyTrigger(Sender: TObject; AID: Integer);
    procedure LoadTrayIcon;
    procedure SetAutoStartRegistry(AEnable: Boolean);
    function IsAutoStartEnabled: Boolean;
  protected
    procedure CreateParams(var Params: TCreateParams); override;
  public
    procedure DirectPaste(AIndex: Integer);
    procedure PauseMonitoring(ADurationMs: DWORD = 800);
    procedure ResumeMonitoring;
  end;

var
  MainForm: TMainForm;

procedure UpdateAppWorkArea;
procedure RestoreOriginalWorkArea;

implementation

{$R *.dfm}

const
  HOTKEY_ID_POPUP = 1;
  HOTKEY_ID_QUICKBAR = 2;
  HOTKEY_ID_SWITCHER = 3;
  HOTKEY_ID_PASTE_BASE = 100;
  HOTKEY_ID_SWITCH_BASE = 200;

var
  GOriginalWorkArea: TRect;
  GWorkAreaInitialized: Boolean = False;
  GAppBarRegistered: Boolean = False;
  GAppBarData: TAppBarData;

procedure InitOriginalWorkArea;
begin
  if not GWorkAreaInitialized then
  begin
    SystemParametersInfo(SPI_GETWORKAREA, 0, @GOriginalWorkArea, 0);
    GWorkAreaInitialized := True;
  end;
end;

var
  GAppBarHWnd: HWND = 0;

procedure RegisterWindowsAppBar(AHeight: Integer);
var
  HTray: HWND;
  R: TRect;
  LTaskbarTop: Integer;
begin
  if (GAppBarHWnd = 0) then
    GAppBarHWnd := AllocateHWnd(nil);
    
  if not GAppBarRegistered and (GAppBarHWnd <> 0) then
  begin
    FillChar(GAppBarData, SizeOf(GAppBarData), 0);
    GAppBarData.cbSize := SizeOf(TAppBarData);
    GAppBarData.hWnd := GAppBarHWnd;
    GAppBarData.uCallbackMessage := WM_USER + 102;
    SHAppBarMessage(ABM_NEW, GAppBarData);
    GAppBarRegistered := True;
  end;
  
  if GAppBarRegistered then
  begin
    HTray := FindWindow('Shell_TrayWnd', nil);
    if (HTray <> 0) and GetWindowRect(HTray, R) and (R.Top > 100) then
      LTaskbarTop := R.Top
    else
      LTaskbarTop := Screen.Height - 48;
      
    GAppBarData.uEdge := ABE_BOTTOM;
    GAppBarData.rc.Left := 0;
    GAppBarData.rc.Right := Screen.Width;
    GAppBarData.rc.Top := LTaskbarTop - AHeight;
    GAppBarData.rc.Bottom := LTaskbarTop;
    SHAppBarMessage(ABM_QUERYPOS, GAppBarData);
    SHAppBarMessage(ABM_SETPOS, GAppBarData);
  end;
end;

procedure UnregisterWindowsAppBar;
begin
  if GAppBarRegistered then
  begin
    SHAppBarMessage(ABM_REMOVE, GAppBarData);
    GAppBarRegistered := False;
  end;
  if GAppBarHWnd <> 0 then
  begin
    DeallocateHWnd(GAppBarHWnd);
    GAppBarHWnd := 0;
  end;
end;

procedure RestoreOriginalWorkArea;
begin
  UnregisterWindowsAppBar;
  if GWorkAreaInitialized then
  begin
    SystemParametersInfo(SPI_SETWORKAREA, 0, @GOriginalWorkArea, 0);
    SendNotifyMessage(HWND_BROADCAST, WM_SETTINGCHANGE, SPI_SETWORKAREA, 0);
  end;
end;

procedure UpdateAppWorkArea;
var
  R: TRect;
  LTaskbarTop: Integer;
  LReserveHeight: Integer;
  HTray: HWND;
  LQuickPinned, LSwitchPinned: Boolean;
  LQuickVis, LSwitchVis: Boolean;
begin
  InitOriginalWorkArea;
  
  LQuickVis := Assigned(QuickBarForm) and QuickBarForm.Visible;
  LSwitchVis := Assigned(WindowSwitcherForm) and WindowSwitcherForm.Visible;
  
  LQuickPinned := LQuickVis and QuickBarForm.Pinned;
  LSwitchPinned := LSwitchVis and WindowSwitcherForm.Pinned;
  
  HTray := FindWindow('Shell_TrayWnd', nil);
  if (HTray <> 0) and GetWindowRect(HTray, R) and (R.Top > 100) then
    LTaskbarTop := R.Top
  else
    LTaskbarTop := GOriginalWorkArea.Bottom;
    
  // 핀 고정 영역 계산:
  // 1) 둘 다 핀 켜짐: 88px 확보 (스위치바 + 퀵바)
  // 2) 스위치바(위)만 핀 켜짐: 
  //    - 퀵바(아래)가 켜져 있으면 스위치바가 위에 있으므로 88px 확보!
  //    - 퀵바가 꺼져 있으면 44px 확보!
  // 3) 퀵바(아래)만 핀 켜짐: 44px 확보!
  // 4) 둘 다 핀 꺼짐: 0px 확보 (전체화면 창이 화면 전체를 덮도록 복원)
  LReserveHeight := 0;
  if LSwitchPinned and LQuickPinned then
    LReserveHeight := 88
  else if LSwitchPinned then
  begin
    if LQuickVis then
      LReserveHeight := 88
    else
      LReserveHeight := 44;
  end
  else if LQuickPinned then
    LReserveHeight := 44;
    
  if LReserveHeight = 0 then
  begin
    RestoreOriginalWorkArea;
  end
  else
  begin
    RegisterWindowsAppBar(LReserveHeight);
    
    R := GOriginalWorkArea;
    R.Bottom := LTaskbarTop - LReserveHeight;
    SystemParametersInfo(SPI_SETWORKAREA, 0, @R, 0);
    SendNotifyMessage(HWND_BROADCAST, WM_SETTINGCHANGE, SPI_SETWORKAREA, 0);
  end;
end;

procedure RemoveFromTaskbar(AHWnd: HWND);
var
  LTaskbarList: ITaskbarList;
begin
  if (AHWnd = 0) or not IsWindow(AHWnd) then Exit;
  if Succeeded(CoCreateInstance(CLSID_TaskbarList, nil, CLSCTX_INPROC_SERVER, IID_ITaskbarList, LTaskbarList)) then
  begin
    LTaskbarList.HrInit;
    LTaskbarList.DeleteTab(AHWnd);
  end;
end;

procedure TMainForm.CreateParams(var Params: TCreateParams);
begin
  inherited CreateParams(Params);
  Params.ExStyle := (Params.ExStyle or WS_EX_TOOLWINDOW) and not WS_EX_APPWINDOW;
  Params.WndParent := GetDesktopWindow;
end;

procedure TMainForm.FormCreate(Sender: TObject);
begin
  FIsReallyExit := False;
  LogMsg('FormCreate Start');
  
  // 작업표시줄(Taskbar) 앱 아이콘 완전 숨김 처리 (트레이에만 상주)
  SetWindowLong(Application.Handle, GWL_EXSTYLE, (GetWindowLong(Application.Handle, GWL_EXSTYLE) or WS_EX_TOOLWINDOW) and not WS_EX_APPWINDOW);
  ShowWindow(Application.Handle, SW_HIDE);
  SetWindowLong(Self.Handle, GWL_EXSTYLE, (GetWindowLong(Self.Handle, GWL_EXSTYLE) or WS_EX_TOOLWINDOW) and not WS_EX_APPWINDOW);
  ShowWindow(Self.Handle, SW_HIDE);
  
  RemoveFromTaskbar(Application.Handle);
  RemoveFromTaskbar(Self.Handle);
  
  InitOriginalWorkArea;
  
  DBManager := TDatabaseManager.Create;
  
  FClipMonitor := TClipboardMonitor.Create;
  FClipMonitor.OnClipboardChange := ClipboardChanged;
  FClipMonitor.OnClipboardImageChange := ClipboardImageChanged;
  
  FHotkeyMgr := THotkeyManager.Create;
  FHotkeyMgr.OnHotkeyTrigger := HotkeyTrigger;
  
  QuickBarForm := TQuickBarForm.Create(Self);
  HistoryPopupForm := THistoryPopupForm.Create(Self);
  WindowSwitcherForm := TWindowSwitcherForm.Create(Self);
  
  RemoveFromTaskbar(QuickBarForm.Handle);
  RemoveFromTaskbar(HistoryPopupForm.Handle);
  RemoveFromTaskbar(WindowSwitcherForm.Handle);
  
  Self.Caption := '멀티 클립보드 매니저 ' + APP_VERSION;
  
  LoadTrayIcon;
  TrayIcon.Hint := '멀티 클립보드 매니저 ' + APP_VERSION;
  TrayIcon.Visible := True;
  
  InitTreeNav;
  LoadAllSettings;
  RegisterGlobalHotkeys;
  
  // 단축키 에디트 ReadOnly 설정 (클립보드 텍스트 오염 방지)
  EditHotkeyPopup.ReadOnly := True;
  EditHotkeyQuickBar.ReadOnly := True;
  EditHotkeySwitcher.ReadOnly := True;
  EditHotkeyQuickPaste.ReadOnly := True;
  EditHotkeySwitchPrefix.ReadOnly := True;
  
  // 에디트 바깥 영역 클릭 시 포커스 해제 연결
  Self.OnMouseDown := BackgroundPanelMouseDown;
  PanelContent.OnMouseDown := BackgroundPanelMouseDown;
  PanelTabHotkeys.OnMouseDown := BackgroundPanelMouseDown;
  PanelTabClipboard.OnMouseDown := BackgroundPanelMouseDown;
  PanelTabAppearance.OnMouseDown := BackgroundPanelMouseDown;
  PanelTabGeneral.OnMouseDown := BackgroundPanelMouseDown;
  PanelLeft.OnMouseDown := BackgroundPanelMouseDown;
  LabelTitleHotkeys.OnMouseDown := BackgroundPanelMouseDown;
  LabelHotkeyTip.OnMouseDown := BackgroundPanelMouseDown;
  
  // 이전 종료 시점의 가시성 상태 복원
  if Assigned(DBManager) and (DBManager.GetSetting('QuickBarVisible', '1') = '1') then
    QuickBarForm.RefreshAndShow
  else
    QuickBarForm.HideBar;
    
  if Assigned(DBManager) and (DBManager.GetSetting('WindowSwitcherVisible', '1') = '1') then
    WindowSwitcherForm.RefreshAndShow
  else
    WindowSwitcherForm.HideBar;
  
  LogMsg('FormCreate End');
end;

procedure TMainForm.FormDestroy(Sender: TObject);
begin
  RestoreOriginalWorkArea;
  
  FHotkeyMgr.Free;
  FClipMonitor.Free;
  
  if Assigned(QuickBarForm) then QuickBarForm.Free;
  if Assigned(HistoryPopupForm) then HistoryPopupForm.Free;
  if Assigned(WindowSwitcherForm) then WindowSwitcherForm.Free;
  
  DBManager.Free;
end;

procedure TMainForm.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  RegisterGlobalHotkeys;
  if not FIsReallyExit then
  begin
    Action := caNone;
    Self.Hide;
  end;
end;

procedure TMainForm.LoadTrayIcon;
var
  LIconPath: string;
  LIcon: TIcon;
  LBitmap: TBitmap;
  LIconInfo: TIconInfo;
begin
  LIconPath := TPath.Combine(ExtractFilePath(ParamStr(0)), 'banana.ico');
  if TFile.Exists(LIconPath) then
  begin
    try
      TrayIcon.Icon.LoadFromFile(LIconPath);
      Self.Icon.LoadFromFile(LIconPath);
      Exit;
    except
    end;
  end;
  
  LIcon := TIcon.Create;
  LBitmap := TBitmap.Create;
  try
    LBitmap.SetSize(32, 32);
    LBitmap.Canvas.Brush.Color := RGB(33, 36, 42);
    LBitmap.Canvas.FillRect(Rect(0, 0, 32, 32));
    
    LBitmap.Canvas.Pen.Color := RGB(245, 210, 60);
    LBitmap.Canvas.Pen.Width := 3;
    LBitmap.Canvas.Arc(4, 4, 28, 28, 6, 26, 26, 6);
    
    FillChar(LIconInfo, SizeOf(TIconInfo), 0);
    LIconInfo.fIcon := True;
    LIconInfo.hbmMask := LBitmap.Handle;
    LIconInfo.hbmColor := LBitmap.Handle;
    
    LIcon.Handle := CreateIconIndirect(LIconInfo);
    TrayIcon.Icon.Assign(LIcon);
    Self.Icon.Assign(LIcon);
  finally
    LBitmap.Free;
    LIcon.Free;
  end;
end;

procedure TMainForm.InitTreeNav;
begin
  TreeViewNav.Items.Clear;
  TreeViewNav.Items.Add(nil, '단축키 설정');
  TreeViewNav.Items.Add(nil, '클립보드 관리');
  TreeViewNav.Items.Add(nil, '외형 및 테마');
  TreeViewNav.Items.Add(nil, '일반 / 시스템');
  
  if TreeViewNav.Items.Count > 0 then
    TreeViewNav.Selected := TreeViewNav.Items[0];
end;

procedure TMainForm.TreeViewNavAdvancedCustomDrawItem(Sender: TCustomTreeView; Node: TTreeNode;
  State: TCustomDrawState; Stage: TCustomDrawStage; var PaintImages, DefaultDraw: Boolean);
var
  LRect: TRect;
  LCanvas: TCanvas;
begin
  if Stage = cdPostPaint then Exit;
  
  LCanvas := Sender.Canvas;
  LRect := Node.DisplayRect(False);
  
  if (cdsSelected in State) or (cdsFocused in State) then
  begin
    LCanvas.Brush.Color := RGB(58, 76, 98); // 깔끔한 슬레이트 블루
    LCanvas.Font.Color := RGB(245, 250, 255); // 또렷한 흰색 글씨
  end
  else
  begin
    LCanvas.Brush.Color := RGB(33, 36, 42); // 네비게이션 다크 그레이
    LCanvas.Font.Color := RGB(215, 222, 235); // 부드러운 밝은 그레이
  end;
  
  LCanvas.Brush.Style := bsSolid;
  LCanvas.FillRect(LRect);
  
  // 텍스트 좌측 넉넉한 패딩 및 깔끔한 드로잉 (포커스 테두리 완벽 제거)
  LRect.Left := LRect.Left + 22;
  LCanvas.Font.Name := 'Segoe UI';
  LCanvas.Font.Size := 10;
  LCanvas.Font.Style := [];
  DrawText(LCanvas.Handle, PChar(Node.Text), -1, LRect, DT_LEFT or DT_VCENTER or DT_SINGLELINE);
  
  DefaultDraw := False;
end;

procedure TMainForm.ShowConfigPanel(AIndex: Integer);
begin
  PanelTabHotkeys.Visible := (AIndex = 0);
  PanelTabClipboard.Visible := (AIndex = 1);
  PanelTabAppearance.Visible := (AIndex = 2);
  PanelTabGeneral.Visible := (AIndex = 3);
end;

procedure TMainForm.TreeViewNavChange(Sender: TObject; Node: TTreeNode);
begin
  if Node = nil then Exit;
  if Node.Text = '단축키 설정' then ShowConfigPanel(0)
  else if Node.Text = '클립보드 관리' then ShowConfigPanel(1)
  else if Node.Text = '외형 및 테마' then ShowConfigPanel(2)
  else if Node.Text = '일반 / 시스템' then ShowConfigPanel(3);
end;

// 대화형 단축키 에디트 이벤트 핸들러
procedure TMainForm.BackgroundPanelMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  // 에디트 바깥 빈 영역 클릭 시 에디트 포커스 해제 (비활성화)
  Self.ActiveControl := TreeViewNav;
  ValidateAllHotkeys;
end;

procedure TMainForm.HotkeyEditEnter(Sender: TObject);
begin
  if Sender is TEdit then
    TEdit(Sender).SelectAll;
end;

procedure TMainForm.HotkeyEditExit(Sender: TObject);
begin
  ValidateAllHotkeys;
end;

procedure TMainForm.HotkeyEditKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
var
  LStr: string;
begin
  if (Key = VK_BACK) or (Key = VK_DELETE) then
  begin
    if Sender is TEdit then
      TEdit(Sender).Text := '';
    Key := 0;
    ValidateAllHotkeys;
    Exit;
  end;
  
  LStr := THotkeyManager.KeyToHotkeyString(Key, Shift, False);
  if LStr <> '' then
  begin
    if Sender is TEdit then
      TEdit(Sender).Text := LStr;
  end;
  
  Key := 0;
  ValidateAllHotkeys;
end;

procedure TMainForm.HotkeyPrefixEditKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
var
  LStr: string;
begin
  if (Key = VK_BACK) or (Key = VK_DELETE) then
  begin
    if Sender is TEdit then
      TEdit(Sender).Text := '';
    Key := 0;
    ValidateAllHotkeys;
    Exit;
  end;
  
  LStr := THotkeyManager.KeyToHotkeyString(Key, Shift, True);
  if LStr <> '' then
  begin
    if Sender is TEdit then
      TEdit(Sender).Text := LStr;
  end;
  
  Key := 0;
  ValidateAllHotkeys;
end;

procedure TMainForm.HotkeyEditKeyUp(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  ValidateAllHotkeys;
  Key := 0;
end;

// 실시간 단축키 유효성, 내부 중복 및 외부 선점 검사
procedure TMainForm.ValidateAllHotkeys;
var
  KPopup, KQuick, KSwitch, KPastePfx, KSwitchPfx: string;
  LMod, LKey: UINT;
  
  procedure CheckSingleKey(const AKeyStr: string; ALabel: TLabel; const AOtherKeys: array of string);
  var
    I: Integer;
    LAvailable: Boolean;
    LCheckStr: string;
  begin
    if Trim(AKeyStr) = '' then
    begin
      ALabel.Caption := '(미설정)';
      ALabel.Font.Color := RGB(150, 150, 150);
      Exit;
    end;
    
    if AKeyStr.EndsWith('...') or AKeyStr.EndsWith('+') then
    begin
      ALabel.Caption := '⚠️ 일반 키를 입력하세요';
      ALabel.Font.Color := RGB(210, 140, 30);
      Exit;
    end;
    
    // 1. 내부 중복 검사
    for I := Low(AOtherKeys) to High(AOtherKeys) do
    begin
      if (Trim(AOtherKeys[I]) <> '') and SameText(Trim(AKeyStr), Trim(AOtherKeys[I])) then
      begin
        ALabel.Caption := '⚠️ 내부 단축키 중복';
        ALabel.Font.Color := RGB(220, 50, 50);
        Exit;
      end;
    end;
    
    // 2. 외부 선점 여부 테스트 (RegisterHotKey Probe)
    LCheckStr := AKeyStr;
    if not LCheckStr.Contains('+') and (LCheckStr = KPastePfx) then
      LCheckStr := LCheckStr + '+1'
    else if not LCheckStr.Contains('+') and (LCheckStr = KSwitchPfx) then
      LCheckStr := LCheckStr + '+1';
      
    THotkeyManager.ParseHotkeyString(LCheckStr, LMod, LKey);
    if LKey = 0 then
    begin
      ALabel.Caption := '⚠️ 키를 입력하세요';
      ALabel.Font.Color := RGB(210, 140, 30);
      Exit;
    end;
    
    LAvailable := THotkeyManager.IsHotkeyAvailable(LMod, LKey);
    if LAvailable then
    begin
      ALabel.Caption := '✓ 사용 가능';
      ALabel.Font.Color := RGB(34, 150, 60);
    end
    else
    begin
      ALabel.Caption := '⚠️ 타 프로그램 사용 중';
      ALabel.Font.Color := RGB(220, 50, 50);
    end;
  end;

begin
  // 검사 직전에 자사 단축키를 일시 해제하여 자사 등록 키를 '타 프로그램 사용 중'으로 오판하는 현상 완벽 방지
  if Assigned(FHotkeyMgr) then
    FHotkeyMgr.UnregisterAll;

  KPopup := Trim(EditHotkeyPopup.Text);
  KQuick := Trim(EditHotkeyQuickBar.Text);
  KSwitch := Trim(EditHotkeySwitcher.Text);
  KPastePfx := Trim(EditHotkeyQuickPaste.Text);
  KSwitchPfx := Trim(EditHotkeySwitchPrefix.Text);
  
  CheckSingleKey(KPopup, LabelStatusPopup, [KQuick, KSwitch, KPastePfx + '+1', KSwitchPfx + '+1']);
  CheckSingleKey(KQuick, LabelStatusQuickBar, [KPopup, KSwitch, KPastePfx + '+1', KSwitchPfx + '+1']);
  CheckSingleKey(KSwitch, LabelStatusSwitcher, [KPopup, KQuick, KPastePfx + '+1', KSwitchPfx + '+1']);
  CheckSingleKey(KPastePfx, LabelStatusQuickPaste, [KSwitchPfx]);
  CheckSingleKey(KSwitchPfx, LabelStatusSwitchPrefix, [KPastePfx]);
end;

procedure TMainForm.UpdateThemeUIFromData;
begin
  ComboSkinPreset.ItemIndex := FTempTheme.PresetIndex;
  ComboDesignStyle.ItemIndex := FTempTheme.DesignStyle;
  EditHistItemHeight.Text := IntToStr(FTempTheme.HistoryItemHeight);
  EditHistFontSize.Text := IntToStr(FTempTheme.HistoryFontSize);
  
  PanelColorHistBg.Color := FTempTheme.HistoryBgColor;
  PanelColorHistSelBg.Color := FTempTheme.HistorySelectedBgColor;
  PanelColorHistText.Color := FTempTheme.HistoryTextColor;
  PanelColorHistSelText.Color := FTempTheme.HistorySelectedTextColor;
  PanelColorBarBg.Color := FTempTheme.QuickBarBgColor;
  PanelColorCardBg.Color := FTempTheme.QuickCardBgColor;
  PanelColorCardActiveBg.Color := FTempTheme.QuickCardActiveBgColor;
end;

procedure TMainForm.ComboSkinPresetChange(Sender: TObject);
var
  LIdx: Integer;
begin
  LIdx := ComboSkinPreset.ItemIndex;
  if (LIdx >= 0) and (LIdx <= 3) then
  begin
    ThemeManager.ApplyPreset(LIdx);
    FTempTheme.PresetIndex := LIdx;
    FTempTheme.HistoryBgColor := ThemeManager.Theme.HistoryBgColor;
    FTempTheme.HistoryHeaderBgColor := ThemeManager.Theme.HistoryHeaderBgColor;
    FTempTheme.HistoryTextColor := ThemeManager.Theme.HistoryTextColor;
    FTempTheme.HistorySelectedBgColor := ThemeManager.Theme.HistorySelectedBgColor;
    FTempTheme.HistorySelectedTextColor := ThemeManager.Theme.HistorySelectedTextColor;
    FTempTheme.HistoryFavHeaderBgColor := ThemeManager.Theme.HistoryFavHeaderBgColor;
    FTempTheme.QuickBarBgColor := ThemeManager.Theme.QuickBarBgColor;
    FTempTheme.QuickCardBgColor := ThemeManager.Theme.QuickCardBgColor;
    FTempTheme.QuickCardActiveBgColor := ThemeManager.Theme.QuickCardActiveBgColor;
    FTempTheme.QuickCardTextColor := ThemeManager.Theme.QuickCardTextColor;
    FTempTheme.QuickCardNumColor := ThemeManager.Theme.QuickCardNumColor;
    FTempTheme.QuickCardGuideBgColor := ThemeManager.Theme.QuickCardGuideBgColor;
    UpdateThemeUIFromData;
  end;
end;

procedure TMainForm.ComboDesignStyleChange(Sender: TObject);
begin
  FTempTheme.DesignStyle := ComboDesignStyle.ItemIndex;
end;

procedure TMainForm.BtnColorHistBgClick(Sender: TObject);
begin
  ColorDialog1.Color := FTempTheme.HistoryBgColor;
  if ColorDialog1.Execute then
  begin
    FTempTheme.HistoryBgColor := ColorDialog1.Color;
    FTempTheme.PresetIndex := 4; // Custom
    UpdateThemeUIFromData;
  end;
end;

procedure TMainForm.BtnColorHistSelBgClick(Sender: TObject);
begin
  ColorDialog1.Color := FTempTheme.HistorySelectedBgColor;
  if ColorDialog1.Execute then
  begin
    FTempTheme.HistorySelectedBgColor := ColorDialog1.Color;
    FTempTheme.PresetIndex := 4;
    UpdateThemeUIFromData;
  end;
end;

procedure TMainForm.BtnColorHistTextClick(Sender: TObject);
begin
  ColorDialog1.Color := FTempTheme.HistoryTextColor;
  if ColorDialog1.Execute then
  begin
    FTempTheme.HistoryTextColor := ColorDialog1.Color;
    FTempTheme.PresetIndex := 4;
    UpdateThemeUIFromData;
  end;
end;

procedure TMainForm.BtnColorHistSelTextClick(Sender: TObject);
begin
  ColorDialog1.Color := FTempTheme.HistorySelectedTextColor;
  if ColorDialog1.Execute then
  begin
    FTempTheme.HistorySelectedTextColor := ColorDialog1.Color;
    FTempTheme.PresetIndex := 4;
    UpdateThemeUIFromData;
  end;
end;

procedure TMainForm.BtnColorBarBgClick(Sender: TObject);
begin
  ColorDialog1.Color := FTempTheme.QuickBarBgColor;
  if ColorDialog1.Execute then
  begin
    FTempTheme.QuickBarBgColor := ColorDialog1.Color;
    FTempTheme.PresetIndex := 4;
    UpdateThemeUIFromData;
  end;
end;

procedure TMainForm.BtnColorCardBgClick(Sender: TObject);
begin
  ColorDialog1.Color := FTempTheme.QuickCardBgColor;
  if ColorDialog1.Execute then
  begin
    FTempTheme.QuickCardBgColor := ColorDialog1.Color;
    FTempTheme.PresetIndex := 4;
    UpdateThemeUIFromData;
  end;
end;

procedure TMainForm.BtnColorCardActiveBgClick(Sender: TObject);
begin
  ColorDialog1.Color := FTempTheme.QuickCardActiveBgColor;
  if ColorDialog1.Execute then
  begin
    FTempTheme.QuickCardActiveBgColor := ColorDialog1.Color;
    FTempTheme.PresetIndex := 4;
    UpdateThemeUIFromData;
  end;
end;

procedure TMainForm.LoadAllSettings;
var
  LAlpha: Integer;
begin
  if not Assigned(DBManager) then Exit;
  
  // 1. 단축키
  EditHotkeyPopup.Text := DBManager.GetSetting('HotkeyPopup', 'Ctrl+Shift+V');
  EditHotkeyQuickBar.Text := DBManager.GetSetting('HotkeyQuickBar', 'Ctrl+Shift+Q');
  EditHotkeySwitcher.Text := DBManager.GetSetting('HotkeySwitcher', 'Ctrl+Shift+W');
  EditHotkeyQuickPaste.Text := DBManager.GetSetting('HotkeyQuickPastePrefix', 'Ctrl');
  EditHotkeySwitchPrefix.Text := DBManager.GetSetting('HotkeySwitchPrefix', 'Alt');
  ValidateAllHotkeys;
  
  // 2. 클립보드
  ChkEnableMonitoring.Checked := (DBManager.GetSetting('EnableMonitoring', '1') = '1');
  if Assigned(FClipMonitor) then
    FClipMonitor.Enabled := ChkEnableMonitoring.Checked;
  ChkCaptureImages.Checked := (DBManager.GetSetting('CaptureImages', '1') = '1');
  ChkIgnoreDuplicates.Checked := (DBManager.GetSetting('IgnoreDuplicates', '1') = '1');
  EditMaxClips.Text := DBManager.GetSetting('MaxClips', '500');
  
  // 3. 외형 및 테마
  LAlpha := StrToIntDef(DBManager.GetSetting('QuickBarAlpha', '225'), 225);
  TrackBarAlpha.Position := LAlpha;
  LabelAlphaValue.Caption := Format('%d%%', [Round((LAlpha / 255) * 100)]);
  ChkShowTooltips.Checked := (DBManager.GetSetting('ShowTooltips', '1') = '1');
  
  if Assigned(ThemeManager) then
  begin
    ThemeManager.LoadSettings;
    ThemeManager.NotifyThemeChanged;
    FTempTheme := ThemeManager.Theme;
    UpdateThemeUIFromData;
  end;
  
  // 4. 일반
  ChkAutoStart.Checked := IsAutoStartEnabled;
end;

procedure TMainForm.SaveAllSettings;
begin
  if not Assigned(DBManager) then Exit;
  
  // 1. 단축키
  DBManager.SaveSetting('HotkeyPopup', Trim(EditHotkeyPopup.Text));
  DBManager.SaveSetting('HotkeyQuickBar', Trim(EditHotkeyQuickBar.Text));
  DBManager.SaveSetting('HotkeySwitcher', Trim(EditHotkeySwitcher.Text));
  DBManager.SaveSetting('HotkeyQuickPastePrefix', Trim(EditHotkeyQuickPaste.Text));
  DBManager.SaveSetting('HotkeySwitchPrefix', Trim(EditHotkeySwitchPrefix.Text));
  
  // 2. 클립보드
  if ChkEnableMonitoring.Checked then
    DBManager.SaveSetting('EnableMonitoring', '1')
  else
    DBManager.SaveSetting('EnableMonitoring', '0');
    
  if ChkCaptureImages.Checked then
    DBManager.SaveSetting('CaptureImages', '1')
  else
    DBManager.SaveSetting('CaptureImages', '0');
    
  if ChkIgnoreDuplicates.Checked then
    DBManager.SaveSetting('IgnoreDuplicates', '1')
  else
    DBManager.SaveSetting('IgnoreDuplicates', '0');
    
  DBManager.SaveSetting('MaxClips', Trim(EditMaxClips.Text));
  
  // 3. 외형 및 테마
  DBManager.SaveSetting('QuickBarAlpha', IntToStr(TrackBarAlpha.Position));
  if Assigned(QuickBarForm) then
  begin
    QuickBarForm.AlphaBlend := (TrackBarAlpha.Position < 255);
    QuickBarForm.AlphaBlendValue := TrackBarAlpha.Position;
  end;
  if Assigned(WindowSwitcherForm) then
  begin
    WindowSwitcherForm.AlphaBlend := (TrackBarAlpha.Position < 255);
    WindowSwitcherForm.AlphaBlendValue := TrackBarAlpha.Position;
  end;
    
  if ChkShowTooltips.Checked then
    DBManager.SaveSetting('ShowTooltips', '1')
  else
    DBManager.SaveSetting('ShowTooltips', '0');
    
  if Assigned(HistoryPopupForm) then
    HistoryPopupForm.ListBoxClips.ShowHint := ChkShowTooltips.Checked;
    
  // 테마 저장
  FTempTheme.HistoryItemHeight := StrToIntDef(Trim(EditHistItemHeight.Text), 25);
  FTempTheme.HistoryFontSize := StrToIntDef(Trim(EditHistFontSize.Text), 8);
  FTempTheme.PresetIndex := ComboSkinPreset.ItemIndex;
  FTempTheme.DesignStyle := ComboDesignStyle.ItemIndex;
  
  if Assigned(ThemeManager) then
  begin
    ThemeManager.Theme := FTempTheme;
    ThemeManager.SaveSettings;
  end;
    
  // 4. 일반
  SetAutoStartRegistry(ChkAutoStart.Checked);
  
  FClipMonitor.Enabled := ChkEnableMonitoring.Checked;
  RegisterGlobalHotkeys;
end;

procedure TMainForm.SetAutoStartRegistry(AEnable: Boolean);
var
  LReg: TRegistry;
begin
  LReg := TRegistry.Create;
  try
    LReg.RootKey := HKEY_CURRENT_USER;
    if LReg.OpenKey('Software\Microsoft\Windows\CurrentVersion\Run', True) then
    begin
      if AEnable then
        LReg.WriteString('ClipboardManager', ParamStr(0))
      else
      begin
        if LReg.ValueExists('ClipboardManager') then
          LReg.DeleteValue('ClipboardManager');
      end;
      LReg.CloseKey;
    end;
  except
  end;
  LReg.Free;
end;

function TMainForm.IsAutoStartEnabled: Boolean;
var
  LReg: TRegistry;
begin
  Result := False;
  LReg := TRegistry.Create;
  try
    LReg.RootKey := HKEY_CURRENT_USER;
    if LReg.OpenKeyReadOnly('Software\Microsoft\Windows\CurrentVersion\Run') then
    begin
      Result := LReg.ValueExists('ClipboardManager');
      LReg.CloseKey;
    end;
  except
  end;
  LReg.Free;
end;

procedure TMainForm.BtnApplyClick(Sender: TObject);
begin
  SaveAllSettings;
end;

procedure TMainForm.BtnSaveClick(Sender: TObject);
begin
  SaveAllSettings;
  Self.Hide;
end;

procedure TMainForm.BtnCancelClick(Sender: TObject);
begin
  RegisterGlobalHotkeys;
  Self.Hide;
end;

procedure TMainForm.TrackBarAlphaChange(Sender: TObject);
var
  LAlpha: Byte;
begin
  LAlpha := TrackBarAlpha.Position;
  LabelAlphaValue.Caption := Format('%d%%', [Round((LAlpha / 255) * 100)]);
  
  if Assigned(QuickBarForm) and QuickBarForm.HandleAllocated then
  begin
    QuickBarForm.AlphaBlend := (LAlpha < 255);
    QuickBarForm.AlphaBlendValue := LAlpha;
  end;
  if Assigned(WindowSwitcherForm) and WindowSwitcherForm.HandleAllocated then
  begin
    WindowSwitcherForm.AlphaBlend := (LAlpha < 255);
    WindowSwitcherForm.AlphaBlendValue := LAlpha;
  end;
end;

procedure TMainForm.BtnClearDBClick(Sender: TObject);
begin
  if MessageDlg('정말로 저장된 모든 클립보드 내역을 삭제하시겠습니까?', mtConfirmation, [mbYes, mbNo], 0) = mrYes then
  begin
    DBManager.ClearAllClips;
    if Assigned(HistoryPopupForm) and HistoryPopupForm.Visible then
      HistoryPopupForm.UpdateDataOnly;
    if Assigned(QuickBarForm) and QuickBarForm.Visible then
      QuickBarForm.RefreshAndShow;
    ShowMessage('클립보드 내역이 초기화되었습니다.');
  end;
end;

procedure TMainForm.RegisterGlobalHotkeys;
var
  LPopupKey, LQuickBarKey, LSwitcherKey, LPastePrefix, LSwitchPrefix: string;
  I: Integer;
  LModifiers, LKey: UINT;
begin
  FHotkeyMgr.UnregisterAll;
  
  LPopupKey := Trim(EditHotkeyPopup.Text);
  if LPopupKey <> '' then
  begin
    THotkeyManager.ParseHotkeyString(LPopupKey, LModifiers, LKey);
    if LKey <> 0 then
      FHotkeyMgr.RegisterKey(HOTKEY_ID_POPUP, LModifiers, LKey);
  end;
    
  LQuickBarKey := Trim(EditHotkeyQuickBar.Text);
  if LQuickBarKey <> '' then
  begin
    THotkeyManager.ParseHotkeyString(LQuickBarKey, LModifiers, LKey);
    if LKey <> 0 then
      FHotkeyMgr.RegisterKey(HOTKEY_ID_QUICKBAR, LModifiers, LKey);
  end;

  LSwitcherKey := Trim(EditHotkeySwitcher.Text);
  if LSwitcherKey <> '' then
  begin
    THotkeyManager.ParseHotkeyString(LSwitcherKey, LModifiers, LKey);
    if LKey <> 0 then
      FHotkeyMgr.RegisterKey(HOTKEY_ID_SWITCHER, LModifiers, LKey);
  end;
    
  LPastePrefix := Trim(EditHotkeyQuickPaste.Text);
  if LPastePrefix <> '' then
  begin
    THotkeyManager.ParseHotkeyString(LPastePrefix + '+1', LModifiers, LKey);
    for I := 1 to 9 do
      FHotkeyMgr.RegisterKey(HOTKEY_ID_PASTE_BASE + I, LModifiers, Ord('0') + I);
  end;
  
  LSwitchPrefix := Trim(EditHotkeySwitchPrefix.Text);
  if LSwitchPrefix <> '' then
  begin
    THotkeyManager.ParseHotkeyString(LSwitchPrefix + '+1', LModifiers, LKey);
    for I := 1 to 9 do
      FHotkeyMgr.RegisterKey(HOTKEY_ID_SWITCH_BASE + I, LModifiers, Ord('0') + I);
  end;
end;

procedure TMainForm.ClipboardChanged(Sender: TObject; const AText: string);
begin
  if (FIgnoreClipUntilTick <> 0) and (GetTickCount < FIgnoreClipUntilTick) then Exit;
  if not Assigned(DBManager) then Exit;
  DBManager.AddClip(AText, 'TEXT');
  
  if Assigned(QuickBarForm) and QuickBarForm.Visible then
    QuickBarForm.RefreshAndShow;
  if Assigned(HistoryPopupForm) and HistoryPopupForm.Visible then
    HistoryPopupForm.UpdateDataOnly;
end;

procedure TMainForm.ClipboardImageChanged(Sender: TObject; ABitmap: TBitmap);
var
  LCurTick: DWORD;
begin
  if (FIgnoreClipUntilTick <> 0) and (GetTickCount < FIgnoreClipUntilTick) then Exit;
  if not Assigned(DBManager) or not ChkCaptureImages.Checked then Exit;
  
  LCurTick := GetTickCount;
  // 윈도우 캡처 도구(Win+Shift+S) 등의 연속 중복 이벤트 방지 (800ms 쿨다운)
  if (FLastImageCaptureTick <> 0) and (LCurTick - FLastImageCaptureTick < 800) then Exit;
  FLastImageCaptureTick := LCurTick;
  
  DBManager.AddImageClip(ABitmap);
  
  if Assigned(QuickBarForm) and QuickBarForm.Visible then
    QuickBarForm.RefreshAndShow;
  if Assigned(HistoryPopupForm) and HistoryPopupForm.Visible then
    HistoryPopupForm.UpdateDataOnly;
end;

procedure TMainForm.HotkeyTrigger(Sender: TObject; AID: Integer);
var
  LIndex: Integer;
begin
  if AID = HOTKEY_ID_POPUP then
  begin
    if Assigned(HistoryPopupForm) then
      HistoryPopupForm.RefreshAndShow;
  end
  else if AID = HOTKEY_ID_QUICKBAR then
  begin
    if Assigned(QuickBarForm) then
      QuickBarForm.ToggleVisibility;
  end
  else if AID = HOTKEY_ID_SWITCHER then
  begin
    if Assigned(WindowSwitcherForm) then
      WindowSwitcherForm.ToggleVisibility;
  end
  else if (AID >= HOTKEY_ID_PASTE_BASE + 1) and (AID <= HOTKEY_ID_PASTE_BASE + 9) then
  begin
    LIndex := AID - HOTKEY_ID_PASTE_BASE - 1;
    DirectPaste(LIndex);
  end
  else if (AID >= HOTKEY_ID_SWITCH_BASE + 1) and (AID <= HOTKEY_ID_SWITCH_BASE + 9) then
  begin
    LIndex := AID - HOTKEY_ID_SWITCH_BASE - 1;
    if Assigned(WindowSwitcherForm) then
      WindowSwitcherForm.SwitchToWindowByIndex(LIndex);
  end;
end;

procedure TMainForm.DirectPaste(AIndex: Integer);
var
  LClips: TArray<TClipRecord>;
  LTotal: Integer;
begin
  if not Assigned(DBManager) then Exit;
  DBManager.GetPagedClipRecords(1, 9, LClips, LTotal);
  
  if (AIndex >= 0) and (AIndex < Length(LClips)) then
  begin
    PauseMonitoring(500);
    if Assigned(HistoryPopupForm) then
      HistoryPopupForm.PasteRecord(LClips[AIndex], False);
  end;
end;

procedure TMainForm.PauseMonitoring(ADurationMs: DWORD);
begin
  FIgnoreClipUntilTick := GetTickCount + ADurationMs;
end;

procedure TMainForm.ResumeMonitoring;
begin
  FIgnoreClipUntilTick := 0;
end;

procedure TMainForm.MenuShowSettingsClick(Sender: TObject);
begin
  FHotkeyMgr.UnregisterAll;
  LoadAllSettings;
  Self.Show;
  SetForegroundWindow(Self.Handle);
end;

procedure TMainForm.MenuExitClick(Sender: TObject);
begin
  FIsReallyExit := True;
  Close;
end;

procedure TMainForm.TrayIconDblClick(Sender: TObject);
begin
  MenuShowSettingsClick(Sender);
end;

end.
