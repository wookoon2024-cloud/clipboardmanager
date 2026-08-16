unit uThemeManager;

interface

uses
  System.SysUtils, System.Classes, Vcl.Graphics, Winapi.Windows, uDatabase, uLog;

type
  TThemeData = record
    PresetIndex: Integer;       // 0: Modern Slate, 1: Dark Charcoal, 2: Midnight Blue, 3: Soft Light, 4: Custom
    DesignStyle: Integer;       // 0: 기본(모던 플랫), 1: 모던 라운드, 2: 글래스 아크릴, 3: 사이버 네온
    
    // 1. 클립보드 세로 히스토리
    HistoryItemHeight: Integer; // 20 ~ 50 (기본 25)
    HistoryFontSize: Integer;   // 8 ~ 14 (기본 8)
    HistoryBgColor: TColor;     // 리스트박스 & 폼 배경색
    HistoryHeaderBgColor: TColor; // 헤더 & 페이징 배경색
    HistoryTextColor: TColor;   // 일반 글자색
    HistorySelectedBgColor: TColor; // 선택 시 배경색
    HistorySelectedTextColor: TColor; // 선택 시 글자색
    HistoryFavHeaderBgColor: TColor; // 즐겨찾기 구분 헤더 배경색
    
    // 2. 하단 퀵바 (클립보드 & 스위치바)
    QuickBarBgColor: TColor;    // 바 전체 배경색
    QuickCardBgColor: TColor;   // 기본 카드 배경색
    QuickCardActiveBgColor: TColor; // 활성/호버 카드 배경색
    QuickCardTextColor: TColor; // 카드 텍스트 색상
    QuickCardNumColor: TColor;  // 카드 숫자 색상
    QuickCardGuideBgColor: TColor; // 좌측 안내 뱃지 배경색
  end;

  TThemeManager = class
  private
    FTheme: TThemeData;
    function ColorToStringHex(AColor: TColor): string;
    function StringHexToColor(const AHex: string; ADefault: TColor): TColor;
  public
    constructor Create;
    destructor Destroy; override;
    
    procedure LoadSettings;
    procedure SaveSettings;
    procedure ApplyPreset(APresetIndex: Integer);
    procedure NotifyThemeChanged;
    
    property Theme: TThemeData read FTheme write FTheme;
  end;

var
  ThemeManager: TThemeManager;

implementation

uses
  uHistoryPopupForm, uQuickBarForm, uWindowSwitcherForm;

{ TThemeManager }

constructor TThemeManager.Create;
begin
  inherited Create;
  ApplyPreset(0); // 기본값: Modern Slate
  LoadSettings;
end;

destructor TThemeManager.Destroy;
begin
  inherited Destroy;
end;

function TThemeManager.ColorToStringHex(AColor: TColor): string;
var
  LColorRef: COLORREF;
begin
  LColorRef := ColorToRGB(AColor);
  Result := Format('#%.2X%.2X%.2X', [GetRValue(LColorRef), GetGValue(LColorRef), GetBValue(LColorRef)]);
end;

function TThemeManager.StringHexToColor(const AHex: string; ADefault: TColor): TColor;
var
  LStr: string;
  R, G, B: Integer;
begin
  Result := ADefault;
  LStr := Trim(AHex);
  if LStr.StartsWith('#') then
    LStr := Copy(LStr, 2, Length(LStr));
    
  if Length(LStr) = 6 then
  begin
    try
      R := StrToInt('$' + Copy(LStr, 1, 2));
      G := StrToInt('$' + Copy(LStr, 3, 2));
      B := StrToInt('$' + Copy(LStr, 5, 2));
      Result := RGB(R, G, B);
    except
      Result := ADefault;
    end;
  end;
end;

