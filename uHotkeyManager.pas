unit uHotkeyManager;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes, 
  System.Generics.Collections, Vcl.Menus;

type
  THotkeyCallback = procedure(Sender: TObject; AID: Integer) of object;

  THotkeyInfo = record
    ID: Integer;
    Modifiers: UINT;
    Key: UINT;
    Active: Boolean;
  end;

  THotkeyManager = class
  private
    FWindowHandle: HWND;
    FOnHotkeyTrigger: THotkeyCallback;
    FHotkeys: TDictionary<Integer, THotkeyInfo>;
    procedure WndProc(var Msg: TMessage);
  public
    constructor Create;
    destructor Destroy; override;
    
    // 개별 핫키 등록 및 취소
    function RegisterKey(AID: Integer; AModifiers: UINT; AKey: UINT): Boolean; overload;
    function RegisterKey(AID: Integer; const AHotkeyStr: string): Boolean; overload;
    procedure UnregisterKey(AID: Integer);
    procedure UnregisterAll;
    
    // 단축키 문자열 파싱 헬퍼 (예: "Ctrl+Shift+V" -> Modifiers, Key)
    class procedure ParseHotkeyString(const AHotkeyStr: string; var AModifiers: UINT; var AKey: UINT);
    
    // 전역 등록 가능 여부 실시간 테스트 (타 프로그램 점유 확인)
    class function IsHotkeyAvailable(AModifiers: UINT; AKey: UINT): Boolean;
    
    // 키보드 이벤트로부터 직관적인 단축키 문자열 생성
    class function KeyToHotkeyString(AKey: Word; AShift: TShiftState; AModifiersOnly: Boolean = False): string;
    
    property OnHotkeyTrigger: THotkeyCallback read FOnHotkeyTrigger write FOnHotkeyTrigger;
  end;

implementation

{ THotkeyManager }

constructor THotkeyManager.Create;
begin
  inherited Create;
  FWindowHandle := AllocateHWnd(WndProc);
  FHotkeys := TDictionary<Integer, THotkeyInfo>.Create;
end;

destructor THotkeyManager.Destroy;
begin
  UnregisterAll;
  FHotkeys.Free;
  if FWindowHandle <> 0 then
    DeallocateHWnd(FWindowHandle);
  inherited Destroy;
end;

procedure THotkeyManager.WndProc(var Msg: TMessage);
begin
  if Msg.Msg = WM_HOTKEY then
  begin
    if Assigned(FOnHotkeyTrigger) then
      FOnHotkeyTrigger(Self, Msg.WParam);
    Msg.Result := 0;
  end;
  
  Msg.Result := DefWindowProc(FWindowHandle, Msg.Msg, Msg.WParam, Msg.LParam);
end;

function THotkeyManager.RegisterKey(AID: Integer; AModifiers: UINT; AKey: UINT): Boolean;
var
  LInfo: THotkeyInfo;
begin
  // 이미 등록된 ID가 있다면 먼저 해제
  if FHotkeys.ContainsKey(AID) then
    UnregisterKey(AID);

  // Windows API를 통한 단축키 등록
  Result := RegisterHotKey(FWindowHandle, AID, AModifiers, AKey);
  
  if Result then
  begin
    LInfo.ID := AID;
    LInfo.Modifiers := AModifiers;
    LInfo.Key := AKey;
    LInfo.Active := True;
    FHotkeys.Add(AID, LInfo);
  end;
end;

function THotkeyManager.RegisterKey(AID: Integer; const AHotkeyStr: string): Boolean;
var
  LModifiers, LKey: UINT;
begin
  Result := False;
  if Trim(AHotkeyStr) = '' then Exit;
  
  try
    ParseHotkeyString(AHotkeyStr, LModifiers, LKey);
    if LKey <> 0 then
      Result := RegisterKey(AID, LModifiers, LKey);
  except
    Result := False;
  end;
end;

procedure THotkeyManager.UnregisterKey(AID: Integer);
begin
  if FHotkeys.ContainsKey(AID) then
  begin
    UnregisterHotKey(FWindowHandle, AID);
    FHotkeys.Remove(AID);
  end;
end;

procedure THotkeyManager.UnregisterAll;
var
  LKey: Integer;
begin
  for LKey in FHotkeys.Keys do
  begin
    UnregisterHotKey(FWindowHandle, LKey);
  end;
  FHotkeys.Clear;
end;

class procedure THotkeyManager.ParseHotkeyString(const AHotkeyStr: string; var AModifiers: UINT; var AKey: UINT);
var
  LParts: TArray<string>;
  LPart: string;
