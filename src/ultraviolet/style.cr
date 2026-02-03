module Ultraviolet
  struct Color
    getter r : UInt8
    getter g : UInt8
    getter b : UInt8

    def initialize(@r : UInt8, @g : UInt8, @b : UInt8)
    end

    def to_fg_ansi : String
      "\e[#{to_fg_code}m"
    end

    def to_bg_ansi : String
      "\e[#{to_bg_code}m"
    end

    def to_underline_ansi : String
      "\e[#{to_underline_code}m"
    end

    def to_fg_code : String
      "38;2;#{@r};#{@g};#{@b}"
    end

    def to_bg_code : String
      "48;2;#{@r};#{@g};#{@b}"
    end

    def to_underline_code : String
      "58;2;#{@r};#{@g};#{@b}"
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
    BOLD          = 1_u8 << 0
    FAINT         = 1_u8 << 1
    ITALIC        = 1_u8 << 2
    BLINK         = 1_u8 << 3
    RAPID_BLINK   = 1_u8 << 4
    REVERSE       = 1_u8 << 5
    CONCEAL       = 1_u8 << 6
    STRIKETHROUGH = 1_u8 << 7
    RESET         = 0_u8
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
      @attrs : UInt8 = Attr::RESET,
    )
    end

    def zero? : Bool
      @fg.nil? && @bg.nil? && @underline_color.nil? &&
        @underline == Underline::None && @attrs == Attr::RESET
    end

    def styled(str : String) : String
      return str if zero?
      "#{string}#{str}\e[m"
    end

    def string : String
      return "\e[m" if zero?

      parts = attr_codes

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
      if from.nil?
        return "" if to.nil?
        return to.string
      end
      return "\e[m" if to.nil? || to.zero?

      codes = color_diff_codes(from, to)
      codes.concat(attr_diff_codes(from, to))
      return "" if codes.empty?
      "\e[#{codes.join(';')}m"
    end

    private def attr_codes : Array(String)
      parts = [] of String
      {
        Attr::BOLD          => "1",
        Attr::FAINT         => "2",
        Attr::ITALIC        => "3",
        Attr::BLINK         => "5",
        Attr::RAPID_BLINK   => "6",
        Attr::REVERSE       => "7",
        Attr::CONCEAL       => "8",
        Attr::STRIKETHROUGH => "9",
      }.each do |flag, code|
        parts << code if (@attrs & flag) != 0
      end

      if @underline == Underline::Single
        parts << "4"
      elsif @underline != Underline::None
        parts << "4:#{Style.underline_code(@underline)}"
      end

      parts
    end

    private def self.color_equal(a : Color?, b : Color?) : Bool
      return true if a.nil? && b.nil?
      return false if a.nil? || b.nil?
      a.r == b.r && a.g == b.g && a.b == b.b
    end

    private def self.color_diff_codes(from : Style, to : Style) : Array(String)
      codes = [] of String
      unless color_equal(from.fg, to.fg)
        codes << (to.fg ? to.fg.to_fg_code : "39")
      end
      unless color_equal(from.bg, to.bg)
        codes << (to.bg ? to.bg.to_bg_code : "49")
      end
      unless color_equal(from.underline_color, to.underline_color)
        codes << (to.underline_color ? to.underline_color.to_underline_code : "59")
      end
      codes
    end

    private def self.attr_diff_codes(from : Style, to : Style) : Array(String)
      codes = [] of String

      from_flags = attr_flags(from)
      to_flags = attr_flags(to)

      bold_faint = bold_faint_diff(from_flags, to_flags)
      codes.concat(bold_faint[:codes])

      italic = italic_diff(from_flags, to_flags)
      codes.concat(italic[:codes])

      underline = underline_diff(from, to, from_flags, to_flags)
      codes.concat(underline[:codes])

      blink = blink_diff(from_flags, to_flags)
      codes.concat(blink[:codes])

      reverse = toggle_diff("27", from_flags[:reverse], to_flags[:reverse])
      conceal = toggle_diff("28", from_flags[:conceal], to_flags[:conceal])
      strike = toggle_diff("29", from_flags[:strikethrough], to_flags[:strikethrough])
      codes.concat(reverse[:codes])
      codes.concat(conceal[:codes])
      codes.concat(strike[:codes])

      codes.concat(set_bold_faint_codes(to_flags, bold_faint))
      codes.concat(set_italic_codes(to_flags, italic))
      codes.concat(set_underline_codes(to, to_flags, underline))
      codes.concat(set_blink_codes(to_flags, blink))
      codes.concat(set_toggle_codes("7", to_flags[:reverse], reverse[:changed]))
      codes.concat(set_toggle_codes("8", to_flags[:conceal], conceal[:changed]))
      codes.concat(set_toggle_codes("9", to_flags[:strikethrough], strike[:changed]))

      codes
    end

    private def self.attr_flags(style : Style)
      {
        bold:          (style.attrs & Attr::BOLD) != 0,
        faint:         (style.attrs & Attr::FAINT) != 0,
        italic:        (style.attrs & Attr::ITALIC) != 0,
        underline:     style.underline != Underline::None,
        blink:         (style.attrs & Attr::BLINK) != 0,
        rapid_blink:   (style.attrs & Attr::RAPID_BLINK) != 0,
        reverse:       (style.attrs & Attr::REVERSE) != 0,
        conceal:       (style.attrs & Attr::CONCEAL) != 0,
        strikethrough: (style.attrs & Attr::STRIKETHROUGH) != 0,
      }
    end

    private def self.bold_faint_diff(from_flags, to_flags)
      codes = [] of String
      bold_changed = from_flags[:bold] != to_flags[:bold]
      faint_changed = from_flags[:faint] != to_flags[:faint]
      if bold_changed || faint_changed
        if (from_flags[:bold] && !to_flags[:bold]) || (from_flags[:faint] && !to_flags[:faint])
          codes << "22"
          bold_changed = true
          faint_changed = true
        end
      end
      {codes: codes, bold_changed: bold_changed, faint_changed: faint_changed}
    end

    private def self.italic_diff(from_flags, to_flags)
      codes = [] of String
      changed = from_flags[:italic] != to_flags[:italic]
      codes << "23" if changed && !to_flags[:italic]
      {codes: codes, changed: changed}
    end

    private def self.underline_diff(from : Style, to : Style, from_flags, to_flags)
      codes = [] of String
      changed = from_flags[:underline] != to_flags[:underline] || from.underline != to.underline
      codes << "24" if changed && !to_flags[:underline]
      {codes: codes, changed: changed}
    end

    private def self.blink_diff(from_flags, to_flags)
      codes = [] of String
      blink_changed = from_flags[:blink] != to_flags[:blink]
      rapid_blink_changed = from_flags[:rapid_blink] != to_flags[:rapid_blink]
      if blink_changed || rapid_blink_changed
        if (from_flags[:blink] && !to_flags[:blink]) || (from_flags[:rapid_blink] && !to_flags[:rapid_blink])
          codes << "25"
          blink_changed = true
          rapid_blink_changed = true
        end
      end
      {codes: codes, blink_changed: blink_changed, rapid_blink_changed: rapid_blink_changed}
    end

    private def self.toggle_diff(code_off : String, from_on : Bool, to_on : Bool)
      codes = [] of String
      changed = from_on != to_on
      codes << code_off if changed && !to_on
      {codes: codes, changed: changed}
    end

    private def self.set_bold_faint_codes(to_flags, bold_faint)
      codes = [] of String
      codes << "1" if bold_faint[:bold_changed] && to_flags[:bold]
      codes << "2" if bold_faint[:faint_changed] && to_flags[:faint]
      codes
    end

    private def self.set_italic_codes(to_flags, italic)
      codes = [] of String
      codes << "3" if italic[:changed] && to_flags[:italic]
      codes
    end

    private def self.set_underline_codes(to : Style, to_flags, underline)
      codes = [] of String
      return codes unless underline[:changed] && to_flags[:underline]

      if to.underline == Underline::Single
        codes << "4"
      else
        codes << "4:#{underline_code(to.underline)}"
      end
      codes
    end

    private def self.set_blink_codes(to_flags, blink)
      codes = [] of String
      codes << "5" if blink[:blink_changed] && to_flags[:blink]
      codes << "6" if blink[:rapid_blink_changed] && to_flags[:rapid_blink]
      codes
    end

    private def self.set_toggle_codes(code_on : String, to_on : Bool, changed : Bool)
      codes = [] of String
      codes << code_on if changed && to_on
      codes
    end

    private def self.underline_code(value : Underline) : Int32
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
