object HistoryPopupForm: THistoryPopupForm
  Left = 0
  Top = 0
  BorderStyle = bsNone
  Caption = 'Clipboard History'
  ClientHeight = 460
  ClientWidth = 480
  Color = 2761761
  DoubleBuffered = True
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  OldCreateOrder = False
  OnCreate = FormCreate
  OnDeactivate = FormDeactivate
  OnDestroy = FormDestroy
  PixelsPerInch = 96
  TextHeight = 15
  object PanelHeader: TPanel
    Left = 0
    Top = 0
    Width = 480
    Height = 32
    Align = alTop
    BevelOuter = bvNone
    Color = 2761761
    ParentBackground = False
    TabOrder = 0
    object LabelTitle: TLabel
      Left = 14
      Top = 8
      Width = 95
      Height = 15
      Caption = 'Clipboard History'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = 15132390
      Font.Height = -12
      Font.Name = 'Segoe UI'
      Font.Style = []
      ParentFont = False
    end
    object PanelHeaderBtns: TPanel
      Left = 320
      Top = 0
      Width = 160
      Height = 32
      Align = alRight
      BevelOuter = bvNone
      Color = 2761761
      ParentBackground = False
      TabOrder = 0
      object BtnPin: TSpeedButton
        Left = 76
        Top = 4
        Width = 24
        Height = 24
        Caption = #128204
        Flat = True
        Font.Charset = DEFAULT_CHARSET
        Font.Color = 15132390
        Font.Height = -13
        Font.Name = 'Segoe UI Symbol'
        Font.Style = []
        ParentFont = False
        OnClick = BtnPinClick
      end
      object BtnSettings: TSpeedButton
        Left = 104
        Top = 4
        Width = 24
        Height = 24
        Caption = #9881
        Flat = True
        Font.Charset = DEFAULT_CHARSET
        Font.Color = 15132390
        Font.Height = -14
        Font.Name = 'Segoe UI Symbol'
        Font.Style = []
        ParentFont = False
        OnClick = BtnSettingsClick
      end
      object BtnClose: TSpeedButton
        Left = 132
        Top = 4
        Width = 24
        Height = 24
        Caption = #10005
        Flat = True
        Font.Charset = DEFAULT_CHARSET
        Font.Color = 15132390
        Font.Height = -13
        Font.Name = 'Segoe UI Symbol'
        Font.Style = []
        ParentFont = False
        OnClick = BtnCloseClick
      end
    end
  end
  object PanelPaging: TPanel
    Left = 0
    Top = 32
    Width = 480
    Height = 24
    Align = alTop
    BevelOuter = bvNone
    Color = 3551534
    ParentBackground = False
    TabOrder = 1
    object LabelBtnPrev: TLabel
      Left = 0
      Top = 0
      Width = 60
      Height = 24
      Align = alLeft
      Alignment = taCenter
      AutoSize = False
      Caption = #9664' Prev'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = 15132390
      Font.Height = -11
      Font.Name = 'Segoe UI'
      Font.Style = []
      ParentFont = False
      Layout = tlCenter
      OnClick = LabelBtnPrevClick
    end
    object LabelBtnNext: TLabel
      Left = 420
      Top = 0
      Width = 60
      Height = 24
      Align = alRight
      Alignment = taCenter
      AutoSize = False
      Caption = 'Next '#9654
      Font.Charset = DEFAULT_CHARSET
      Font.Color = 15132390
      Font.Height = -11
      Font.Name = 'Segoe UI'
      Font.Style = []
      ParentFont = False
      Layout = tlCenter
      OnClick = LabelBtnNextClick
    end
    object LabelPageInfo: TLabel
      Left = 60
      Top = 0
      Width = 360
      Height = 24
      Align = alClient
      Alignment = taCenter
      Caption = '1 / 1  (총 0개)'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = 11842740
      Font.Height = -11
      Font.Name = 'Segoe UI'
      Font.Style = []
      ParentFont = False
      Layout = tlCenter
    end
  end
  object ListBoxClips: TListBox
    Left = 0
    Top = 56
    Width = 480
    Height = 388
    Align = alClient
    BorderStyle = bsNone
    Color = 2761761
    DoubleBuffered = True
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWhite
    Font.Height = -12
    Font.Name = 'Segoe UI'
    Font.Style = []
    ItemHeight = 25
    ParentFont = False
    Style = lbOwnerDrawFixed
    TabOrder = 2
    OnDblClick = ListBoxClipsDblClick
    OnDrawItem = ListBoxClipsDrawItem
    OnKeyDown = ListBoxClipsKeyDown
    OnMouseDown = ListBoxClipsMouseDown
    OnMouseMove = ListBoxClipsMouseMove
  end
  object PanelBottomBar: TPanel
    Left = 0
    Top = 444
    Width = 480
    Height = 16
    Align = alBottom
    BevelOuter = bvNone
    Color = 2761761
    ParentBackground = False
    TabOrder = 3
    object PaintBoxGrip: TPaintBox
      Left = 464
      Top = 0
      Width = 16
      Height = 16
      Align = alRight
      OnMouseDown = GripMouseDown
      OnPaint = PaintBoxGripPaint
    end
  end
  object TimerHoverCheck: TTimer
    Enabled = False
    Interval = 100
    OnTimer = TimerHoverCheckTimer
    Left = 240
    Top = 232
  end
  object PopupMenuClip: TPopupMenu
    Left = 240
    Top = 160
    object MenuPinClip: TMenuItem
      Caption = '상단 고정'
      OnClick = MenuPinClipClick
    end
    object MenuEditFav: TMenuItem
      Caption = '즐겨찾기 수정'
      OnClick = MenuEditFavClick
    end
    object MenuToggleFav: TMenuItem
      Caption = '즐겨찾기 토글'
      OnClick = MenuToggleFavClick
    end
    object MenuDeleteClip: TMenuItem
      Caption = '삭제'
      OnClick = MenuDeleteClipClick
    end
  end
end
