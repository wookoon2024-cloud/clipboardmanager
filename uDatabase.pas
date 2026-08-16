unit uDatabase;

interface

uses
  System.SysUtils, System.Classes, System.IOUtils, Vcl.Graphics,
  FireDAC.Stan.Intf, FireDAC.Stan.Option, FireDAC.Stan.Error, FireDAC.Phys.Intf,
  FireDAC.Stan.Def, FireDAC.Stan.Pool, FireDAC.Stan.Async, FireDAC.Phys,
  FireDAC.Phys.SQLite, FireDAC.Phys.SQLiteDef, FireDAC.Stan.ExprFuncs,
  FireDAC.Phys.SQLiteWrapper.Stat, FireDAC.VCLUI.Wait, Data.DB,
  FireDAC.Comp.Client, FireDAC.Comp.DataSet, FireDAC.Stan.Param, FireDAC.DApt;

type
  TClipRecord = record
    ID: Integer;
    Title: string;
    Content: string;
    ClipType: string; // 'TEXT' 또는 'IMAGE'
    IsFavorite: Boolean;
    IsPinned: Boolean;
    CreatedAt: string;
  end;

  TDatabaseManager = class
  private
    FConnection: TFDConnection;
    FImageDir: string;
    procedure CreateTables;
  public
    constructor Create;
    destructor Destroy; override;
    
    // 클립보드 관련 함수
    procedure AddClip(const AContent: string; const AType: string);
    procedure AddImageClip(ABitmap: TBitmap);
    procedure GetRecentClips(AList: TStrings; AMaxCount: Integer = 100);
    procedure GetPagedClipRecords(APage: Integer; APageSize: Integer; var ARecords: TArray<TClipRecord>; var ATotalCount: Integer);
    procedure GetFavoriteClipRecords(var ARecords: TArray<TClipRecord>);
    procedure ToggleFavorite(AID: Integer);
    procedure TogglePinClip(AID: Integer);
    procedure SaveFavoriteWithTitle(AID: Integer; const ATitle, AContent: string);
    procedure ReorderFavorites(const AIDList: TArray<Integer>);
    procedure ClearAllFavorites;
    procedure DeleteClip(AID: Integer);
    procedure ClearAllClips;
    
    // 설정값 관련 함수
    function GetSetting(const AKey: string; const ADefault: string): string;
    procedure SaveSetting(const AKey, AValue: string);
  end;

var
  DBManager: TDatabaseManager;

implementation

{ TDatabaseManager }

constructor TDatabaseManager.Create;
var
  LDBPath: string;
begin
  inherited Create;
  LDBPath := TPath.Combine(TPath.GetDirectoryName(ParamStr(0)), 'clips.db');
  FImageDir := TPath.Combine(TPath.GetDirectoryName(ParamStr(0)), 'images');
  if not TDirectory.Exists(FImageDir) then
    TDirectory.CreateDirectory(FImageDir);
  
  FConnection := TFDConnection.Create(nil);
  FConnection.Params.DriverID := 'SQLite';
  FConnection.Params.Database := LDBPath;
  FConnection.LoginPrompt := False;
  
  try
    FConnection.Open;
    CreateTables;
  except
    on E: Exception do
      raise Exception.Create('데이터베이스 연결 실패: ' + E.Message);
  end;
end;

destructor TDatabaseManager.Destroy;
begin
  if FConnection.Connected then
    FConnection.Close;
  FConnection.Free;
  inherited Destroy;
end;

procedure TDatabaseManager.CreateTables;
var
  LQuery: TFDQuery;
