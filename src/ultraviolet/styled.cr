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
      Ultraviolet.print_string(buf, buf.width_method, area.min.x, area.min.y, area, str, !@wrap, @tail)
    end

    # ameba:disable Metrics/CyclomaticComplexity
    def lines(method : WidthMethod = DEFAULT_WIDTH_METHOD) : Array(Line)
      rows = [] of Array(Cell)
      rows << [] of Cell

      x = 0
      y = 0
      style = Style.new
      link = Link.new
      pending = ""
      last_x = -1
      last_y = -1
      str = @text.gsub("\r\n", "\n")

      i = 0
      while i < str.bytesize
        byte = str.byte_at(i)
        if byte == 0x1b
          next_index, style, link, pass = Ultraviolet.handle_escape_with_passthrough(str, i, style, link)
          pending += pass unless pass.empty?
          i = next_index
          next
        end

        if byte == '\n'.ord
          y += 1
          x = 0
          ensure_row(rows, y)
          i += 1
          next
        end

        if byte == '\r'.ord
          x = 0
          i += 1
          next
        end

        segment, i = Ultraviolet.read_print_segment(str, i)
        TextSegment.each_grapheme(segment) do |cluster|
          grapheme = cluster.str
          width = method.call(grapheme)
          width = UnicodeCharWidth.width(grapheme) if width < 0

          if width <= 0
            fold_line_cell(rows, last_x, last_y, grapheme) if last_x >= 0
            next
          end

          content = grapheme
          unless pending.empty?
            content = pending + content
            pending = ""
          end

          place_line_cell(rows[y], x, Cell.new(content, width, style, link))
          last_x = x
          last_y = y
          x += width
        end
      end

      fold_line_cell(rows, last_x, last_y, pending) unless pending.empty? || last_x < 0

      rows.map do |row|
        line = Line.new(row.size)
        idx = 0
        while idx < row.size
          line.cells[idx] = row[idx]
          idx += 1
        end
        line
      end
    end

    # ameba:enable Metrics/CyclomaticComplexity

    private def fold_line_cell(rows : Array(Array(Cell)), x : Int32, y : Int32, text : String) : Nil
      return if x < 0 || y < 0 || y >= rows.size

      row = rows[y]
      return if x >= row.size

      cell = row[x].clone
      cell.content += text
      row[x] = cell
    end

    def height : Int32
      @text.count('\n') + 1
    end

    def unicode_width : Int32
      width_height(DEFAULT_WIDTH_METHOD).first
    end

    def wc_width : Int32
      width_height(DEFAULT_WIDTH_METHOD).first
    end

    def bounds : Rectangle
      width, height = width_height(DEFAULT_WIDTH_METHOD)
      Ultraviolet.rect(0, 0, width, height)
    end

    private def width_height(method : WidthMethod) : {Int32, Int32}
      lines = Ultraviolet.strip_ansi(@text).split('\n', remove_empty: false)
      height = lines.size
      width = 0
      lines.each do |line|
        width = {width, method.call(line)}.max
      end
      {width, height}
    end

    private def ensure_row(rows : Array(Array(Cell)), y : Int32) : Nil
      while rows.size <= y
        rows << [] of Cell
      end
    end

    private def place_line_cell(row : Array(Cell), x : Int32, cell : Cell) : Nil
      while row.size <= x
        row << EMPTY_CELL
      end
      row[x] = cell.clone

      if cell.width > 1
        i = 1
        while i < cell.width
          idx = x + i
          while row.size <= idx
            row << EMPTY_CELL
          end
          row[idx] = Cell.new
          i += 1
        end
      end
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

    if next_char == ']'.ord || next_char == '_'.ord || next_char == 'P'.ord || next_char == 'X'.ord || next_char == '^'.ord
      allow_bel = next_char == ']'.ord
      next_index, _ = string_sequence_end(value, index, allow_bel)
      return next_index
    end

    index + 1
  end

  def self.print_string(
    screen : Screen,
    method : WidthMethod,
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
    pending = ""
    last_x = -1
    last_y = -1

    tail_cell, tail_width = build_tail_cell(method, truncate, tail, style, link)

    i = 0
    while i < value.bytesize
      byte = value.byte_at(i)
      if byte == 0x1b
        next_index, style, link, pass = handle_escape_with_passthrough(value, i, style, link)
        pending += pass unless pass.empty?
        i = next_index
        next
      end

      if byte == '\n'.ord
        x = bounds.min.x
        y += 1
        i += 1
        break if y >= bounds.max.y
        next
      end

      if byte == '\r'.ord
        x = bounds.min.x
        i += 1
        next
      end

      segment, i = read_print_segment(value, i)
      x, y, done, pending, last_x, last_y = render_segment(
        screen, method, bounds, segment, x, y, style, link, truncate, tail_cell, tail_width, pending, last_x, last_y
      )
      break if done
    end

    fold_screen_cell(screen, last_x, last_y, pending) unless pending.empty? || last_x < 0
  end

  private def self.build_tail_cell(method : WidthMethod, truncate : Bool, tail : String, style : Style, link : Link) : {Cell, Int32}
    if truncate && !tail.empty?
      width = method.call(tail)
      return {Cell.new(tail, width, style, link), width}
    end

    {Cell.new, 0}
  end

  def self.read_print_segment(value : String, index : Int32) : {String, Int32}
    segment_start = index
    i = index
    while i < value.bytesize
      current = value.byte_at(i)
      break if current == 0x1b || current == '\n'.ord || current == '\r'.ord
      i += 1
    end
    segment_len = i - segment_start
    segment = value.byte_slice(segment_start, segment_len) || ""
    {segment, i}
  end

  private def self.render_segment(
    screen : Screen,
    method : WidthMethod,
    bounds : Rectangle,
    segment : String,
    x : Int32,
    y : Int32,
    style : Style,
    link : Link,
    truncate : Bool,
    tail_cell : Cell,
    tail_width : Int32,
    pending : String,
    last_x : Int32,
    last_y : Int32,
  ) : {Int32, Int32, Bool, String, Int32, Int32}
    done = false

    TextSegment.each_grapheme(segment) do |cluster|
      grapheme = cluster.str
      width = method.call(grapheme)

      if width <= 0
        fold_screen_cell(screen, last_x, last_y, grapheme) if last_x >= 0
        next
      end

      content = grapheme
      unless pending.empty?
        content = pending + content
        pending = ""
      end

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
          last_x = x
          last_y = y
          done = true
          break
        end

        cell = Cell.new(content, width, style, link)
        screen.set_cell(x, y, cell)
        last_x = x
        last_y = y
        x += width
      end
    end

    {x, y, done, pending, last_x, last_y}
  end

  private def self.fold_screen_cell(screen : Screen, x : Int32, y : Int32, text : String) : Nil
    return if x < 0 || y < 0

    cell = screen.cell_at(x, y)
    return unless cell

    folded = cell.clone
    folded.content += text
    screen.set_cell(x, y, folded)
  end

  def self.handle_escape(
    value : String,
    index : Int32,
    style : Style,
    link : Link,
  ) : {Int32, Style, Link}
    next_index, new_style, new_link, _ = handle_escape_with_passthrough(value, index, style, link)
    {next_index, new_style, new_link}
  end

  def self.handle_escape_with_passthrough(
    value : String,
    index : Int32,
    style : Style,
    link : Link,
  ) : {Int32, Style, Link, String}
    return {index + 1, style, link, ""} if index + 1 >= value.bytesize

    next_char = value.byte_at(index + 1)
    if next_char == '['.ord
      next_index, new_style = parse_csi(value, index + 2, style)
      return {next_index, new_style, link, ""}
    end
    if next_char == ']'.ord
      next_index, new_link = parse_osc(value, index + 2, link)
      return {next_index, style, new_link, ""}
    end
    if next_char == '_'.ord || next_char == 'P'.ord || next_char == 'X'.ord || next_char == '^'.ord
      next_index, terminated = string_sequence_end(value, index, false)
      if terminated
        sequence = value.byte_slice(index, next_index - index) || ""
        return {next_index, style, link, sequence}
      end
      return {next_index, style, link, ""}
    end
    {index + 1, style, link, ""}
  end

  # Returns the index just past a string-type sequence and whether it ended with
  # the two-byte ST. The one-byte C1 ST is deliberately not accepted: 0x9c is
  # also a UTF-8 continuation byte, so an unterminated sequence that ran out
  # mid-character can end in the same byte.
  private def self.string_sequence_end(value : String, index : Int32, allow_bel : Bool) : {Int32, Bool}
    i = index + 2
    while i < value.bytesize
      byte = value.byte_at(i)
      return {i + 1, true} if allow_bel && byte == 0x07
      if byte == 0x1b && i + 1 < value.bytesize && value.byte_at(i + 1) == '\\'.ord
        return {i + 2, true}
      end
      i += 1
    end
    {value.bytesize, false}
  end

  private def self.parse_csi(value : String, start_index : Int32, style : Style) : {Int32, Style}
    i = start_index
    while i < value.bytesize
      byte = value.byte_at(i)
      if byte >= 0x40 && byte <= 0x7e
        if byte == 'm'.ord
          # start_index/i are byte offsets from decoder scan; use byte_slice
          # so multibyte graphemes before CSI don't corrupt parameter parsing.
          params = value.byte_slice(start_index, i - start_index)
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
        data = value.byte_slice(start_index, i - start_index)
        return {i + 1, read_link_string(data, link)}
      end
      if byte == 0x1b && i + 1 < value.bytesize && value.byte_at(i + 1) == '\\'.ord
        data = value.byte_slice(start_index, i - start_index)
        return {i + 2, read_link_string(data, link)}
      end
      i += 1
    end
    {value.bytesize, link}
  end

  def self.read_style(params : String, pen : Style) : Style
    style = pen
    if params.empty?
      style = reset_style(style)
      return style
    end

    tokens = params.split(';', remove_empty: false)
    i = 0
    while i < tokens.size
      code, parts = parse_style_token(tokens[i])
      style, consumed = apply_style_code(style, code, parts, tokens, i)
      i += consumed + 1
    end
    style
  end

  # Go parity alias: params already split from a CSI sequence payload.
  def self.read_style_from_params(params : String, pen : Style) : Style
    read_style(params, pen)
  end

  # Convenience overload for parser outputs that surface bytes.
  def self.read_style_from_params(params : Bytes, pen : Style) : Style
    read_style(String.new(params), pen)
  end

  private STYLE_SET_ATTR = {
    1 => Attr::BOLD,
    2 => Attr::FAINT,
    3 => Attr::ITALIC,
    5 => Attr::BLINK,
    6 => Attr::RAPID_BLINK,
    7 => Attr::REVERSE,
    8 => Attr::CONCEAL,
    9 => Attr::STRIKETHROUGH,
  }

  private STYLE_CLEAR_ATTR = {
    22 => (Attr::BOLD | Attr::FAINT),
    23 => Attr::ITALIC,
    25 => (Attr::BLINK | Attr::RAPID_BLINK),
    27 => Attr::REVERSE,
    28 => Attr::CONCEAL,
    29 => Attr::STRIKETHROUGH,
  }

  private def self.reset_style(style : Style) : Style
    style.fg = nil
    style.bg = nil
    style.underline_color = nil
    style.underline = Underline::None
    style.attrs = Attr::RESET
    style
  end

  private def self.parse_style_token(token : String) : {Int32, Array(String)}
    value = token.empty? ? "0" : token
    parts = value.split(':')
    code = parse_int_token(parts[0])
    {code || 0, parts}
  end

  private def self.parse_int_token(token : String) : Int32?
    return nil if token.empty?
    i = 0
    while i < token.bytesize && token.byte_at(i).unsafe_chr.ascii_number?
      i += 1
    end
    return nil if i == 0
    token[0, i].to_i?
  end

  private def self.apply_style_code(style : Style, code : Int32, parts : Array(String), tokens : Array(String), index : Int32) : {Style, Int32}
    return {apply_style_reset(style, code), 0} if code == 0

    style, handled = apply_style_attr(style, code)
    return {style, 0} if handled

    style, handled = apply_style_misc(style, code, parts)
    return {style, 0} if handled

    apply_style_color(style, code, parts, tokens, index)
  end

  private def self.apply_style_reset(style : Style, _code : Int32) : Style
    reset_style(style)
  end

  private def self.apply_style_attr(style : Style, code : Int32) : {Style, Bool}
    if attr = STYLE_SET_ATTR[code]?
      style.attrs |= attr
      return {style, true}
    end
    if attr = STYLE_CLEAR_ATTR[code]?
      style.attrs &= ~attr
      return {style, true}
    end
    {style, false}
  end

  private def self.apply_style_misc(style : Style, code : Int32, parts : Array(String)) : {Style, Bool}
    case code
    when 4
      underline_code = parts.size > 1 ? (parse_int_token(parts[1]) || 1) : 1
      style.underline = underline_from_code(underline_code)
      {style, true}
    when 24
      style.underline = Underline::None
      {style, true}
    else
      {style, false}
    end
  end

  private def self.apply_style_color(style : Style, code : Int32, parts : Array(String), tokens : Array(String), index : Int32) : {Style, Int32}
    style, handled = apply_style_basic_color(style, code)
    return {style, 0} if handled

    style, consumed = apply_style_extended_color_code(style, code, parts, tokens, index)
    return {style, consumed} if consumed

    style, handled = apply_style_bright_color(style, code)
    return {style, 0} if handled

    {style, 0}
  end

  private def self.apply_style_basic_color(style : Style, code : Int32) : {Style, Bool}
    if code >= 30 && code <= 37
      style.fg = AnsiColor.basic(code - 30)
      return {style, true}
    end
    if code == 39
      style.fg = nil
      return {style, true}
    end
    if code >= 40 && code <= 47
      style.bg = AnsiColor.basic(code - 40)
      return {style, true}
    end
    if code == 49
      style.bg = nil
      return {style, true}
    end
    {style, false}
  end

  private def self.apply_style_extended_color_code(style : Style, code : Int32, parts : Array(String), tokens : Array(String), index : Int32) : {Style, Int32?}
    if code == 38
      style, consumed = apply_extended_color(style, parts, tokens, index, :fg)
      return {style, consumed}
    end
    if code == 48
      style, consumed = apply_extended_color(style, parts, tokens, index, :bg)
      return {style, consumed}
    end
    if code == 58
      style, consumed = apply_extended_color(style, parts, tokens, index, :underline)
      return {style, consumed}
    end
    if code == 59
      style.underline_color = nil
      return {style, 0}
    end
    {style, nil}
  end

  private def self.apply_style_bright_color(style : Style, code : Int32) : {Style, Bool}
    if code >= 90 && code <= 97
      style.fg = AnsiColor.bright(code - 90)
      return {style, true}
    end
    if code >= 100 && code <= 107
      style.bg = AnsiColor.bright(code - 100)
      return {style, true}
    end
    {style, false}
  end

  private def self.apply_extended_color(style : Style, parts : Array(String), tokens : Array(String), index : Int32, target : Symbol) : {Style, Int32}
    color, _ = read_color_parts(parts)
    if color
      style = assign_color(style, color, target)
      return {style, 0}
    end

    color, consumed = read_color(tokens, index + 1)
    if color
      style = assign_color(style, color, target)
      return {style, consumed}
    end

    {style, 0}
  end

  private def self.assign_color(style : Style, color : Color, target : Symbol) : Style
    case target
    when :fg
      style.fg = color
    when :bg
      style.bg = color
    when :underline
      style.underline_color = color
    end
    style
  end

  private def self.read_color_parts(parts : Array(String)) : {Color?, Int32}
    return {nil, 0} if parts.size < 3
    mode = parse_int_token(parts[1])
    return {nil, 0} unless mode

    if mode == 2
      return {nil, 0} if parts.size < 5
      r = parse_int_token(parts[2])
      g = parse_int_token(parts[3])
      b = parse_int_token(parts[4])
      return {nil, 0} unless r && g && b
      return {Color.new(r.to_u8, g.to_u8, b.to_u8), 0}
    end

    if mode == 5
      return {nil, 0} if parts.size < 3
      idx = parse_int_token(parts[2])
      return {nil, 0} unless idx
      return {AnsiColor.indexed(idx), 0}
    end

    {nil, 0}
  end

  private def self.read_color(tokens : Array(String), start_index : Int32) : {Color?, Int32}
    return {nil, 0} if start_index >= tokens.size

    mode = parse_int_token(tokens[start_index])
    return {nil, 0} unless mode

    if mode == 2
      return {nil, 0} if start_index + 3 >= tokens.size
      r = parse_int_token(tokens[start_index + 1])
      g = parse_int_token(tokens[start_index + 2])
      b = parse_int_token(tokens[start_index + 3])
      return {nil, 0} unless r && g && b
      color = Color.new(r.to_u8, g.to_u8, b.to_u8)
      return {color, 4}
    end

    if mode == 5
      return {nil, 0} if start_index + 1 >= tokens.size
      idx = parse_int_token(tokens[start_index + 1])
      return {nil, 0} unless idx
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

  private def self.read_link_string(data : String, link : Link) : Link
    # OSC 8 is `8;params;URI`. Only the first two semicolons delimit; any
    # semicolon after them belongs to the URI.
    parts = data.split(';', 3, remove_empty: false)
    return link unless parts.size == 3

    params = parts[1]
    url = parts[2]
    Link.new(url, params)
  end

  def self.read_link(data : Bytes, link : Link) : Link
    # Convert bytes to string (ASCII safe)
    str = String.new(data)
    read_link_string(str, link)
  end

  # Go parity alias: raw OSC payload bytes (`8;params;url`).
  def self.read_link_from_data(data : Bytes, link : Link) : Link
    read_link(data, link)
  end

  # Go-compatible constructor alias for [StyledString.new].
  def self.new_styled_string(text : String = "", wrap : Bool = false, tail : String = "") : StyledString
    StyledString.new(text, wrap, tail)
  end
end