procedure TThemeManager.ApplyPreset(APresetIndex: Integer);
begin
  FTheme.PresetIndex := APresetIndex;
  
  case APresetIndex of
    0: // 1. 모던 슬레이트 그레이 (Modern Slate Gray)
    begin
      FTheme.HistoryItemHeight := 25;
      FTheme.HistoryFontSize := 8;
      FTheme.HistoryBgColor := RGB(33, 36, 42);
      FTheme.HistoryHeaderBgColor := RGB(42, 46, 54);
      FTheme.HistoryTextColor := RGB(225, 230, 238);
      FTheme.HistorySelectedBgColor := RGB(58, 76, 98);
      FTheme.HistorySelectedTextColor := RGB(245, 250, 255);
      FTheme.HistoryFavHeaderBgColor := RGB(46, 50, 58);
      
      FTheme.QuickBarBgColor := RGB(33, 36, 42);
      FTheme.QuickCardBgColor := RGB(46, 50, 58);
      FTheme.QuickCardActiveBgColor := RGB(58, 76, 98);
      FTheme.QuickCardTextColor := RGB(225, 230, 238);
      FTheme.QuickCardNumColor := RGB(150, 165, 185);
      FTheme.QuickCardGuideBgColor := RGB(42, 46, 54);
    end;
    
    1: // 2. 다크 챠콜 (Dark Charcoal)
    begin
      FTheme.HistoryItemHeight := 25;
      FTheme.HistoryFontSize := 8;
      FTheme.HistoryBgColor := RGB(22, 22, 24);
      FTheme.HistoryHeaderBgColor := RGB(30, 30, 34);
      FTheme.HistoryTextColor := RGB(230, 230, 235);
      FTheme.HistorySelectedBgColor := RGB(60, 60, 70);
      FTheme.HistorySelectedTextColor := clWhite;
      FTheme.HistoryFavHeaderBgColor := RGB(35, 35, 40);
      
      FTheme.QuickBarBgColor := RGB(20, 20, 22);
      FTheme.QuickCardBgColor := RGB(32, 32, 36);
      FTheme.QuickCardActiveBgColor := RGB(65, 65, 75);
      FTheme.QuickCardTextColor := RGB(230, 230, 235);
      FTheme.QuickCardNumColor := RGB(160, 160, 175);
      FTheme.QuickCardGuideBgColor := RGB(30, 30, 34);
    end;
    
    2: // 3. 미드나잇 블루 (Midnight Blue)
    begin
      FTheme.HistoryItemHeight := 25;
      FTheme.HistoryFontSize := 8;
      FTheme.HistoryBgColor := RGB(20, 28, 42);
      FTheme.HistoryHeaderBgColor := RGB(26, 38, 58);
      FTheme.HistoryTextColor := RGB(225, 235, 250);
      FTheme.HistorySelectedBgColor := RGB(45, 75, 115);
      FTheme.HistorySelectedTextColor := clWhite;
      FTheme.HistoryFavHeaderBgColor := RGB(30, 44, 66);
      
      FTheme.QuickBarBgColor := RGB(18, 25, 38);
      FTheme.QuickCardBgColor := RGB(28, 40, 62);
      FTheme.QuickCardActiveBgColor := RGB(50, 85, 130);
      FTheme.QuickCardTextColor := RGB(225, 235, 250);
      FTheme.QuickCardNumColor := RGB(140, 175, 215);
      FTheme.QuickCardGuideBgColor := RGB(26, 38, 58);
    end;
    
    3: // 4. 소프트 라이트 (Soft Light)
    begin
      FTheme.HistoryItemHeight := 26;
      FTheme.HistoryFontSize := 9;
      FTheme.HistoryBgColor := RGB(245, 246, 248);
      FTheme.HistoryHeaderBgColor := RGB(232, 235, 240);
      FTheme.HistoryTextColor := RGB(40, 45, 55);
      FTheme.HistorySelectedBgColor := RGB(205, 220, 245);
      FTheme.HistorySelectedTextColor := RGB(15, 30, 60);
      FTheme.HistoryFavHeaderBgColor := RGB(225, 228, 235);
      
      FTheme.QuickBarBgColor := RGB(240, 242, 246);
      FTheme.QuickCardBgColor := RGB(255, 255, 255);
      FTheme.QuickCardActiveBgColor := RGB(210, 225, 250);
      FTheme.QuickCardTextColor := RGB(40, 45, 55);
      FTheme.QuickCardNumColor := RGB(100, 110, 130);
      FTheme.QuickCardGuideBgColor := RGB(230, 234, 242);
    end;
  end;
end;

