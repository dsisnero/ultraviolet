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
        # Ansi.each_grapheme_cluster segments exactly as the width functions
        # measure (virama-joined conjuncts are one cluster), so the cells built
        # here agree with what the terminal paints.
        Ansi.each_grapheme_cluster(segment) do |grapheme, _shard_width|
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

    Ansi.each_grapheme_cluster(segment) do |grapheme, _shard_width|
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

  # ReadStyle reads a pen style from SGR parameters.
  #
  # Go parity: this is a direct port of Go ultraviolet's `ReadStyle`
  # (styled.go). It consumes the parser's parameters, not a re-split string, so
  # the `HasMore` flags and missing parameters survive and `ansi.ReadStyleColor`
  # can reject the ambiguous colour forms. That matters for sequences that mix
  # `;` and `:` separators: Go reads "38;2::10:20:30" as black because the colour
  # parse fails, the empty parameter resets the pen, and the trailing `30` is
  # then read as a foreground attribute.
  # ameba:disable Metrics/CyclomaticComplexity
  def self.read_style(params : Ansi::Params, pen : Style) : Style
    return Style.new if params.size == 0

    style = pen
    i = 0
    while i < params.size
      param, has_more, _ = params.param(i, 0)
      case param
      when 0
        style = Style.new
      when 1
        style.attrs |= Attr::BOLD
      when 2
        style.attrs |= Attr::FAINT
      when 3
        style.attrs |= Attr::ITALIC
      when 4
        next_param, _, next_ok = params.param(i + 1, 0)
        if has_more && next_ok
          # Only sub-parameters (separated by ":") carry the underline style.
          if next_param >= 0 && next_param <= 5
            i += 1
            style.underline = underline_from_code(next_param)
          end
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
        style.fg = AnsiColor.basic(param - 30)
      when 38
        n, color = Ansi.read_style_color(params_from(params, i))
        if n > 0
          style.fg = color.nil? ? nil : style_color(color)
          i += n - 1
        end
      when 39
        style.fg = nil
      when 40..47
        style.bg = AnsiColor.basic(param - 40)
      when 48
        n, color = Ansi.read_style_color(params_from(params, i))
        if n > 0
          style.bg = color.nil? ? nil : style_color(color)
          i += n - 1
        end
      when 49
        style.bg = nil
      when 58
        n, color = Ansi.read_style_color(params_from(params, i))
        if n > 0
          style.underline_color = color.nil? ? nil : style_color(color)
          i += n - 1
        end
      when 59
        style.underline_color = nil
      when 90..97
        style.fg = AnsiColor.bright(param - 90)
      when 100..107
        style.bg = AnsiColor.bright(param - 100)
      end
      i += 1
    end
    style
  end

  # ReadStyle from an SGR parameter payload such as "1;31:4". The payload is run
  # through the parser so it is tokenised exactly like the sequence on the wire,
  # then handed to the parameter-based reader above.
  def self.read_style(params : String, pen : Style) : Style
    style = pen
    parser = Ansi::Parser.new
    parser.set_handler(Ansi::Handler.new(
      handle_csi: ->(cmd : Ansi::Cmd, got : Ansi::Params) do
        style = read_style(got, style) if cmd == 'm'.ord
      end
    ))
    parser.parse("\e[#{params}m")
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

  # Parameters from `index` onwards, encoded the way the parser encodes them.
  private def self.params_from(params : Ansi::Params, index : Int32) : Ansi::Params
    Ansi::Params.new(params.to_a[index..])
  end

  private def self.style_color(color : Ansi::PaletteColor) : Color
    case color
    when Ansi::BasicColor
      AnsiColor.basic(color.value.to_i)
    when Ansi::IndexedColor
      AnsiColor.indexed(color.value.to_i)
    when Ansi::RGBColor
      Color.new(color.r, color.g, color.b)
    when Ansi::TrueColor
      r, g, b = Ansi.hex_to_rgb(color.value)
      Color.new(r.to_u8, g.to_u8, b.to_u8)
    when Ansi::Color
      Color.new(color.r, color.g, color.b)
    when Colorful::Color
      Color.new(
        (color.r * 255.0).round.clamp(0, 255).to_u8,
        (color.g * 255.0).round.clamp(0, 255).to_u8,
        (color.b * 255.0).round.clamp(0, 255).to_u8
      )
    else
      Color.new(0_u8, 0_u8, 0_u8)
    end
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