begin
  LQuery := TFDQuery.Create(nil);
  try
    LQuery.Connection := FConnection;
    
    // clips 테이블 생성
    LQuery.SQL.Text := 
      'CREATE TABLE IF NOT EXISTS clips (' +
      '  id INTEGER PRIMARY KEY AUTOINCREMENT,' +
      '  title TEXT,' +
      '  content TEXT,' +
      '  clip_type TEXT,' +
      '  is_favorite INTEGER DEFAULT 0,' +
      '  is_pinned INTEGER DEFAULT 0,' +
      '  created_at DATETIME DEFAULT CURRENT_TIMESTAMP' +
      ');';
    LQuery.ExecSQL;

    // 기존 테이블에 title 컬럼 누락 시 자동 추가
    try
      LQuery.SQL.Text := 'ALTER TABLE clips ADD COLUMN title TEXT;';
      LQuery.ExecSQL;
    except
    end;

    // 기존 테이블에 is_pinned 컬럼 누락 시 자동 추가
    try
      LQuery.SQL.Text := 'ALTER TABLE clips ADD COLUMN is_pinned INTEGER DEFAULT 0;';
      LQuery.ExecSQL;
    except
    end;
    
    try
      LQuery.SQL.Text := 'ALTER TABLE clips ADD COLUMN pinned_order INTEGER DEFAULT 0;';
      LQuery.ExecSQL;
    except
    end;

    try
      LQuery.SQL.Text := 'ALTER TABLE clips ADD COLUMN fav_order INTEGER DEFAULT 0;';
      LQuery.ExecSQL;
    except
    end;

    // settings 테이블 생성
    LQuery.SQL.Text :=
      'CREATE TABLE IF NOT EXISTS settings (' +
      '  key TEXT PRIMARY KEY,' +
      '  value TEXT' +
      ');';
    LQuery.ExecSQL;
    
  finally
    LQuery.Free;
  end;
end;

procedure TDatabaseManager.AddClip(const AContent: string; const AType: string);
var
  LQuery: TFDQuery;
  LTrimmed: string;
begin
  LTrimmed := Trim(AContent);
  if LTrimmed = '' then Exit;
  
  LQuery := TFDQuery.Create(nil);
  try
    LQuery.Connection := FConnection;
    
    // 중복 방지 체크
    if GetSetting('IgnoreDuplicates', '1') = '1' then
    begin
      LQuery.SQL.Text := 'SELECT id, content FROM clips WHERE clip_type = :type ORDER BY id DESC LIMIT 1';
      LQuery.ParamByName('type').AsString := AType;
      LQuery.Open;
      
      if not LQuery.IsEmpty and (LQuery.FieldByName('content').AsString = LTrimmed) then
        Exit;
      LQuery.Close;
    end;
    
    // 클립 저장
    LQuery.SQL.Text := 'INSERT INTO clips (content, clip_type, is_favorite, is_pinned, created_at) VALUES (:content, :clip_type, 0, 0, datetime(''now'', ''localtime''))';
    LQuery.ParamByName('content').AsString := LTrimmed;
    LQuery.ParamByName('clip_type').AsString := AType;
    LQuery.ExecSQL;
    
  finally
    LQuery.Free;
  end;
end;

procedure TDatabaseManager.AddImageClip(ABitmap: TBitmap);
var
  LFileName, LFullPath: string;
  LQuery: TFDQuery;
begin
  if (ABitmap = nil) or (ABitmap.Width <= 0) or (ABitmap.Height <= 0) then Exit;
  
  LFileName := FormatDateTime('yyyymmdd_hhnnss_zzz', Now) + '.bmp';
  LFullPath := TPath.Combine(FImageDir, LFileName);
  
  try
    ABitmap.SaveToFile(LFullPath);
    
    LQuery := TFDQuery.Create(nil);
    try
      LQuery.Connection := FConnection;
      LQuery.SQL.Text := 'INSERT INTO clips (content, clip_type, is_favorite, is_pinned, created_at) VALUES (:content, ''IMAGE'', 0, 0, datetime(''now'', ''localtime''))';
      LQuery.ParamByName('content').AsString := LFileName;
      LQuery.ExecSQL;
    finally
      LQuery.Free;
    end;
  except
  end;
end;