procedure TThemeManager.LoadSettings;
begin
  if not Assigned(DBManager) then Exit;
  
  FTheme.PresetIndex := StrToIntDef(DBManager.GetSetting('ThemePreset', '0'), 0);
  ApplyPreset(FTheme.PresetIndex);
  
  FTheme.DesignStyle := StrToIntDef(DBManager.GetSetting('ThemeDesignStyle', '0'), 0);
  
  FTheme.HistoryItemHeight := StrToIntDef(DBManager.GetSetting('ThemeHistItemHeight', IntToStr(FTheme.HistoryItemHeight)), FTheme.HistoryItemHeight);
  FTheme.HistoryFontSize := StrToIntDef(DBManager.GetSetting('ThemeHistFontSize', IntToStr(FTheme.HistoryFontSize)), FTheme.HistoryFontSize);
  
  // 사용자 정의(Custom, PresetIndex = 4)일 때만 개별 커스텀 색상을 DB에서 덮어씌움
  if FTheme.PresetIndex = 4 then
  begin
    FTheme.HistoryBgColor := StringHexToColor(DBManager.GetSetting('ThemeHistBgColor', ''), FTheme.HistoryBgColor);
    FTheme.HistoryHeaderBgColor := StringHexToColor(DBManager.GetSetting('ThemeHistHeaderBgColor', ''), FTheme.HistoryHeaderBgColor);
    FTheme.HistoryTextColor := StringHexToColor(DBManager.GetSetting('ThemeHistTextColor', ''), FTheme.HistoryTextColor);
    FTheme.HistorySelectedBgColor := StringHexToColor(DBManager.GetSetting('ThemeHistSelBgColor', ''), FTheme.HistorySelectedBgColor);
    FTheme.HistorySelectedTextColor := StringHexToColor(DBManager.GetSetting('ThemeHistSelTextColor', ''), FTheme.HistorySelectedTextColor);
    FTheme.HistoryFavHeaderBgColor := StringHexToColor(DBManager.GetSetting('ThemeHistFavHeaderBgColor', ''), FTheme.HistoryFavHeaderBgColor);
    
    FTheme.QuickBarBgColor := StringHexToColor(DBManager.GetSetting('ThemeQuickBarBgColor', ''), FTheme.QuickBarBgColor);
    FTheme.QuickCardBgColor := StringHexToColor(DBManager.GetSetting('ThemeQuickCardBgColor', ''), FTheme.QuickCardBgColor);
    FTheme.QuickCardActiveBgColor := StringHexToColor(DBManager.GetSetting('ThemeQuickCardActiveBgColor', ''), FTheme.QuickCardActiveBgColor);
    FTheme.QuickCardTextColor := StringHexToColor(DBManager.GetSetting('ThemeQuickCardTextColor', ''), FTheme.QuickCardTextColor);
    FTheme.QuickCardNumColor := StringHexToColor(DBManager.GetSetting('ThemeQuickCardNumColor', ''), FTheme.QuickCardNumColor);
    FTheme.QuickCardGuideBgColor := StringHexToColor(DBManager.GetSetting('ThemeQuickCardGuideBgColor', ''), FTheme.QuickCardGuideBgColor);
  end;
  
  NotifyThemeChanged;
end;

procedure TThemeManager.SaveSettings;
begin
  if not Assigned(DBManager) then Exit;
  
  DBManager.SaveSetting('ThemePreset', IntToStr(FTheme.PresetIndex));
  DBManager.SaveSetting('ThemeDesignStyle', IntToStr(FTheme.DesignStyle));
  DBManager.SaveSetting('ThemeHistItemHeight', IntToStr(FTheme.HistoryItemHeight));
  DBManager.SaveSetting('ThemeHistFontSize', IntToStr(FTheme.HistoryFontSize));
  
  DBManager.SaveSetting('ThemeHistBgColor', ColorToStringHex(FTheme.HistoryBgColor));
  DBManager.SaveSetting('ThemeHistHeaderBgColor', ColorToStringHex(FTheme.HistoryHeaderBgColor));
  DBManager.SaveSetting('ThemeHistTextColor', ColorToStringHex(FTheme.HistoryTextColor));
  DBManager.SaveSetting('ThemeHistSelBgColor', ColorToStringHex(FTheme.HistorySelectedBgColor));
  DBManager.SaveSetting('ThemeHistSelTextColor', ColorToStringHex(FTheme.HistorySelectedTextColor));
  DBManager.SaveSetting('ThemeHistFavHeaderBgColor', ColorToStringHex(FTheme.HistoryFavHeaderBgColor));
  
  DBManager.SaveSetting('ThemeQuickBarBgColor', ColorToStringHex(FTheme.QuickBarBgColor));
  DBManager.SaveSetting('ThemeQuickCardBgColor', ColorToStringHex(FTheme.QuickCardBgColor));
  DBManager.SaveSetting('ThemeQuickCardActiveBgColor', ColorToStringHex(FTheme.QuickCardActiveBgColor));
  DBManager.SaveSetting('ThemeQuickCardTextColor', ColorToStringHex(FTheme.QuickCardTextColor));
  DBManager.SaveSetting('ThemeQuickCardNumColor', ColorToStringHex(FTheme.QuickCardNumColor));
  DBManager.SaveSetting('ThemeQuickCardGuideBgColor', ColorToStringHex(FTheme.QuickCardGuideBgColor));
  
  NotifyThemeChanged;
end;

procedure TThemeManager.NotifyThemeChanged;
begin
  if Assigned(HistoryPopupForm) then
    HistoryPopupForm.ApplyTheme;
    
  if Assigned(QuickBarForm) then
    QuickBarForm.ApplyTheme;
    
  if Assigned(WindowSwitcherForm) then
    WindowSwitcherForm.ApplyTheme;
end;

initialization
  ThemeManager := TThemeManager.Create;

finalization
  ThemeManager.Free;

end.
