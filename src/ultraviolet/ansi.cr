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

    # Modes (subset used in tests)
    KeyboardActionMode      =    2
    BracketedPasteMode      = 2004
    AltScreenSaveCursorMode = 1049

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