procedure TDatabaseManager.GetRecentClips(AList: TStrings; AMaxCount: Integer);
var
  LQuery: TFDQuery;
  LType, LVal: string;
begin
  AList.Clear;
  LQuery := TFDQuery.Create(nil);
  try
    LQuery.Connection := FConnection;
    LQuery.SQL.Text := 'SELECT content, clip_type FROM clips ORDER BY is_pinned DESC, id DESC LIMIT :limit';
    LQuery.ParamByName('limit').AsInteger := AMaxCount;
    LQuery.Open;
    
    while not LQuery.Eof do
    begin
      LType := LQuery.FieldByName('clip_type').AsString;
      LVal := LQuery.FieldByName('content').AsString;
      if LType = 'IMAGE' then
        AList.Add('[IMAGE]' + LVal)
      else
        AList.Add(LVal);
      LQuery.Next;
    end;
  finally
    LQuery.Free;
  end;
end;

procedure TDatabaseManager.GetPagedClipRecords(APage: Integer; APageSize: Integer; var ARecords: TArray<TClipRecord>; var ATotalCount: Integer);
var
  LQuery: TFDQuery;
  LOffset: Integer;
  LIdx: Integer;
begin
  SetLength(ARecords, 0);
  ATotalCount := 0;
  
  LQuery := TFDQuery.Create(nil);
  try
    LQuery.Connection := FConnection;
    
    // 1. 전체 개수 조회
    LQuery.SQL.Text := 'SELECT COUNT(*) FROM clips';
    LQuery.Open;
    if not LQuery.IsEmpty then
      ATotalCount := LQuery.Fields[0].AsInteger;
    LQuery.Close;
    
    if ATotalCount = 0 then Exit;
    
    // 2. 페이징 데이터 조회 (is_pinned 최우선, 고정된 것끼리는 고정된 순서 pinned_order ASC, 일반은 최신 id DESC)
    if APage < 1 then APage := 1;
    LOffset := (APage - 1) * APageSize;
    
    LQuery.SQL.Text := 'SELECT id, title, content, clip_type, is_favorite, is_pinned, created_at FROM clips ' +
                       'ORDER BY is_pinned DESC, CASE WHEN is_pinned = 1 THEN pinned_order ELSE 0 END ASC, id DESC ' +
                       'LIMIT :limit OFFSET :offset';
    LQuery.ParamByName('limit').AsInteger := APageSize;
    LQuery.ParamByName('offset').AsInteger := LOffset;
    LQuery.Open;
    
    SetLength(ARecords, LQuery.RecordCount);
    LIdx := 0;
    while not LQuery.Eof do
    begin
      ARecords[LIdx].ID := LQuery.FieldByName('id').AsInteger;
      ARecords[LIdx].Title := LQuery.FieldByName('title').AsString;
      ARecords[LIdx].Content := LQuery.FieldByName('content').AsString;
      ARecords[LIdx].ClipType := LQuery.FieldByName('clip_type').AsString;
      ARecords[LIdx].IsFavorite := LQuery.FieldByName('is_favorite').AsInteger = 1;
      ARecords[LIdx].IsPinned := LQuery.FieldByName('is_pinned').AsInteger = 1;
      ARecords[LIdx].CreatedAt := LQuery.FieldByName('created_at').AsString;
      Inc(LIdx);
      LQuery.Next;
    end;
  finally
    LQuery.Free;
  end;
end;

procedure TDatabaseManager.GetFavoriteClipRecords(var ARecords: TArray<TClipRecord>);
var
  LQuery: TFDQuery;
  LIdx: Integer;
