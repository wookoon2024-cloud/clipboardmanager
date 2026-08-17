unit uLog;

interface

uses
  System.SysUtils, System.IOUtils, System.Classes;

const
  APP_VERSION = 'v1.1.7';

procedure LogMsg(const AMsg: string);

implementation

procedure LogMsg(const AMsg: string);
var
  LFile, LLine: string;
begin
  try
    LFile := TPath.Combine(TPath.GetDirectoryName(ParamStr(0)), 'debug_log.txt');
    LLine := FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', Now) + ' ' + AMsg + sLineBreak;
    TFile.AppendAllText(LFile, LLine, TEncoding.UTF8);
  except
  end;
end;

end.
