module Ultraviolet
  module Ansi
    # C0 control codes
    NUL = 0x00
    SOH = 0x01
    STX = 0x02
    ETX = 0x03
    EOT = 0x04
    ENQ = 0x05
    ACK = 0x06
    BEL = 0x07
    BS  = 0x08
    HT  = 0x09
    LF  = 0x0a
    VT  = 0x0b
    FF  = 0x0c
    CR  = 0x0d
    SO  = 0x0e
    SI  = 0x0f
    DLE = 0x10
    DC1 = 0x11
    DC2 = 0x12
    DC3 = 0x13
    DC4 = 0x14
    NAK = 0x15
    SYN = 0x16
    ETB = 0x17
    CAN = 0x18
    EM  = 0x19
    SUB = 0x1a
    ESC = 0x1b
    FS  = 0x1c
    GS  = 0x1d
    RS  = 0x1e
    US  = 0x1f

    SP  = 0x20
    DEL = 0x7f

    # C1 control codes
    PAD = 0x80
    SS3 = 0x8f
    DCS = 0x90
    SOS = 0x98
    CSI = 0x9b
    ST  = 0x9c
    OSC = 0x9d
    PM  = 0x9e
    APC = 0x9f

    # Kitty keyboard enhancement flags
    KittyDisambiguateEscapeCodes    = 1 << 0
    KittyReportEventTypes           = 1 << 1
    KittyReportAlternateKeys        = 1 << 2
    KittyReportAllKeysAsEscapeCodes = 1 << 3
    KittyReportAssociatedText       = 1 << 4

    alias Cmd = Int32

    module Parser
      PrefixShift   =  8
      IntermedShift = 16
      MaxParamsSize = 32
    end

    struct Param
      property value : Int32
      property? has_more : Bool
      property? present : Bool

      def initialize(@value : Int32 = 0, @has_more : Bool = false, @present : Bool = false)
      end

      def param(default : Int32) : Int32
        return default unless @present
        @value
      end

      def has_more? : Bool
        @has_more
      end
    end

    struct Params
      include Enumerable(Param)

      getter params : Array(Param)

      def initialize(@params : Array(Param))
      end

      def each(&block : Param ->) : Nil
        @params.each do |param|
          block.call(param)
        end
      end

      def size : Int32
        @params.size
      end

      def [](index : Int32) : Param
        @params[index]
      end

      def empty? : Bool
        @params.empty?
      end

      def param(index : Int32, default : Int32) : {Int32, Bool, Bool}
        return {default, false, false} if index < 0 || index >= @params.size
        param = @params[index]
        return {default, param.has_more?, false} unless param.present?
        {param.value, param.has_more?, true}
      end
    end

    # Mode settings for mode report (DECRPM)
    ModeNotRecognized    = 0
    ModeSet              = 1
    ModeReset            = 2
    ModePermanentlySet   = 3
    ModePermanentlyReset = 4

    struct ANSIMode
      getter value : Int32

      def initialize(@value : Int32)
      end

      def mode : Int32
        @value
      end
    end

    struct DECMode
      getter value : Int32

      def initialize(@value : Int32)
      end

      def mode : Int32
        @value
      end
    end

    struct BasicColor
      getter value : UInt8

      def initialize(@value : UInt8)
      end

      def +(other : BasicColor) : BasicColor
        BasicColor.new(@value + other.value)
      end

      def to_color : Color
        case @value
        when  0 then Color.new(0x00_u8, 0x00_u8, 0x00_u8) # Black
        when  1 then Color.new(0x80_u8, 0x00_u8, 0x00_u8) # Red
        when  2 then Color.new(0x00_u8, 0x80_u8, 0x00_u8) # Green
        when  3 then Color.new(0x80_u8, 0x80_u8, 0x00_u8) # Yellow
        when  4 then Color.new(0x00_u8, 0x00_u8, 0x80_u8) # Blue
        when  5 then Color.new(0x80_u8, 0x00_u8, 0x80_u8) # Magenta
        when  6 then Color.new(0x00_u8, 0x80_u8, 0x80_u8) # Cyan
        when  7 then Color.new(0xc0_u8, 0xc0_u8, 0xc0_u8) # White
        when  8 then Color.new(0x80_u8, 0x80_u8, 0x80_u8) # BrightBlack
        when  9 then Color.new(0xff_u8, 0x00_u8, 0x00_u8) # BrightRed
        when 10 then Color.new(0x00_u8, 0xff_u8, 0x00_u8) # BrightGreen
        when 11 then Color.new(0xff_u8, 0xff_u8, 0x00_u8) # BrightYellow
        when 12 then Color.new(0x00_u8, 0x00_u8, 0xff_u8) # BrightBlue
        when 13 then Color.new(0xff_u8, 0x00_u8, 0xff_u8) # BrightMagenta
        when 14 then Color.new(0x00_u8, 0xff_u8, 0xff_u8) # BrightCyan
        when 15 then Color.new(0xff_u8, 0xff_u8, 0xff_u8) # BrightWhite
        else         Color.new(0x00_u8, 0x00_u8, 0x00_u8)
        end
      end
    end

    Black         = BasicColor.new(0_u8)
    Red           = BasicColor.new(1_u8)
    Green         = BasicColor.new(2_u8)
    Yellow        = BasicColor.new(3_u8)
    Blue          = BasicColor.new(4_u8)
    Magenta       = BasicColor.new(5_u8)
    Cyan          = BasicColor.new(6_u8)
    White         = BasicColor.new(7_u8)
    BrightBlack   = BasicColor.new(8_u8)
    BrightRed     = BasicColor.new(9_u8)
    BrightGreen   = BasicColor.new(10_u8)
    BrightYellow  = BasicColor.new(11_u8)
    BrightBlue    = BasicColor.new(12_u8)
    BrightMagenta = BasicColor.new(13_u8)
    BrightCyan    = BasicColor.new(14_u8)
    BrightWhite   = BasicColor.new(15_u8)

    alias Mode = ANSIMode | DECMode

    def self.set_mode(*modes : Mode) : String
      set_mode(false, modes.to_a)
    end

    def self.sm(*modes : Mode) : String
      set_mode(*modes)
    end

    def self.decset(*modes : Mode) : String
      set_mode(*modes)
    end

    def self.reset_mode(*modes : Mode) : String
      set_mode(true, modes.to_a)
    end

    def self.rm(*modes : Mode) : String
      reset_mode(*modes)
    end

    def self.decrst(*modes : Mode) : String
      reset_mode(*modes)
    end

    def self.request_mode(mode : Mode) : String
      prefix = mode.is_a?(DECMode) ? "?" : ""
      "\e[#{prefix}#{mode.mode}$p"
    end

    def self.decrqm(mode : Mode) : String
      request_mode(mode)
    end

    def self.report_mode(mode : Mode, value : Int32) : String
      value = 0 if value < 0 || value > 4
      if mode.is_a?(DECMode)
        "\e[?#{mode.mode};#{value}$y"
      else
        "\e[#{mode.mode};#{value}$y"
      end
    end

    def self.decrpm(mode : Mode, value : Int32) : String
      report_mode(mode, value)
    end

    private def self.set_mode(reset : Bool, modes : Array(Mode)) : String
      return "" if modes.empty?

      cmd = reset ? "l" : "h"
      seq = "\e["
      if modes.size == 1
        prefix = modes[0].is_a?(DECMode) ? "?" : ""
        return "#{seq}#{prefix}#{modes[0].mode}#{cmd}"
      end

      ansi = [] of String
      dec = [] of String
      modes.each do |mode|
        if mode.is_a?(DECMode)
          dec << mode.mode.to_s
        else
          ansi << mode.mode.to_s
        end
      end

      result = ""
      result += "#{seq}#{ansi.join(";")}#{cmd}" unless ansi.empty?
      result += "#{seq}?#{dec.join(";")}#{cmd}" unless dec.empty?
      result
    end

    # Modes (subset used in tests)
    KeyboardActionMode      =    2
    BracketedPasteMode      = 2004
    AltScreenSaveCursorMode = 1049

    ModeKeyboardAction        = ANSIMode.new(2)
    KAM                       = ModeKeyboardAction
    SetModeKeyboardAction     = "\e[2h"
    ResetModeKeyboardAction   = "\e[2l"
    RequestModeKeyboardAction = "\e[2$p"

    ModeInsertReplace        = ANSIMode.new(4)
    IRM                      = ModeInsertReplace
    SetModeInsertReplace     = "\e[4h"
    ResetModeInsertReplace   = "\e[4l"
    RequestModeInsertReplace = "\e[4$p"

    ModeBiDirectionalSupport        = ANSIMode.new(8)
    BDSM                            = ModeBiDirectionalSupport
    SetModeBiDirectionalSupport     = "\e[8h"
    ResetModeBiDirectionalSupport   = "\e[8l"
    RequestModeBiDirectionalSupport = "\e[8$p"

    ModeSendReceive        = ANSIMode.new(12)
    ModeLocalEcho          = ModeSendReceive
    SRM                    = ModeSendReceive
    SetModeSendReceive     = "\e[12h"
    ResetModeSendReceive   = "\e[12l"
    RequestModeSendReceive = "\e[12$p"
    SetModeLocalEcho       = "\e[12h"
    ResetModeLocalEcho     = "\e[12l"
    RequestModeLocalEcho   = "\e[12$p"

    ModeLineFeedNewLine        = ANSIMode.new(20)
    LNM                        = ModeLineFeedNewLine
    SetModeLineFeedNewLine     = "\e[20h"
    ResetModeLineFeedNewLine   = "\e[20l"
    RequestModeLineFeedNewLine = "\e[20$p"

    ModeCursorKeys        = DECMode.new(1)
    DECCKM                = ModeCursorKeys
    SetModeCursorKeys     = "\e[?1h"
    ResetModeCursorKeys   = "\e[?1l"
    RequestModeCursorKeys = "\e[?1$p"

    ModeOrigin        = DECMode.new(6)
    DECOM             = ModeOrigin
    SetModeOrigin     = "\e[?6h"
    ResetModeOrigin   = "\e[?6l"
    RequestModeOrigin = "\e[?6$p"

    ModeAutoWrap        = DECMode.new(7)
    DECAWM              = ModeAutoWrap
    SetModeAutoWrap     = "\e[?7h"
    ResetModeAutoWrap   = "\e[?7l"
    RequestModeAutoWrap = "\e[?7$p"

    ModeMouseX10        = DECMode.new(9)
    SetModeMouseX10     = "\e[?9h"
    ResetModeMouseX10   = "\e[?9l"
    RequestModeMouseX10 = "\e[?9$p"

    ModeTextCursorEnable        = DECMode.new(25)
    DECTCEM                     = ModeTextCursorEnable
    SetModeTextCursorEnable     = "\e[?25h"
    ResetModeTextCursorEnable   = "\e[?25l"
    RequestModeTextCursorEnable = "\e[?25$p"
    ShowCursor                  = SetModeTextCursorEnable
    HideCursor                  = ResetModeTextCursorEnable

    ModeNumericKeypad        = DECMode.new(66)
    DECNKM                   = ModeNumericKeypad
    SetModeNumericKeypad     = "\e[?66h"
    ResetModeNumericKeypad   = "\e[?66l"
    RequestModeNumericKeypad = "\e[?66$p"

    ModeBackarrowKey        = DECMode.new(67)
    DECBKM                  = ModeBackarrowKey
    SetModeBackarrowKey     = "\e[?67h"
    ResetModeBackarrowKey   = "\e[?67l"
    RequestModeBackarrowKey = "\e[?67$p"

    ModeLeftRightMargin        = DECMode.new(69)
    DECLRMM                    = ModeLeftRightMargin
    SetModeLeftRightMargin     = "\e[?69h"
    ResetModeLeftRightMargin   = "\e[?69l"
    RequestModeLeftRightMargin = "\e[?69$p"

    ModeMouseNormal        = DECMode.new(1000)
    SetModeMouseNormal     = "\e[?1000h"
    ResetModeMouseNormal   = "\e[?1000l"
    RequestModeMouseNormal = "\e[?1000$p"

    ModeMouseHighlight        = DECMode.new(1001)
    SetModeMouseHighlight     = "\e[?1001h"
    ResetModeMouseHighlight   = "\e[?1001l"
    RequestModeMouseHighlight = "\e[?1001$p"

    ModeMouseButtonEvent        = DECMode.new(1002)
    SetModeMouseButtonEvent     = "\e[?1002h"
    ResetModeMouseButtonEvent   = "\e[?1002l"
    RequestModeMouseButtonEvent = "\e[?1002$p"

    ModeMouseAnyEvent        = DECMode.new(1003)
    SetModeMouseAnyEvent     = "\e[?1003h"
    ResetModeMouseAnyEvent   = "\e[?1003l"
    RequestModeMouseAnyEvent = "\e[?1003$p"

    ModeFocusEvent        = DECMode.new(1004)
    SetModeFocusEvent     = "\e[?1004h"
    ResetModeFocusEvent   = "\e[?1004l"
    RequestModeFocusEvent = "\e[?1004$p"

    ModeMouseExtSgr        = DECMode.new(1006)
    SetModeMouseExtSgr     = "\e[?1006h"
    ResetModeMouseExtSgr   = "\e[?1006l"
    RequestModeMouseExtSgr = "\e[?1006$p"

    ModeMouseExtUtf8        = DECMode.new(1005)
    SetModeMouseExtUtf8     = "\e[?1005h"
    ResetModeMouseExtUtf8   = "\e[?1005l"
    RequestModeMouseExtUtf8 = "\e[?1005$p"

    ModeMouseExtUrxvt        = DECMode.new(1015)
    SetModeMouseExtUrxvt     = "\e[?1015h"
    ResetModeMouseExtUrxvt   = "\e[?1015l"
    RequestModeMouseExtUrxvt = "\e[?1015$p"

    ModeMouseExtSgrPixel        = DECMode.new(1016)
    SetModeMouseExtSgrPixel     = "\e[?1016h"
    ResetModeMouseExtSgrPixel   = "\e[?1016l"
    RequestModeMouseExtSgrPixel = "\e[?1016$p"

    ModeAltScreen        = DECMode.new(1047)
    SetModeAltScreen     = "\e[?1047h"
    ResetModeAltScreen   = "\e[?1047l"
    RequestModeAltScreen = "\e[?1047$p"

    ModeSaveCursor        = DECMode.new(1048)
    SetModeSaveCursor     = "\e[?1048h"
    ResetModeSaveCursor   = "\e[?1048l"
    RequestModeSaveCursor = "\e[?1048$p"

    ModeAltScreenSaveCursor        = DECMode.new(1049)
    SetModeAltScreenSaveCursor     = "\e[?1049h"
    ResetModeAltScreenSaveCursor   = "\e[?1049l"
    RequestModeAltScreenSaveCursor = "\e[?1049$p"

    ModeBracketedPaste        = DECMode.new(2004)
    SetModeBracketedPaste     = "\e[?2004h"
    ResetModeBracketedPaste   = "\e[?2004l"
    RequestModeBracketedPaste = "\e[?2004$p"

    ModeSynchronizedOutput        = DECMode.new(2026)
    SetModeSynchronizedOutput     = "\e[?2026h"
    ResetModeSynchronizedOutput   = "\e[?2026l"
    RequestModeSynchronizedOutput = "\e[?2026$p"

    ModeUnicodeCore        = DECMode.new(2027)
    SetModeUnicodeCore     = "\e[?2027h"
    ResetModeUnicodeCore   = "\e[?2027l"
    RequestModeUnicodeCore = "\e[?2027$p"

    ModeLightDark        = DECMode.new(2031)
    SetModeLightDark     = "\e[?2031h"
    ResetModeLightDark   = "\e[?2031l"
    RequestModeLightDark = "\e[?2031$p"

    ModeInBandResize        = DECMode.new(2048)
    SetModeInBandResize     = "\e[?2048h"
    ResetModeInBandResize   = "\e[?2048l"
    RequestModeInBandResize = "\e[?2048$p"

    ModeWin32Input        = DECMode.new(9001)
    SetModeWin32Input     = "\e[?9001h"
    ResetModeWin32Input   = "\e[?9001l"
    RequestModeWin32Input = "\e[?9001$p"

    # XParseColor returns a color from X-style strings such as "rgb:ff/00/ff".
    def self.x_parse_color(value : String) : Color
      v = value.strip
      if v.starts_with?('#')
        return parse_hex_color(v[1..])
      end

      if v.starts_with?("rgb:")
        return parse_rgb_color(v[4..])
      end

      parse_hex_color(v)
    end

    private def self.parse_hex_color(value : String) : Color
      hex = value
      if hex.size == 3
        r = (hex[0].to_s * 2).to_i(16)
        g = (hex[1].to_s * 2).to_i(16)
        b = (hex[2].to_s * 2).to_i(16)
        return Color.new(r.to_u8, g.to_u8, b.to_u8)
      end
      if hex.size == 6
        r = hex[0, 2].to_i(16)
        g = hex[2, 2].to_i(16)
        b = hex[4, 2].to_i(16)
        return Color.new(r.to_u8, g.to_u8, b.to_u8)
      end
      if hex.size == 12
        r = scale_hex_component(hex[0, 4])
        g = scale_hex_component(hex[4, 4])
        b = scale_hex_component(hex[8, 4])
        return Color.new(r, g, b)
      end

      Color.new(0_u8, 0_u8, 0_u8)
    end

    private def self.parse_rgb_color(value : String) : Color
      parts = value.split('/')
      return Color.new(0_u8, 0_u8, 0_u8) unless parts.size == 3

      r = scale_hex_component(parts[0])
      g = scale_hex_component(parts[1])
      b = scale_hex_component(parts[2])
      Color.new(r, g, b)
    end

    private def self.scale_hex_component(component : String) : UInt8
      return 0_u8 if component.empty?
      value = component.to_i(16)
      max = (1 << (component.size * 4)) - 1
      scaled = (value * 255) // max
      scaled.to_u8
    end

    def self.cursor_position(col : Int32, row : Int32) : String
      return "\e[H" if row == 1 && col == 1
      "\e[#{row};#{col}H"
    end

    def self.vertical_position_absolute(row : Int32) : String
      "\e[#{row}d"
    end

    def self.horizontal_position_absolute(col : Int32) : String
      "\e[#{col}`"
    end

    def self.cursor_horizontal_absolute(col : Int32) : String
      "\e[#{col}G"
    end

    def self.cursor_forward(count : Int32) : String
      "\e[#{count}C"
    end

    def self.cursor_backward(count : Int32) : String
      "\e[#{count}D"
    end

    def self.cursor_up(count : Int32) : String
      "\e[#{count}A"
    end

    def self.cursor_down(count : Int32) : String
      "\e[#{count}B"
    end

    def self.cursor_horizontal_forward_tab(count : Int32) : String
      "\e[#{count}I"
    end

    def self.cursor_horizontal_backward_tab(count : Int32) : String
      "\e[#{count}Z"
    end

    def self.erase_character(count : Int32) : String
      "\e[#{count}X"
    end

    def self.repeat_previous_character(count : Int32) : String
      "\e[#{count}b"
    end

    def self.erase_line_right : String
      "\e[K"
    end

    def self.erase_line_left : String
      "\e[1K"
    end

    def self.erase_screen_below : String
      "\e[J"
    end

    def self.erase_entire_screen : String
      "\e[2J"
    end

    def self.cursor_home_position : String
      "\e[H"
    end

    def self.delete_line(count : Int32) : String
      return "\e[M" if count == 1
      "\e[#{count}M"
    end

    def self.insert_line(count : Int32) : String
      return "\e[L" if count == 1
      "\e[#{count}L"
    end

    def self.scroll_up(count : Int32) : String
      "\e[#{count}S"
    end

    def self.scroll_down(count : Int32) : String
      "\e[#{count}T"
    end

    def self.reverse_index : String
      "\eM"
    end

    def self.set_top_bottom_margins(top : Int32, bottom : Int32) : String
      "\e[#{top};#{bottom}r"
    end

    def self.delete_character(count : Int32) : String
      return "\e[P" if count == 1
      "\e[#{count}P"
    end

    def self.insert_character(count : Int32) : String
      return "\e[@" if count == 1
      "\e[#{count}@"
    end

    def self.set_mode_insert_replace : String
      "\e[4h"
    end

    def self.reset_mode_insert_replace : String
      "\e[4l"
    end

    def self.set_mode_auto_wrap : String
      "\e[?7h"
    end

    def self.reset_mode_auto_wrap : String
      "\e[?7l"
    end

    def self.reset_style : String
      "\e[m"
    end

    def self.set_hyperlink(url : String, params : String) : String
      return reset_hyperlink if url.empty?
      "\e]8;#{params};#{url}\a"
    end

    def self.reset_hyperlink : String
      "\e]8;;\a"
    end

    def self.string_width(value : String) : Int32
      UnicodeCharWidth.width(Ultraviolet.strip_ansi(value))
    end
  end
end