begin
  SetLength(ARecords, 0);
  LQuery := TFDQuery.Create(nil);
  try
    LQuery.Connection := FConnection;
    LQuery.SQL.Text := 'SELECT id, title, content, clip_type, is_favorite, is_pinned, created_at FROM clips ' +
                       'WHERE is_favorite = 1 ' +
                       'ORDER BY fav_order ASC, id ASC ' +
                       'LIMIT 50';
    LQuery.Open;
    
    SetLength(ARecords, LQuery.RecordCount);
    LIdx := 0;
    while not LQuery.Eof do
    begin
      ARecords[LIdx].ID := LQuery.FieldByName('id').AsInteger;
      ARecords[LIdx].Title := LQuery.FieldByName('title').AsString;
      ARecords[LIdx].Content := LQuery.FieldByName('content').AsString;
      ARecords[LIdx].ClipType := LQuery.FieldByName('clip_type').AsString;
      ARecords[LIdx].IsFavorite := True;
      ARecords[LIdx].IsPinned := LQuery.FieldByName('is_pinned').AsInteger = 1;
      ARecords[LIdx].CreatedAt := LQuery.FieldByName('created_at').AsString;
      Inc(LIdx);
      LQuery.Next;
    end;
  finally
    LQuery.Free;
  end;
end;

procedure TDatabaseManager.ReorderFavorites(const AIDList: TArray<Integer>);
var
  I: Integer;
  LQuery: TFDQuery;
begin
  if Length(AIDList) = 0 then Exit;
  LQuery := TFDQuery.Create(nil);
  try
    LQuery.Connection := FConnection;
    for I := 0 to High(AIDList) do
    begin
      LQuery.SQL.Text := 'UPDATE clips SET fav_order = :order WHERE id = :id';
      LQuery.ParamByName('order').AsInteger := I + 1;
      LQuery.ParamByName('id').AsInteger := AIDList[I];
      LQuery.ExecSQL;
    end;
  finally
    LQuery.Free;
  end;
end;

procedure TDatabaseManager.ToggleFavorite(AID: Integer);
var
  LQuery: TFDQuery;
begin
  LQuery := TFDQuery.Create(nil);
  try
    LQuery.Connection := FConnection;
    LQuery.SQL.Text := 'UPDATE clips SET is_favorite = CASE WHEN is_favorite = 1 THEN 0 ELSE 1 END WHERE id = :id';
    LQuery.ParamByName('id').AsInteger := AID;
    LQuery.ExecSQL;
  finally
    LQuery.Free;
  end;
end;

procedure TDatabaseManager.TogglePinClip(AID: Integer);
var
  LQuery: TFDQuery;
  LCurPinned: Integer;
  LMaxOrder: Integer;
begin
  LQuery := TFDQuery.Create(nil);
  try
    LQuery.Connection := FConnection;
    
    LQuery.SQL.Text := 'SELECT is_pinned FROM clips WHERE id = :id';
    LQuery.ParamByName('id').AsInteger := AID;
    LQuery.Open;
    if LQuery.IsEmpty then Exit;
    LCurPinned := LQuery.FieldByName('is_pinned').AsInteger;
    LQuery.Close;
    
    if LCurPinned = 1 then
    begin
      // 고정 해제
      LQuery.SQL.Text := 'UPDATE clips SET is_pinned = 0, pinned_order = 0 WHERE id = :id';
      LQuery.ParamByName('id').AsInteger := AID;
      LQuery.ExecSQL;
    end
    else
    begin
      // 새로 고정: 기존 최대 고정 순서 + 1 을 부여하여 1번 뒤(2번, 3번...)로 고정
      LQuery.SQL.Text := 'SELECT COALESCE(MAX(pinned_order), 0) AS max_order FROM clips WHERE is_pinned = 1';
      LQuery.Open;
      LMaxOrder := LQuery.FieldByName('max_order').AsInteger;
      LQuery.Close;
      
      LQuery.SQL.Text := 'UPDATE clips SET is_pinned = 1, pinned_order = :order WHERE id = :id';
      LQuery.ParamByName('order').AsInteger := LMaxOrder + 1;
      LQuery.ParamByName('id').AsInteger := AID;
      LQuery.ExecSQL;
    end;
  finally
    LQuery.Free;
  end;