begin
  AModifiers := 0;
  AKey := 0;
  
  LParts := AHotkeyStr.Replace(' ', '').Split(['+']);
  for LPart in LParts do
  begin
    if SameText(LPart, 'CTRL') then
      AModifiers := AModifiers or MOD_CONTROL
    else if SameText(LPart, 'SHIFT') then
      AModifiers := AModifiers or MOD_SHIFT
    else if SameText(LPart, 'ALT') then
      AModifiers := AModifiers or MOD_ALT
    else if SameText(LPart, 'WIN') then
      AModifiers := AModifiers or MOD_WIN
    // 단일 문자 키 판별
    else if Length(LPart) = 1 then
      AKey := Ord(UpCase(LPart[1]))
    // F1 ~ F12
    else if (Length(LPart) >= 2) and SameText(LPart.Substring(0, 1), 'F') then
      AKey := VK_F1 + StrToIntDef(LPart.Substring(1), 1) - 1
    else if SameText(LPart, 'SPACE') then
      AKey := VK_SPACE
    else if SameText(LPart, 'ENTER') or SameText(LPart, 'RETURN') then
      AKey := VK_RETURN
    else if SameText(LPart, 'TAB') then
      AKey := VK_TAB
    else if SameText(LPart, 'ESC') or SameText(LPart, 'ESCAPE') then
      AKey := VK_ESCAPE
    else if SameText(LPart, 'GRAVE') or SameText(LPart, '`') or SameText(LPart, '~') then
      AKey := VK_OEM_3;
  end;
end;

class function THotkeyManager.IsHotkeyAvailable(AModifiers: UINT; AKey: UINT): Boolean;
var
  LTestHwnd: HWND;
  LTestID: Integer;
begin
  Result := True;
  if AKey = 0 then Exit;
  
  LTestID := 9988;
  LTestHwnd := AllocateHWnd(nil);
  if LTestHwnd <> 0 then
  begin
    try
      // OS에 등록 테스트
      if RegisterHotKey(LTestHwnd, LTestID, AModifiers, AKey) then
      begin
        UnregisterHotKey(LTestHwnd, LTestID);
        Result := True;
      end
      else
      begin
        Result := False; // 이미 다른 앱이나 시스템이 선점
      end;
    finally
      DeallocateHWnd(LTestHwnd);
    end;
  end;
end;

class function THotkeyManager.KeyToHotkeyString(AKey: Word; AShift: TShiftState; AModifiersOnly: Boolean = False): string;
var
  LRes: string;
begin
  LRes := '';
  
  if ssCtrl in AShift then
    LRes := LRes + 'Ctrl+';
  if ssAlt in AShift then
    LRes := LRes + 'Alt+';
  if ssShift in AShift then
    LRes := LRes + 'Shift+';
    
  if (GetAsyncKeyState(VK_LWIN) < 0) or (GetAsyncKeyState(VK_RWIN) < 0) then
    LRes := LRes + 'Win+';

  if AModifiersOnly then
  begin
    if LRes.EndsWith('+') then
      LRes := LRes.Substring(0, Length(LRes) - 1);
    Result := LRes;
    Exit;
  end;
  
  // 일반 키가 Modifier 자체인 경우는 입력 대기 상태 표기 ('Ctrl+...')
  if AKey in [VK_CONTROL, VK_LCONTROL, VK_RCONTROL,
              VK_MENU, VK_LMENU, VK_RMENU,
              VK_SHIFT, VK_LSHIFT, VK_RSHIFT,
              VK_LWIN, VK_RWIN] then
  begin
    if LRes.EndsWith('+') then
      Result := LRes + '...'
    else
      Result := '';
    Exit;
  end;
  
  // 일반 문자 키
  if (AKey >= Ord('A')) and (AKey <= Ord('Z')) then
    LRes := LRes + Chr(AKey)
  else if (AKey >= Ord('0')) and (AKey <= Ord('9')) then
    LRes := LRes + Chr(AKey)
  else if (AKey >= VK_NUMPAD0) and (AKey <= VK_NUMPAD9) then
    LRes := LRes + 'Num' + IntToStr(AKey - VK_NUMPAD0)
  else if (AKey >= VK_F1) and (AKey <= VK_F12) then
    LRes := LRes + 'F' + IntToStr(AKey - VK_F1 + 1)
  else if AKey = VK_SPACE then
    LRes := LRes + 'Space'
  else if AKey = VK_RETURN then
    LRes := LRes + 'Enter'
  else if AKey = VK_TAB then
    LRes := LRes + 'Tab'
  else if AKey = VK_ESCAPE then
    LRes := LRes + 'Esc'
  else if AKey = VK_OEM_3 then
    LRes := LRes + '`'
  else if AKey = VK_OEM_MINUS then
    LRes := LRes + '-'
  else if AKey = VK_OEM_PLUS then
    LRes := LRes + '='
  else if AKey = VK_OEM_4 then
    LRes := LRes + '['
  else if AKey = VK_OEM_6 then
    LRes := LRes + ']'
  else if AKey = VK_OEM_1 then
    LRes := LRes + ';'
  else if AKey = VK_OEM_7 then
    LRes := LRes + ''''
  else if AKey = VK_OEM_COMMA then
    LRes := LRes + ','
  else if AKey = VK_OEM_PERIOD then
    LRes := LRes + '.'
  else if AKey = VK_OEM_2 then
    LRes := LRes + '/'
  else
    LRes := LRes + 'Key' + IntToStr(AKey);
    
  Result := LRes;
end;

end.
