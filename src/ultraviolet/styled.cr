require "textseg"
require "uniwidth"
require "./ansi_color"

module Ultraviolet
  class StyledString
    property text : String
    property? wrap : Bool
    property tail : String

    def initialize(@text : String = "", @wrap : Bool = false, @tail : String = "")
    end

    def to_s : String
      @text
    end

    def draw(buf : Screen, area : Rectangle) : Nil
      y = area.min.y
      while y < area.max.y
        x = area.min.x
        while x < area.max.x
          buf.set_cell(x, y, nil)
          x += 1
        end
        y += 1
      end

      str = @text.gsub("\r\n", "\n")
      Ultraviolet.print_string(buf, area.min.x, area.min.y, area, str, !@wrap, @tail)
    end

    def height : Int32
      @text.count('\n') + 1
    end

    def unicode_width : Int32
      width_height.first
    end

    def wc_width : Int32
      width_height.first
    end

    def bounds : Rectangle
      width, height = width_height
      Ultraviolet.rect(0, 0, width, height)
    end

    private def width_height : {Int32, Int32}
      lines = Ultraviolet.strip_ansi(@text).split('\n', remove_empty: false)
      height = lines.size
      width = 0
      lines.each do |line|
        width = {width, UnicodeCharWidth.width(line)}.max
      end
      {width, height}
    end
  end

  def self.strip_ansi(value : String) : String
    result = String::Builder.new
    i = 0
    last = 0
    while i < value.bytesize
      if value.byte_at(i) == 0x1b
        result << value[last, i - last] if i > last
        i = skip_escape(value, i)
        last = i
        next
      end
      i += 1
    end
    result << value[last, value.bytesize - last] if last < value.bytesize
    result.to_s
  end

  private def self.skip_escape(value : String, index : Int32) : Int32
    return index + 1 if index + 1 >= value.bytesize

    next_char = value.byte_at(index + 1)
    if next_char == '['.ord
      i = index + 2
      while i < value.bytesize
        byte = value.byte_at(i)
        return i + 1 if byte >= 0x40 && byte <= 0x7e
        i += 1
      end
      return value.bytesize
    end

    if next_char == ']'.ord
      i = index + 2
      while i < value.bytesize
        byte = value.byte_at(i)
        return i + 1 if byte == 0x07
        if byte == 0x1b && i + 1 < value.bytesize && value.byte_at(i + 1) == '\\'.ord
          return i + 2
        end
        i += 1
      end
    end

    index + 1
  end

  # ameba:disable Metrics/CyclomaticComplexity
  def self.print_string(
    screen : Screen,
    start_x : Int32,
    start_y : Int32,
    bounds : Rectangle,
    value : String,
    truncate : Bool,
    tail : String,
  ) : Nil
    x = start_x
    y = start_y
    style = Style.new
    link = Link.new

    tail_cell = Cell.new
    tail_width = 0
    if truncate && !tail.empty?
      tail_width = UnicodeCharWidth.width(tail)
      tail_cell = Cell.new(tail, tail_width, style, link)
    end

    i = 0
    while i < value.bytesize
      byte = value.byte_at(i)
      if byte == 0x1b
        next_index, style, link = handle_escape(value, i, style, link)
        i = next_index
        next
      end

      if byte == '\n'.ord
        y += 1
        x = bounds.min.x
        i += 1
        next
      end

      if byte == '\r'.ord
        x = bounds.min.x
        i += 1
        next
      end

      segment_start = i
      while i < value.bytesize
        current = value.byte_at(i)
        break if current == 0x1b || current == '\n'.ord || current == '\r'.ord
        i += 1
      end
      segment = value[segment_start, i - segment_start]

      TextSegment.each_grapheme(segment) do |cluster|
        grapheme = cluster.str
        width = UnicodeCharWidth.width(grapheme)

        if !truncate && x + width > bounds.max.x && y + 1 < bounds.max.y
          x = bounds.min.x
          y += 1
        end

        pos = Position.new(x, y)
        if pos.in?(bounds)
          if truncate && tail_width > 0 && x + width > bounds.max.x - tail_width
            cell = tail_cell.clone
            cell.style = style
            cell.link = link
            screen.set_cell(x, y, cell)
            return
          end

          cell = Cell.new(grapheme, width, style, link)
          screen.set_cell(x, y, cell)
          x += width
        end
      end
    end
  end

  # ameba:enable Metrics/CyclomaticComplexity

  private def self.handle_escape(
    value : String,
    index : Int32,
    style : Style,
    link : Link,
  ) : {Int32, Style, Link}
    return {index + 1, style, link} if index + 1 >= value.bytesize

    next_char = value.byte_at(index + 1)
    if next_char == '['.ord
      next_index, new_style = parse_csi(value, index + 2, style)
      return {next_index, new_style, link}
    end
    if next_char == ']'.ord
      next_index, new_link = parse_osc(value, index + 2, link)
      return {next_index, style, new_link}
    end
    {index + 1, style, link}
  end

  private def self.parse_csi(value : String, start_index : Int32, style : Style) : {Int32, Style}
    i = start_index
    while i < value.bytesize
      byte = value.byte_at(i)
      if byte >= 0x40 && byte <= 0x7e
        if byte == 'm'.ord
          params = value[start_index, i - start_index]
          return {i + 1, read_style(params, style)}
        end
        return {i + 1, style}
      end
      i += 1
    end
    {value.bytesize, style}
  end

  private def self.parse_osc(value : String, start_index : Int32, link : Link) : {Int32, Link}
    i = start_index
    while i < value.bytesize
      byte = value.byte_at(i)
      if byte == 0x07
        data = value[start_index, i - start_index]
        return {i + 1, read_link(data, link)}
      end
      if byte == 0x1b && i + 1 < value.bytesize && value.byte_at(i + 1) == '\\'.ord
        data = value[start_index, i - start_index]
        return {i + 2, read_link(data, link)}
      end
      i += 1
    end
    {value.bytesize, link}
  end

  # ameba:disable Metrics/CyclomaticComplexity
  private def self.read_style(params : String, pen : Style) : Style
    style = pen
    if params.empty?
      style.fg = nil
      style.bg = nil
      style.underline_color = nil
      style.underline = Underline::None
      style.attrs = Attr::RESET
      return style
    end

    tokens = params.split(';', remove_empty: false)
    i = 0
    while i < tokens.size
      token = tokens[i]
      token = "0" if token.empty?
      parts = token.split(':')
      code = parts[0].to_i?
      code ||= 0

      case code
      when 0
        style.fg = nil
        style.bg = nil
        style.underline_color = nil
        style.underline = Underline::None
        style.attrs = Attr::RESET
      when 1
        style.attrs |= Attr::BOLD
      when 2
        style.attrs |= Attr::FAINT
      when 3
        style.attrs |= Attr::ITALIC
      when 4
        if parts.size > 1
          style.underline = underline_from_code(parts[1].to_i)
        else
          style.underline = Underline::Single
        end
      when 5
        style.attrs |= Attr::BLINK
      when 6
        style.attrs |= Attr::RAPID_BLINK
      when 7
        style.attrs |= Attr::REVERSE
      when 8
        style.attrs |= Attr::CONCEAL
      when 9
        style.attrs |= Attr::STRIKETHROUGH
      when 22
        style.attrs &= ~(Attr::BOLD | Attr::FAINT)
      when 23
        style.attrs &= ~Attr::ITALIC
      when 24
        style.underline = Underline::None
      when 25
        style.attrs &= ~(Attr::BLINK | Attr::RAPID_BLINK)
      when 27
        style.attrs &= ~Attr::REVERSE
      when 28
        style.attrs &= ~Attr::CONCEAL
      when 29
        style.attrs &= ~Attr::STRIKETHROUGH
      when 30..37
        style.fg = AnsiColor.basic(code - 30)
      when 38
        color, consumed = read_color_parts(parts)
        if color
          style.fg = color
        else
          color, consumed = read_color(tokens, i + 1)
          if color
            style.fg = color
            i += consumed
          end
        end
      when 39
        style.fg = nil
      when 40..47
        style.bg = AnsiColor.basic(code - 40)
      when 48
        color, consumed = read_color_parts(parts)
        if color
          style.bg = color
        else
          color, consumed = read_color(tokens, i + 1)
          if color
            style.bg = color
            i += consumed
          end
        end
      when 49
        style.bg = nil
      when 58
        color, consumed = read_color_parts(parts)
        if color
          style.underline_color = color
        else
          color, consumed = read_color(tokens, i + 1)
          if color
            style.underline_color = color
            i += consumed
          end
        end
      when 59
        style.underline_color = nil
      when 90..97
        style.fg = AnsiColor.bright(code - 90)
      when 100..107
        style.bg = AnsiColor.bright(code - 100)
      end

      i += 1
    end
    style
  end

  # ameba:enable Metrics/CyclomaticComplexity

  private def self.read_color_parts(parts : Array(String)) : {Color?, Int32}
    return {nil, 0} if parts.size < 3
    mode = parts[1].to_i?
    return {nil, 0} unless mode

    if mode == 2
      return {nil, 0} if parts.size < 5
      r = parts[2].to_i
      g = parts[3].to_i
      b = parts[4].to_i
      return {Color.new(r.to_u8, g.to_u8, b.to_u8), 0}
    end

    if mode == 5
      return {nil, 0} if parts.size < 3
      idx = parts[2].to_i
      return {AnsiColor.indexed(idx), 0}
    end

    {nil, 0}
  end

  private def self.read_color(tokens : Array(String), start_index : Int32) : {Color?, Int32}
    return {nil, 0} if start_index >= tokens.size

    mode = tokens[start_index].to_i?
    return {nil, 0} unless mode

    if mode == 2
      return {nil, 0} if start_index + 3 >= tokens.size
      r = tokens[start_index + 1].to_i
      g = tokens[start_index + 2].to_i
      b = tokens[start_index + 3].to_i
      color = Color.new(r.to_u8, g.to_u8, b.to_u8)
      return {color, 4}
    end

    if mode == 5
      return {nil, 0} if start_index + 1 >= tokens.size
      idx = tokens[start_index + 1].to_i
      return {AnsiColor.indexed(idx), 2}
    end

    {nil, 0}
  end

  private def self.underline_from_code(code : Int32) : Underline
    case code
    when 0
      Underline::None
    when 1
      Underline::Single
    when 2
      Underline::Double
    when 3
      Underline::Curly
    when 4
      Underline::Dotted
    when 5
      Underline::Dashed
    else
      Underline::Single
    end
  end

  private def self.read_link(data : String, link : Link) : Link
    parts = data.split(';', remove_empty: false)
    return link unless parts.size == 3

    params = parts[1]
    url = parts[2]
    if url.empty?
      Link.new
    else
      Link.new(url, params)
    end
  end
end
