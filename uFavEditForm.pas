unit uFavEditForm;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ExtCtrls;

type
  TFavEditForm = class(TForm)
    LabelTitle: TLabel;
    LabelContent: TLabel;
    EditTitle: TEdit;
    MemoContent: TMemo;
    BtnSave: TButton;
    BtnCancel: TButton;
    procedure BtnSaveClick(Sender: TObject);
    procedure BtnCancelClick(Sender: TObject);
  public
    class function Execute(AParentForm: TCustomForm; var ATitle, AContent: string): Boolean;
  end;

var
  FavEditForm: TFavEditForm;

implementation

{$R *.dfm}

procedure TFavEditForm.BtnSaveClick(Sender: TObject);
begin
  ModalResult := mrOk;
end;

procedure TFavEditForm.BtnCancelClick(Sender: TObject);
begin
  ModalResult := mrCancel;
end;

class function TFavEditForm.Execute(AParentForm: TCustomForm; var ATitle, AContent: string): Boolean;
var
  LForm: TFavEditForm;
begin
  Result := False;
  LForm := TFavEditForm.Create(nil);
  try
    if Assigned(AParentForm) then
      LForm.PopupParent := AParentForm;
      
    LForm.EditTitle.Text := ATitle;
    LForm.MemoContent.Text := AContent;
    
    if LForm.ShowModal = mrOk then
    begin
      ATitle := Trim(LForm.EditTitle.Text);
      AContent := LForm.MemoContent.Text;
      Result := True;
    end;
  finally
    LForm.Free;
  end;
end;

end.