end;

procedure TDatabaseManager.SaveFavoriteWithTitle(AID: Integer; const ATitle, AContent: string);
var
  LQuery: TFDQuery;
begin
  LQuery := TFDQuery.Create(nil);
  try
    LQuery.Connection := FConnection;
    LQuery.SQL.Text := 'UPDATE clips SET title = :title, content = :content, is_favorite = 1 WHERE id = :id';
    LQuery.ParamByName('title').AsString := Trim(ATitle);
    LQuery.ParamByName('content').AsString := AContent;
    LQuery.ParamByName('id').AsInteger := AID;
    LQuery.ExecSQL;
  finally
    LQuery.Free;
  end;
end;

procedure TDatabaseManager.ClearAllFavorites;
var
  LQuery: TFDQuery;
begin
  LQuery := TFDQuery.Create(nil);
  try
    LQuery.Connection := FConnection;
    LQuery.SQL.Text := 'UPDATE clips SET is_favorite = 0 WHERE is_favorite = 1';
    LQuery.ExecSQL;
  finally
    LQuery.Free;
  end;
end;

procedure TDatabaseManager.DeleteClip(AID: Integer);
var
  LQuery: TFDQuery;
  LType, LFileName: string;
begin
  LQuery := TFDQuery.Create(nil);
  try
    LQuery.Connection := FConnection;
    
    // 이미지 파일 삭제
    LQuery.SQL.Text := 'SELECT content, clip_type FROM clips WHERE id = :id';
    LQuery.ParamByName('id').AsInteger := AID;
    LQuery.Open;
    if not LQuery.IsEmpty then
    begin
      LType := LQuery.FieldByName('clip_type').AsString;
      LFileName := LQuery.FieldByName('content').AsString;
      if (LType = 'IMAGE') and (LFileName <> '') then
      begin
        try
          TFile.Delete(TPath.Combine(FImageDir, LFileName));
        except
        end;
      end;
    end;
    LQuery.Close;
    
    // 레코드 삭제
    LQuery.SQL.Text := 'DELETE FROM clips WHERE id = :id';
    LQuery.ParamByName('id').AsInteger := AID;
    LQuery.ExecSQL;
  finally
    LQuery.Free;
  end;
end;

procedure TDatabaseManager.ClearAllClips;
var
  LQuery: TFDQuery;
begin
  LQuery := TFDQuery.Create(nil);
  try
    LQuery.Connection := FConnection;
    // 즐겨찾기(is_favorite = 1)는 남겨두고 일반 히스토리만 삭제
    LQuery.SQL.Text := 'DELETE FROM clips WHERE is_favorite = 0';
    LQuery.ExecSQL;
  finally
    LQuery.Free;
  end;
end;

function TDatabaseManager.GetSetting(const AKey: string; const ADefault: string): string;
var
  LQuery: TFDQuery;
begin
  Result := ADefault;
  LQuery := TFDQuery.Create(nil);
  try
    LQuery.Connection := FConnection;
    LQuery.SQL.Text := 'SELECT value FROM settings WHERE key = :key';
    LQuery.ParamByName('key').AsString := AKey;
    LQuery.Open;
    
    if not LQuery.IsEmpty then
      Result := LQuery.FieldByName('value').AsString;
  finally
    LQuery.Free;
  end;
end;

procedure TDatabaseManager.SaveSetting(const AKey, AValue: string);
var
  LQuery: TFDQuery;
begin
  LQuery := TFDQuery.Create(nil);
  try
    LQuery.Connection := FConnection;
    LQuery.SQL.Text := 'INSERT OR REPLACE INTO settings (key, value) VALUES (:key, :value)';
    LQuery.ParamByName('key').AsString := AKey;
    LQuery.ParamByName('value').AsString := AValue;
    LQuery.ExecSQL;
  finally
    LQuery.Free;
  end;
end;

end.
