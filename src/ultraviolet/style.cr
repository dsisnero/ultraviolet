module Ultraviolet
  struct Color
    getter r : UInt8
    getter g : UInt8
    getter b : UInt8

    def initialize(@r : UInt8, @g : UInt8, @b : UInt8)
    end

    def to_fg_ansi : String
      "\e[38;2;#{@r};#{@g};#{@b}m"
    end

    def to_bg_ansi : String
      "\e[48;2;#{@r};#{@g};#{@b}m"
    end

    def to_underline_ansi : String
      "\e[58;2;#{@r};#{@g};#{@b}m"
    end
  end

  enum Underline
    None
    Single
    Double
    Curly
    Dotted
    Dashed
  end

  module Attr
    BOLD            = 1_u8 << 0
    FAINT           = 1_u8 << 1
    ITALIC          = 1_u8 << 2
    BLINK           = 1_u8 << 3
    RAPID_BLINK     = 1_u8 << 4
    REVERSE         = 1_u8 << 5
    CONCEAL         = 1_u8 << 6
    STRIKETHROUGH   = 1_u8 << 7
    RESET           = 0_u8
  end

  struct Style
    getter fg : Color?
    getter bg : Color?
    getter underline_color : Color?
    getter underline : Underline
    getter attrs : UInt8

    def initialize(
      @fg : Color? = nil,
      @bg : Color? = nil,
      @underline_color : Color? = nil,
      @underline : Underline = Underline::None,
      @attrs : UInt8 = Attr::RESET
    )
    end

    def zero? : Bool
      @fg.nil? && @bg.nil? && @underline_color.nil? &&
        @underline == Underline::None && @attrs == Attr::RESET
    end

    def styled(str : String) : String
      return str if zero?
      "#{string}#{str}\e[0m"
    end

    def string : String
      return "\e[0m" if zero?

      parts = [] of String

      if (@attrs & Attr::BOLD) != 0
        parts << "1"
      end
      if (@attrs & Attr::FAINT) != 0
        parts << "2"
      end
      if (@attrs & Attr::ITALIC) != 0
        parts << "3"
      end
      if @underline == Underline::Single
        parts << "4"
      elsif @underline != Underline::None
        parts << "4:#{underline_code(@underline)}"
      end
      if (@attrs & Attr::BLINK) != 0
        parts << "5"
      end
      if (@attrs & Attr::RAPID_BLINK) != 0
        parts << "6"
      end
      if (@attrs & Attr::REVERSE) != 0
        parts << "7"
      end
      if (@attrs & Attr::CONCEAL) != 0
        parts << "8"
      end
      if (@attrs & Attr::STRIKETHROUGH) != 0
        parts << "9"
      end

      seq = parts.empty? ? "" : "\e[#{parts.join(';')}m"
      if color = @fg
        seq += color.to_fg_ansi
      end
      if color = @bg
        seq += color.to_bg_ansi
      end
      if color = @underline_color
        seq += color.to_underline_ansi
      end

      seq
    end

    def diff(from : Style?) : String
      Style.diff(from, self)
    end

    def self.diff(from : Style?, to : Style?) : String
      return "" if from.nil? && to.nil?
      return "" if !from.nil? && !to.nil? && from == to
      return to.not_nil!.string if from.nil?
      return "\e[0m" if to.nil? || to.zero?
      to.string
    end

    private def underline_code(value : Underline) : Int32
      case value
      when Underline::Double
        2
      when Underline::Curly
        3
      when Underline::Dotted
        4
      when Underline::Dashed
        5
      else
        1
      end
    end
  end
end
