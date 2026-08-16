object FavEditForm: TFavEditForm
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  Caption = '즐겨찾기 등록 / 편집'
  ClientHeight = 280
  ClientWidth = 420
  Color = 2761761
  DoubleBuffered = True
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  FormStyle = fsStayOnTop
  OldCreateOrder = False
  Position = poScreenCenter
  PixelsPerInch = 96
  TextHeight = 15
  object LabelTitle: TLabel
    Left = 20
    Top = 16
    Width = 24
    Height = 15
    Caption = '제목:'
    Font.Charset = DEFAULT_CHARSET
    Font.Color = 15132390
    Font.Height = -12
    Font.Name = 'Segoe UI'
    Font.Style = []
    ParentFont = False
  end
  object LabelContent: TLabel
    Left = 20
    Top = 72
    Width = 24
    Height = 15
    Caption = '내용:'
    Font.Charset = DEFAULT_CHARSET
    Font.Color = 15132390
    Font.Height = -12
    Font.Name = 'Segoe UI'
    Font.Style = []
    ParentFont = False
  end
  object EditTitle: TEdit
    Left = 20
    Top = 36
    Width = 380
    Height = 25
    Font.Charset = DEFAULT_CHARSET
    Font.Color = 2236962
    Font.Height = -13
    Font.Name = 'Segoe UI'
    Font.Style = []
    ParentFont = False
    TabOrder = 0
  end
  object MemoContent: TMemo
    Left = 20
    Top = 92
    Width = 380
    Height = 135
    Font.Charset = DEFAULT_CHARSET
    Font.Color = 2236962
    Font.Height = -12
    Font.Name = 'Segoe UI'
    Font.Style = []
    ParentFont = False
    ScrollBars = ssVertical
    TabOrder = 1
  end
  object BtnSave: TButton
    Left = 230
    Top = 238
    Width = 80
    Height = 28
    Caption = '저장'
    Default = True
    ModalResult = 1
    TabOrder = 2
    OnClick = BtnSaveClick
  end
  object BtnCancel: TButton
    Left = 320
    Top = 238
    Width = 80
    Height = 28
    Cancel = True
    Caption = '취소'
    ModalResult = 2
    TabOrder = 3
    OnClick = BtnCancelClick
  end
end
