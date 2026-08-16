object MainForm: TMainForm
  Left = 0
  Top = 0
  BorderIcons = [biSystemMenu, biMinimize]
  BorderStyle = bsSingle
  Caption = '멀티 클립보드 매니저 환경 설정'
  ClientHeight = 440
  ClientWidth = 630
  Color = 2761761
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  OldCreateOrder = False
  Position = poScreenCenter
  OnClose = FormClose
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  PixelsPerInch = 96
  TextHeight = 15
  object PanelLeft: TPanel
    Left = 0
    Top = 0
    Width = 190
    Height = 395
    Align = alLeft
    BevelOuter = bvNone
    Color = 2761761
    Padding.Left = 6
    Padding.Top = 14
    Padding.Right = 6
    Padding.Bottom = 10
    ParentBackground = False
    TabOrder = 0
    object TreeViewNav: TTreeView
      Left = 6
      Top = 14
      Width = 178
      Height = 371
      Align = alClient
      BorderStyle = bsNone
      Color = 2761761
      Font.Charset = DEFAULT_CHARSET
      Font.Color = 15132390
      Font.Height = -13
      Font.Name = 'Segoe UI'
      Font.Style = []
      HideSelection = False
      Indent = 19
      ParentFont = False
      ReadOnly = True
      RowSelect = True
      ShowButtons = False
      ShowLines = False
      ShowRoot = False
      TabOrder = 0
      OnAdvancedCustomDrawItem = TreeViewNavAdvancedCustomDrawItem
      OnChange = TreeViewNavChange
    end
  end
  object PanelBottom: TPanel
    Left = 0
    Top = 395
    Width = 630
    Height = 45
    Align = alBottom
    BevelOuter = bvNone
    Color = 3551534
    ParentBackground = False
    TabOrder = 1
    object BtnApply: TButton
      Left = 370
      Top = 8
      Width = 75
      Height = 28
      Caption = '적용'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -12
      Font.Name = 'Segoe UI'
      Font.Style = []
      ParentFont = False
      TabOrder = 0
      OnClick = BtnApplyClick
    end
    object BtnSave: TButton
      Left = 455
      Top = 8
      Width = 80
      Height = 28
      Caption = '확인'
      Default = True
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -12
      Font.Name = 'Segoe UI'
      Font.Style = []
      ParentFont = False
      TabOrder = 1
      OnClick = BtnSaveClick
    end
    object BtnCancel: TButton
      Left = 545
      Top = 8
      Width = 75
      Height = 28
      Cancel = True
      Caption = '닫기'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -12
      Font.Name = 'Segoe UI'
      Font.Style = []
      ParentFont = False
      TabOrder = 2
      OnClick = BtnCancelClick
    end
  end
  object PanelContent: TPanel
    Left = 190
    Top = 0
    Width = 440
    Height = 395
    Align = alClient
    BevelOuter = bvNone
    Color = clWhite
    ParentBackground = False
    TabOrder = 2
    object PanelTabHotkeys: TPanel
      Left = 0
      Top = 0
      Width = 440
      Height = 395
      Align = alClient
      BevelOuter = bvNone
      Color = clWhite
      ParentBackground = False
      TabOrder = 0
      object LabelTitleHotkeys: TLabel
        Left = 24
        Top = 14
        Width = 100
        Height = 21
        Caption = '단축키 설정'
        Font.Charset = DEFAULT_CHARSET
        Font.Color = 2302755
        Font.Height = -16
        Font.Name = 'Segoe UI'
        Font.Style = []
        ParentFont = False
      end
      object LabelHotkeyPopup: TLabel
        Left = 24
        Top = 42
        Width = 142
        Height = 15
        Caption = '세로형 히스토리 팝업 단축키'
        Font.Color = 3355443
      end
      object EditHotkeyPopup: TEdit
        Left = 24
        Top = 58
        Width = 230
        Height = 23
        Font.Height = -12
        Font.Name = 'Segoe UI'
        ParentFont = False
        TabOrder = 0
        Text = 'Ctrl+Shift+V'
        OnEnter = HotkeyEditEnter
        OnExit = HotkeyEditExit
        OnKeyDown = HotkeyEditKeyDown
        OnKeyUp = HotkeyEditKeyUp
      end
      object LabelStatusPopup: TLabel
        Left = 262
        Top = 61
        Width = 145
        Height = 15
        AutoSize = False
        Caption = '✓ 사용 가능'
        Font.Charset = DEFAULT_CHARSET
        Font.Color = 32768
        Font.Height = -11
        Font.Name = 'Segoe UI'
        Font.Style = []
        ParentFont = False
      end
      object LabelHotkeyQuickBar: TLabel
        Left = 24
        Top = 86
        Width = 130
        Height = 15
        Caption = '가로형 퀵 바 토글 단축키'
        Font.Color = 3355443
      end
      object EditHotkeyQuickBar: TEdit
        Left = 24
        Top = 102
        Width = 230
        Height = 23
        Font.Height = -12
        Font.Name = 'Segoe UI'
        ParentFont = False
        TabOrder = 1
        Text = 'Ctrl+Shift+Q'
        OnEnter = HotkeyEditEnter
        OnExit = HotkeyEditExit
        OnKeyDown = HotkeyEditKeyDown
        OnKeyUp = HotkeyEditKeyUp
      end
      object LabelStatusQuickBar: TLabel
        Left = 262
        Top = 105
        Width = 145
        Height = 15
        AutoSize = False
        Caption = '✓ 사용 가능'
        Font.Charset = DEFAULT_CHARSET
        Font.Color = 32768
        Font.Height = -11
        Font.Name = 'Segoe UI'
        Font.Style = []
        ParentFont = False
      end
      object LabelHotkeySwitcher: TLabel
        Left = 24
        Top = 130
        Width = 175
        Height = 15
        Caption = '활성 앱 창전환 스위처 단축키'
        Font.Color = 3355443
      end
      object EditHotkeySwitcher: TEdit
        Left = 24
        Top = 146
        Width = 230
        Height = 23
        Font.Height = -12
        Font.Name = 'Segoe UI'
        ParentFont = False
        TabOrder = 2
        Text = 'Ctrl+Shift+W'
        OnEnter = HotkeyEditEnter
        OnExit = HotkeyEditExit
        OnKeyDown = HotkeyEditKeyDown
        OnKeyUp = HotkeyEditKeyUp
      end
      object LabelStatusSwitcher: TLabel
        Left = 262
        Top = 149
        Width = 145
        Height = 15
        AutoSize = False
        Caption = '✓ 사용 가능'
        Font.Charset = DEFAULT_CHARSET
        Font.Color = 32768
        Font.Height = -11
        Font.Name = 'Segoe UI'
        Font.Style = []
        ParentFont = False
      end
      object LabelHotkeyQuickPaste: TLabel
        Left = 24
        Top = 174
        Width = 235
        Height = 15
        Caption = '다이렉트 1~9번 붙여넣기 단축키 접두사 (+숫자)'
        Font.Color = 3355443
      end
      object EditHotkeyQuickPaste: TEdit
        Left = 24
        Top = 190
        Width = 230
        Height = 23
        Font.Height = -12
        Font.Name = 'Segoe UI'
        ParentFont = False
        TabOrder = 3
        Text = 'Ctrl'
        OnEnter = HotkeyEditEnter
        OnExit = HotkeyEditExit
        OnKeyDown = HotkeyPrefixEditKeyDown
        OnKeyUp = HotkeyEditKeyUp
      end
      object LabelStatusQuickPaste: TLabel
        Left = 262
        Top = 193
        Width = 145
        Height = 15
        AutoSize = False
        Caption = '✓ 사용 가능'
        Font.Charset = DEFAULT_CHARSET
        Font.Color = 32768
        Font.Height = -11
        Font.Name = 'Segoe UI'
        Font.Style = []
        ParentFont = False
      end
      object LabelHotkeySwitchPrefix: TLabel
        Left = 24
        Top = 218
        Width = 225
        Height = 15
        Caption = '스위치바 1~9번 창전환 단축키 접두사 (+숫자)'
        Font.Color = 3355443
      end
      object EditHotkeySwitchPrefix: TEdit
        Left = 24
        Top = 234
        Width = 230
        Height = 23
        Font.Height = -12
        Font.Name = 'Segoe UI'
        ParentFont = False
        TabOrder = 4
        Text = 'Alt'
        OnEnter = HotkeyEditEnter
        OnExit = HotkeyEditExit
        OnKeyDown = HotkeyPrefixEditKeyDown
        OnKeyUp = HotkeyEditKeyUp
      end
      object LabelStatusSwitchPrefix: TLabel
        Left = 262
        Top = 237
        Width = 145
        Height = 15
        AutoSize = False
        Caption = '✓ 사용 가능'
        Font.Charset = DEFAULT_CHARSET
        Font.Color = 32768
        Font.Height = -11
        Font.Name = 'Segoe UI'
        Font.Style = []
        ParentFont = False
      end
      object LabelHotkeyTip: TLabel
        Left = 24
        Top = 268
        Width = 380
        Height = 45
        AutoSize = False
        Caption = 
          '* 팁: 에디트 클릭 후 원하는 키보드 조합을 누르면 자동으로 입력됩니다.'#13#10 +
          '* 팝업/토글은 조합키+일반키, 접두사는 조합키(Ctrl, Alt 등)를 누르세요.'
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clGrayText
        Font.Height = -11
        Font.Name = 'Segoe UI'
        Font.Style = []
        ParentFont = False
      end
    end
    object PanelTabClipboard: TPanel
      Left = 0
      Top = 0
      Width = 440
      Height = 395
      Align = alClient
      BevelOuter = bvNone
      Color = clWhite
      ParentBackground = False
      TabOrder = 1
      object LabelTitleClipboard: TLabel
        Left = 24
        Top = 18
        Width = 100
        Height = 21
        Caption = '클립보드 관리'
        Font.Charset = DEFAULT_CHARSET
        Font.Color = 2302755
        Font.Height = -16
        Font.Name = 'Segoe UI'
        Font.Style = []
        ParentFont = False
      end
      object ChkEnableMonitoring: TCheckBox
        Left = 24
        Top = 60
        Width = 380
        Height = 24
        Caption = '백그라운드 클립보드 자동 모니터링 활성화'
        Checked = True
        State = cbChecked
        TabOrder = 0
      end
      object ChkCaptureImages: TCheckBox
        Left = 24
        Top = 95
        Width = 380
        Height = 24
        Caption = '복사한 이미지 및 화면 캡처 내역 자동 저장 (CF_BITMAP)'
        Checked = True
        State = cbChecked
        TabOrder = 1
      end
      object ChkIgnoreDuplicates: TCheckBox
        Left = 24
        Top = 130
        Width = 380
        Height = 24
        Caption = '연속으로 동일한 내용을 복사할 때 중복 저장 방지'
        Checked = True
        State = cbChecked
        TabOrder = 2
      end
      object LabelMaxClips: TLabel
        Left = 24
        Top = 175
        Width = 180
        Height = 15
        Caption = '최대 보관할 히스토리 내역 개수:'
        Font.Color = 3355443
      end
      object EditMaxClips: TEdit
        Left = 24
        Top = 195
        Width = 120
        Height = 25
        Font.Height = -13
        Font.Name = 'Segoe UI'
        ParentFont = False
        TabOrder = 3
        Text = '500'
      end
    end
    object PanelTabAppearance: TPanel
      Left = 0
      Top = 0
      Width = 440
      Height = 395
      Align = alClient
      BevelOuter = bvNone
      Color = clWhite
      ParentBackground = False
      TabOrder = 2
      object LabelTitleAppearance: TLabel
        Left = 20
        Top = 12
        Width = 100
        Height = 21
        Caption = '외형 및 테마'
        Font.Charset = DEFAULT_CHARSET
        Font.Color = 2302755
        Font.Height = -16
        Font.Name = 'Segoe UI'
        Font.Style = []
        ParentFont = False
      end
      object LabelSkinPreset: TLabel
        Left = 20
        Top = 38
        Width = 85
        Height = 15
        Caption = '스킨 색상 테마:'
        Font.Color = 3355443
      end
      object ComboSkinPreset: TComboBox
        Left = 115
        Top = 34
        Width = 175
        Height = 23
        Style = csDropDownList
        TabOrder = 0
        OnChange = ComboSkinPresetChange
        Items.Strings = (
          '모던 슬레이트 (Modern Slate)'
          '다크 챠콜 (Dark Charcoal)'
          '미드나잇 블루 (Midnight Blue)'
          '소프트 라이트 (Soft Light)'
          '사용자 정의 (Custom)')
      end
      object LabelDesignStyle: TLabel
        Left = 20
        Top = 68
        Width = 85
        Height = 15
        Caption = '디자인 스타일:'
        Font.Color = 3355443
      end
      object ComboDesignStyle: TComboBox
        Left = 115
        Top = 64
        Width = 175
        Height = 23
        Style = csDropDownList
        TabOrder = 1
        OnChange = ComboDesignStyleChange
        Items.Strings = (
          '모던 네온 라운드 (기본)'
          '클래식 플랫 (Classic Flat)'
          '소프트 아크릴 (Soft Acrylic)'
          '캡슐 미니멀 (Capsule Minimal)')
      end
      object LabelHistItemHeight: TLabel
        Left = 20
        Top = 98
        Width = 115
        Height = 15
        Caption = '히스토리 줄간격(px):'
        Font.Color = 3355443
      end
      object EditHistItemHeight: TEdit
        Left = 140
        Top = 94
        Width = 45
        Height = 23
        TabOrder = 2
        Text = '25'
      end
      object LabelHistFontSize: TLabel
        Left = 205
        Top = 98
        Width = 75
        Height = 15
        Caption = '글씨 크기(pt):'
        Font.Color = 3355443
      end
      object EditHistFontSize: TEdit
        Left = 285
        Top = 94
        Width = 40
        Height = 23
        TabOrder = 3
        Text = '8'
      end
      object GroupBoxColors: TGroupBox
        Left = 20
        Top = 124
        Width = 395
        Height = 170
        Caption = ' 부위별 색상 커스터마이징 '
        Font.Charset = DEFAULT_CHARSET
        Font.Color = 2302755
        Font.Height = -12
        Font.Name = 'Segoe UI'
        Font.Style = []
        ParentFont = False
        TabOrder = 4
        object BtnColorHistBg: TButton
          Left = 15
          Top = 26
          Width = 135
          Height = 26
          Caption = '히스토리 배경색...'
          TabOrder = 0
          OnClick = BtnColorHistBgClick
        end
        object PanelColorHistBg: TPanel
          Left = 155
          Top = 26
          Width = 26
          Height = 26
          BevelOuter = bvNone
          Color = 2761761
          ParentBackground = False
          TabOrder = 1
        end
        object BtnColorHistSelBg: TButton
          Left = 205
          Top = 26
          Width = 145
          Height = 26
          Caption = '항목 선택 배경색...'
          TabOrder = 2
          OnClick = BtnColorHistSelBgClick
        end
        object PanelColorHistSelBg: TPanel
          Left = 355
          Top = 26
          Width = 26
          Height = 26
          BevelOuter = bvNone
          Color = 6438458
          ParentBackground = False
          TabOrder = 3
        end
        object BtnColorHistText: TButton
          Left = 15
          Top = 61
          Width = 135
          Height = 26
          Caption = '히스토리 글자색...'
          TabOrder = 4
          OnClick = BtnColorHistTextClick
        end
        object PanelColorHistText: TPanel
          Left = 155
          Top = 61
          Width = 26
          Height = 26
          BevelOuter = bvNone
          Color = 15658735
          ParentBackground = False
          TabOrder = 5
        end
        object BtnColorHistSelText: TButton
          Left = 205
          Top = 61
          Width = 145
          Height = 26
          Caption = '선택 시 글자색...'
          TabOrder = 6
          OnClick = BtnColorHistSelTextClick
        end
        object PanelColorHistSelText: TPanel
          Left = 355
          Top = 61
          Width = 26
          Height = 26
          BevelOuter = bvNone
          Color = 16777215
          ParentBackground = False
          TabOrder = 7
        end
        object BtnColorBarBg: TButton
          Left = 15
          Top = 96
          Width = 135
          Height = 26
          Caption = '하단 퀵바 배경색...'
          TabOrder = 8
          OnClick = BtnColorBarBgClick
        end
        object PanelColorBarBg: TPanel
          Left = 155
          Top = 96
          Width = 26
          Height = 26
          BevelOuter = bvNone
          Color = 2761761
          ParentBackground = False
          TabOrder = 9
        end
        object BtnColorCardBg: TButton
          Left = 205
          Top = 96
          Width = 145
          Height = 26
          Caption = '하단 카드 기본색...'
          TabOrder = 10
          OnClick = BtnColorCardBgClick
        end
        object PanelColorCardBg: TPanel
          Left = 355
          Top = 96
          Width = 26
          Height = 26
          BevelOuter = bvNone
          Color = 3813934
          ParentBackground = False
          TabOrder = 11
        end
        object BtnColorCardActiveBg: TButton
          Left = 15
          Top = 131
          Width = 135
          Height = 26
          Caption = '하단 활성 카드색...'
          TabOrder = 12
          OnClick = BtnColorCardActiveBgClick
        end
        object PanelColorCardActiveBg: TPanel
          Left = 155
          Top = 131
          Width = 26
          Height = 26
          BevelOuter = bvNone
          Color = 6438458
          ParentBackground = False
          TabOrder = 13
        end
      end
      object LabelQuickbarAlpha: TLabel
        Left = 20
        Top = 298
        Width = 135
        Height = 15
        Caption = '가로형 퀵 바 투명도 조절:'
        Font.Color = 3355443
      end
      object LabelAlphaValue: TLabel
        Left = 365
        Top = 298
        Width = 40
        Height = 15
        Alignment = taRightJustify
        Caption = '88%'
        Font.Charset = DEFAULT_CHARSET
        Font.Color = 2302755
        Font.Height = -12
        Font.Name = 'Segoe UI'
        Font.Style = []
        ParentFont = False
      end
      object TrackBarAlpha: TTrackBar
        Left = 15
        Top = 316
        Width = 395
        Height = 35
        Max = 255
        Min = 100
        Position = 225
        TabOrder = 5
        OnChange = TrackBarAlphaChange
      end
      object ChkShowTooltips: TCheckBox
        Left = 20
        Top = 354
        Width = 380
        Height = 24
        Caption = '내역에 마우스를 올렸을 때 전체 내용 미리보기'
        Checked = True
        State = cbChecked
        TabOrder = 6
      end
    end
    object PanelTabGeneral: TPanel
      Left = 0
      Top = 0
      Width = 440
      Height = 395
      Align = alClient
      BevelOuter = bvNone
      Color = clWhite
      ParentBackground = False
      TabOrder = 3
      object LabelTitleGeneral: TLabel
        Left = 24
        Top = 18
        Width = 150
        Height = 21
        Caption = '일반 / 시스템 설정'
        Font.Charset = DEFAULT_CHARSET
        Font.Color = 2302755
        Font.Height = -16
        Font.Name = 'Segoe UI'
        Font.Style = []
        ParentFont = False
      end
      object ChkAutoStart: TCheckBox
        Left = 24
        Top = 60
        Width = 380
        Height = 24
        Caption = '윈도우 부팅 시 자동 실행 (시작프로그램 등록)'
        TabOrder = 0
      end
      object LabelClearInfo: TLabel
        Left = 24
        Top = 130
        Width = 380
        Height = 25
        AutoSize = False
        Caption = '* 저장된 모든 클립보드 내역을 완전히 비웁니다.'
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clGrayText
        Font.Height = -11
        Font.Name = 'Segoe UI'
        Font.Style = []
        ParentFont = False
      end
      object BtnClearDB: TButton
        Left = 24
        Top = 170
        Width = 180
        Height = 32
        Caption = '클립보드 전체 내역 삭제'
        TabOrder = 1
        OnClick = BtnClearDBClick
      end
    end
  end
  object TrayIcon: TTrayIcon
    PopupMenu = TrayMenu
    Visible = False
    OnDblClick = TrayIconDblClick
    Left = 120
    Top = 330
  end
  object TrayMenu: TPopupMenu
    Left = 140
    Top = 330
    object MenuShowSettings: TMenuItem
      Caption = '환경 설정...'
      OnClick = MenuShowSettingsClick
    end
    object MenuExit: TMenuItem
      Caption = '종료'
      OnClick = MenuExitClick
    end
  end
  object ColorDialog1: TColorDialog
    Left = 80
    Top = 330
  end
end
