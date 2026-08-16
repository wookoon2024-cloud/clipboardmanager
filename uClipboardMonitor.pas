unit uClipboardMonitor;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes, Vcl.Graphics;

type
  TClipboardChangeEvent = procedure(Sender: TObject; const AText: string) of object;
  TClipboardImageEvent = procedure(Sender: TObject; ABitmap: TBitmap) of object;

  TClipboardMonitor = class
  private
    FWindowHandle: HWND;
    FOnClipboardChange: TClipboardChangeEvent;
    FOnClipboardImageChange: TClipboardImageEvent;
    FEnabled: Boolean;
    procedure WndProc(var Msg: TMessage);
    procedure DoClipboardChange;
    function GetClipboardUnicodeText: string;
    function GetClipboardBitmap(ABitmap: TBitmap): Boolean;
  public
    constructor Create;
    destructor Destroy; override;
    
    property Enabled: Boolean read FEnabled write FEnabled;
    property OnClipboardChange: TClipboardChangeEvent read FOnClipboardChange write FOnClipboardChange;
    property OnClipboardImageChange: TClipboardImageEvent read FOnClipboardImageChange write FOnClipboardImageChange;
  end;

// Windows API 동적 임포트
function AddClipboardFormatListener(hwnd: HWND): BOOL; stdcall; external 'user32.dll' name 'AddClipboardFormatListener';
function RemoveClipboardFormatListener(hwnd: HWND): BOOL; stdcall; external 'user32.dll' name 'RemoveClipboardFormatListener';

implementation

{ TClipboardMonitor }

constructor TClipboardMonitor.Create;
begin
  inherited Create;
  FEnabled := True;
  
  // 메시지 수신을 위한 가상 윈도우 생성
  FWindowHandle := AllocateHWnd(WndProc);
  
  if FWindowHandle <> 0 then
  begin
    // 클립보드 리스너 등록
    AddClipboardFormatListener(FWindowHandle);
  end;
end;

destructor TClipboardMonitor.Destroy;
begin
  if FWindowHandle <> 0 then
  begin
    RemoveClipboardFormatListener(FWindowHandle);
    DeallocateHWnd(FWindowHandle);
  end;
  inherited Destroy;
end;

procedure TClipboardMonitor.WndProc(var Msg: TMessage);
begin
  if Msg.Msg = WM_CLIPBOARDUPDATE then
  begin
    if FEnabled then
      DoClipboardChange;
    Msg.Result := 0;
    Exit;
  end;
  
  Msg.Result := DefWindowProc(FWindowHandle, Msg.Msg, Msg.WParam, Msg.LParam);
end;

function TClipboardMonitor.GetClipboardUnicodeText: string;
var
  HData: THandle;
  PText: PChar;
  LRetries: Integer;
begin
  Result := '';
  
  for LRetries := 1 to 5 do
  begin
    if OpenClipboard(FWindowHandle) then
    begin
      try
        if IsClipboardFormatAvailable(CF_UNICODETEXT) then
        begin
          HData := GetClipboardData(CF_UNICODETEXT);
          if HData <> 0 then
          begin
            PText := GlobalLock(HData);
            if PText <> nil then
            begin
              try
                Result := string(PText);
              finally
                GlobalUnlock(HData);
              end;
            end;
          end;
          Break;
        end;
      finally
        CloseClipboard;
      end;
    end
    else
    begin
      Sleep(20);
    end;
  end;
end;

function TClipboardMonitor.GetClipboardBitmap(ABitmap: TBitmap): Boolean;
var
  HData: THandle;
  LRetries: Integer;
begin
  Result := False;
  for LRetries := 1 to 5 do
  begin
    if OpenClipboard(FWindowHandle) then
    begin
      try
        if IsClipboardFormatAvailable(CF_BITMAP) then
        begin
          HData := GetClipboardData(CF_BITMAP);
          if HData <> 0 then
          begin
            ABitmap.Handle := CopyImage(HData, IMAGE_BITMAP, 0, 0, LR_COPYRETURNORG);
            Result := not ABitmap.Empty;
          end;
          Break;
        end;
      finally
        CloseClipboard;
      end;
    end
    else
      Sleep(20);
  end;
end;

procedure TClipboardMonitor.DoClipboardChange;
var
  LText: string;
  LBitmap: TBitmap;
begin
  // 1. 텍스트 우선 확인
  LText := GetClipboardUnicodeText;
  if Trim(LText) <> '' then
  begin
    if Assigned(FOnClipboardChange) then
      FOnClipboardChange(Self, LText);
    Exit;
  end;

  // 2. 이미지가 있으면 이미지 처리
  if Assigned(FOnClipboardImageChange) then
  begin
    LBitmap := TBitmap.Create;
    try
      if GetClipboardBitmap(LBitmap) then
      begin
        FOnClipboardImageChange(Self, LBitmap);
      end;
    finally
      LBitmap.Free;
    end;
  end;
end;

end.
