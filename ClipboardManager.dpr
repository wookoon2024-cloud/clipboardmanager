program ClipboardManager;

uses
  Winapi.Windows,
  Vcl.Forms,
  System.SysUtils,
  uLog in 'uLog.pas',
  uMainForm in 'uMainForm.pas' {MainForm},
  uDatabase in 'uDatabase.pas',
  uClipboardMonitor in 'uClipboardMonitor.pas',
  uHotkeyManager in 'uHotkeyManager.pas',
  uQuickBarForm in 'uQuickBarForm.pas' {QuickBarForm},
  uHistoryPopupForm in 'uHistoryPopupForm.pas' {HistoryPopupForm},
  uWindowSwitcherForm in 'uWindowSwitcherForm.pas' {WindowSwitcherForm},
  uFavEditForm in 'uFavEditForm.pas' {FavEditForm},
  uThemeManager in 'uThemeManager.pas';

{$R *.res}

type
  TGlobalHandler = class
    class procedure OnException(Sender: TObject; E: Exception);
  end;

class procedure TGlobalHandler.OnException(Sender: TObject; E: Exception);
begin
  LogMsg('[GLOBAL EXCEPTION] ' + E.ClassName + ': ' + E.Message);
end;

begin
  LogMsg('=== APP STARTING ===');
  Application.Initialize;
  Application.OnException := TGlobalHandler.OnException;
  Application.MainFormOnTaskbar := False;
  Application.ShowMainForm := False;
  ShowWindow(Application.Handle, SW_HIDE);
  
  LogMsg('Calling CreateForm(TMainForm)...');
  try
    Application.CreateForm(TMainForm, MainForm);
    LogMsg('CreateForm(TMainForm) SUCCESS');
  except
    on E: Exception do
      LogMsg('[ERROR in CreateForm TMainForm] ' + E.ClassName + ': ' + E.Message);
  end;
  
  LogMsg('Calling Application.Run...');
  Application.Run;
  LogMsg('=== APP TERMINATED ===');
end.
