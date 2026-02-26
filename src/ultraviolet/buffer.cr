require "./geometry"
require "./cell"

module Ultraviolet
  module Screen
    abstract def bounds : Rectangle
    abstract def cell_at(x : Int32, y : Int32) : Cell?
    abstract def set_cell(x : Int32, y : Int32, cell : Cell?) : Nil
    abstract def width : Int32
    abstract def height : Int32
    abstract def width_method : WidthMethod
  end

  module Drawable
    abstract def draw(screen : Screen, area : Rectangle) : Nil
  end

  struct DrawableFunc
    include Drawable

    def initialize(&@proc : Screen, Rectangle -> Nil)
    end

    def draw(screen : Screen, area : Rectangle) : Nil
      @proc.call(screen, area)
    end
  end

  class Line
    getter cells : Array(Cell)

    def initialize(width : Int32)
      @cells = Array(Cell).new(width, EMPTY_CELL)
    end

    def width : Int32
      @cells.size
    end

    def set(x : Int32, cell : Cell?) : Nil
      return if x < 0 || x >= @cells.size

      clear_prev_cells(x)

      if cell.nil?
        @cells[x] = EMPTY_CELL
        return
      end

      place_cell(x, cell)
    end

    def at(x : Int32) : Cell?
      return if x < 0 || x >= @cells.size
      @cells[x]
    end

    def string : String
      buf = String::Builder.new
      pending = String::Builder.new
      pending_count = 0

      @cells.each do |cell|
        next if cell.zero?
        if cell == EMPTY_CELL
          pending << ' '
          pending_count += 1
          next
        end
        if pending_count > 0
          buf << pending.to_s
          pending = String::Builder.new
          pending_count = 0
        end
        buf << cell.string
      end

      buf.to_s
    end

    def render : String
      buf = String::Builder.new
      render_line(buf)
      buf.to_s
    end

    def render_line(buf : String::Builder) : Nil
      pen = Style.new
      link = Link.new
      pending = String::Builder.new
      pending_count = 0

      @cells.each do |cell|
        next if cell.zero?
        if cell == EMPTY_CELL
          pen, link, pending_count = append_empty_cell(buf, pen, link, pending, pending_count)
          next
        end

        pending, pending_count = flush_pending(buf, pending, pending_count)
        pen = apply_style(buf, cell, pen)
        link = apply_link(buf, cell, link)
        buf << cell.string
      end

      if !link.empty?
        buf << link.end_sequence
      end
      if !pen.zero?
        buf << "\e[0m"
      end
    end

    private def clear_prev_cells(x : Int32) : Nil
      prev = at(x)
      return unless prev

      prev_width = prev.width
      if prev_width > 1
        clear_wide_right(x, prev_width)
      elsif prev_width == 0
        clear_wide_left(x)
      end
    end

    private def clear_wide_right(x : Int32, width : Int32) : Nil
      j = 0
      while j < width && x + j < @cells.size
        idx = x + j
        cell = @cells[idx].clone
        cell.empty!
        @cells[idx] = cell
        j += 1
      end
    end

    private def clear_wide_left(x : Int32) : Nil
      j = 1
      while x - j >= 0
        wide = at(x - j)
        if wide && wide.width > 1 && j < wide.width
          clear_wide_span(x - j, wide.width)
          break
        end
        j += 1
      end
    end

    private def clear_wide_span(start : Int32, width : Int32) : Nil
      k = 0
      while k < width && start + k < @cells.size
        idx = start + k
        cell = @cells[idx].clone
        cell.empty!
        @cells[idx] = cell
        k += 1
      end
    end

    private def place_cell(x : Int32, cell : Cell) : Nil
      @cells[x] = cell.clone
      cell_width = cell.width
      if x + cell_width > @cells.size
        i = 0
        while i < cell_width && x + i < @cells.size
          idx = x + i
          blank = cell.clone
          blank.empty!
          @cells[idx] = blank
          i += 1
        end
        return
      end

      if cell_width > 1
        j = 1
        while j < cell_width && x + j < @cells.size
          @cells[x + j] = Cell.new
          j += 1
        end
      end
    end

    private def append_empty_cell(
      buf : String::Builder,
      pen : Style,
      link : Link,
      pending : String::Builder,
      pending_count : Int32,
    ) : {Style, Link, Int32}
      unless pen.zero?
        buf << "\e[0m"
        pen = Style.new
      end
      unless link.empty?
        buf << link.end_sequence
        link = Link.new
      end
      pending << ' '
      pending_count += 1
      {pen, link, pending_count}
    end

    private def flush_pending(
      buf : String::Builder,
      pending : String::Builder,
      pending_count : Int32,
    ) : {String::Builder, Int32}
      return {pending, pending_count} if pending_count == 0

      buf << pending.to_s
      {String::Builder.new, 0}
    end

    private def apply_style(buf : String::Builder, cell : Cell, pen : Style) : Style
      if cell.style.zero? && !pen.zero?
        buf << "\e[0m"
        return Style.new
      end
      if cell.style != pen
        buf << cell.style.diff(pen)
        return cell.style
      end
      pen
    end

    private def apply_link(buf : String::Builder, cell : Cell, link : Link) : Link
      if cell.link != link && !link.empty?
        buf << link.end_sequence
        link = Link.new
      end
      if cell.link != link
        buf << cell.link.start_sequence
        return cell.link
      end
      link
    end
  end

  class Lines
    getter lines : Array(Line)

    def initialize(@lines : Array(Line))
    end

    def height : Int32
      @lines.size
    end

    def width : Int32
      max_width = 0
      @lines.each do |line|
        max_width = {max_width, line.width}.max
      end
      max_width
    end

    def string : String
      buf = String::Builder.new
      @lines.each_with_index do |line, i|
        buf << line.string
        buf << '\n' if i < @lines.size - 1
      end
      buf.to_s
    end

    def render : String
      buf = String::Builder.new
      @lines.each_with_index do |line, i|
        line.render_line(buf)
        buf << '\n' if i < @lines.size - 1
      end
      buf.to_s
    end
  end

  class Buffer
    include Drawable

    getter lines : Array(Line)

    def initialize(width : Int32, height : Int32)
      @lines = Array(Line).new(height) { Line.new(width) }
      resize(width, height)
    end

    def self.new_buffer(width : Int32, height : Int32) : Buffer
      Buffer.new(width, height)
    end

    def string : String
      Lines.new(@lines).string
    end

    def render : String
      Lines.new(@lines).render
    end

    def line(y : Int32) : Line?
      return if y < 0 || y >= @lines.size
      @lines[y]
    end

    def line_at(y : Int32) : Line
      @lines[y]
    end

    def cell_at(x : Int32, y : Int32) : Cell?
      return if y < 0 || y >= @lines.size
      @lines[y].at(x)
    end

    def set_cell(x : Int32, y : Int32, cell : Cell?) : Nil
      return if y < 0 || y >= @lines.size
      @lines[y].set(x, cell)
    end

    def height : Int32
      @lines.size
    end

    def width : Int32
      return 0 if @lines.empty?
      @lines[0].width
    end

    def bounds : Rectangle
      Ultraviolet.rect(0, 0, width, height)
    end

    def resize(width : Int32, height : Int32) : Nil
      current_width = self.width
      current_height = self.height
      return if current_width == width && current_height == height

      if width > current_width
        @lines.each do |line|
          (width - current_width).times { line.cells << EMPTY_CELL }
        end
      elsif width < current_width
        @lines.each do |line|
          while line.cells.size > width
            line.cells.pop
          end
        end
      end

      if height > @lines.size
        (height - @lines.size).times { @lines << Line.new(width) }
      elsif height < @lines.size
        while @lines.size > height
          @lines.pop
        end
      end
    end

    def fill(cell : Cell?) : Nil
      fill_area(cell, bounds)
    end

    def fill_area(cell : Cell?, area : Rectangle) : Nil
      cell_width = 1
      cell_width = cell.width if cell && cell.width > 1
      y = area.min.y
      while y < area.max.y
        x = area.min.x
        while x < area.max.x
          set_cell(x, y, cell)
          x += cell_width
        end
        y += 1
      end
    end

    def clear : Nil
      clear_area(bounds)
    end

    def clear_area(area : Rectangle) : Nil
      fill_area(nil, area)
    end

    def clone_area(area : Rectangle) : Buffer?
      return unless area.in?(bounds)
      result = Buffer.new(area.dx, area.dy)
      y = area.min.y
      while y < area.max.y
        x = area.min.x
        while x < area.max.x
          cell = cell_at(x, y)
          result.set_cell(x - area.min.x, y - area.min.y, cell) if cell && !cell.zero?
          x += 1
        end
        y += 1
      end
      result
    end

    def clone : Buffer
      clone_area(bounds) || Buffer.new(0, 0)
    end

    def draw(screen : Screen, area : Rectangle) : Nil
      return if area.empty?
      return unless area.overlaps?(screen.bounds)

      y = area.min.y
      while y < area.max.y
        x = area.min.x
        while x < area.max.x
          cell = cell_at(x - area.min.x, y - area.min.y)
          if cell.nil? || cell.zero?
            x += 1
            next
          end
          screen.set_cell(x, y, cell)
          width = cell.width
          width = 1 if width <= 0
          x += width
        end
        y += 1
      end
    end

    def insert_line(y : Int32, n : Int32, cell : Cell?) : Nil
      insert_line_area(y, n, cell, bounds)
    end

    def insert_line_area(y : Int32, n : Int32, cell : Cell?, area : Rectangle) : Nil
      return if n <= 0 || y < area.min.y || y >= area.max.y || y >= height

      count = n
      count = area.max.y - y if y + count > area.max.y

      i = area.max.y - 1
      while i >= y + count
        x = area.min.x
        while x < area.max.x
          @lines[i].cells[x] = @lines[i - count].cells[x]
          x += 1
        end
        i -= 1
      end

      i = y
      while i < y + count
        x = area.min.x
        while x < area.max.x
          set_cell(x, i, cell)
          x += 1
        end
        i += 1
      end
    end

    def delete_line_area(y : Int32, n : Int32, cell : Cell?, area : Rectangle) : Nil
      return if n <= 0 || y < area.min.y || y >= area.max.y || y >= height

      count = n
      count = area.max.y - y if count > area.max.y - y

      dst = y
      while dst < area.max.y - count
        src = dst + count
        x = area.min.x
        while x < area.max.x
          @lines[dst].cells[x] = @lines[src].cells[x]
          x += 1
        end
        dst += 1
      end

      i = area.max.y - count
      while i < area.max.y
        x = area.min.x
        while x < area.max.x
          set_cell(x, i, cell)
          x += 1
        end
        i += 1
      end
    end

    def delete_line(y : Int32, n : Int32, cell : Cell?) : Nil
      delete_line_area(y, n, cell, bounds)
    end

    def insert_cell(x : Int32, y : Int32, n : Int32, cell : Cell?) : Nil
      insert_cell_area(x, y, n, cell, bounds)
    end

    def insert_cell_area(x : Int32, y : Int32, n : Int32, cell : Cell?, area : Rectangle) : Nil
      return unless valid_insert_cell_area?(x, y, n, area)

      count = n
      count = area.max.x - x if x + count > area.max.x

      shift_cells_right(y, x, count, area)
      fill_inserted_cells(y, x, count, cell, area)
    end

    def delete_cell(x : Int32, y : Int32, n : Int32, cell : Cell?) : Nil
      delete_cell_area(x, y, n, cell, bounds)
    end

    def delete_cell_area(x : Int32, y : Int32, n : Int32, cell : Cell?, area : Rectangle) : Nil
      return if n <= 0 || y < area.min.y || y >= area.max.y || y >= height ||
                x < area.min.x || x >= area.max.x || x >= width

      count = n
      remaining = area.max.x - x
      count = remaining if count > remaining

      i = x
      while i < area.max.x - count
        if i + count < area.max.x
          set_cell(i, y, cell_at(i + count, y))
        end
        i += 1
      end

      i = area.max.x - count
      while i < area.max.x
        set_cell(i, y, cell)
        i += 1
      end
    end

    private def valid_insert_cell_area?(x : Int32, y : Int32, n : Int32, area : Rectangle) : Bool
      return false if n <= 0
      return false if y < area.min.y
      return false if y >= area.max.y
      return false if y >= height
      return false if x < area.min.x
      return false if x >= area.max.x
      return false if x >= width
      true
    end

    private def shift_cells_right(y : Int32, x : Int32, count : Int32, area : Rectangle) : Nil
      i = area.max.x - 1
      while i >= x + count && i - count >= area.min.x
        @lines[y].cells[i] = @lines[y].cells[i - count]
        i -= 1
      end
    end

    private def fill_inserted_cells(
      y : Int32,
      x : Int32,
      count : Int32,
      cell : Cell?,
      area : Rectangle,
    ) : Nil
      i = x
      while i < x + count && i < area.max.x
        set_cell(i, y, cell)
        i += 1
      end
    end
  end

  struct LineData
    property first_cell : Int32
    property last_cell : Int32
    property old_index : Int32

    def initialize(@first_cell : Int32 = -1, @last_cell : Int32 = -1, @old_index : Int32 = 0)
    end
  end

  class RenderBuffer < Buffer
    property touched : Array(LineData?)

    def initialize(width : Int32, height : Int32)
      super(width, height)
      @touched = Array(LineData?).new(height, nil)
    end

    def touch_line(x : Int32, y : Int32, n : Int32) : Nil
      return if y < 0 || y >= @lines.size

      if y >= @touched.size
        @touched += Array(LineData?).new(y - @touched.size + 1, nil)
      end
      return if y >= @touched.size

      current = @touched[y]
      if current.nil?
        @touched[y] = LineData.new(x, x + n)
      else
        current.first_cell = {current.first_cell, x}.min
        current.last_cell = {current.last_cell, x + n}.max
        @touched[y] = current
      end
    end

    def touch(x : Int32, y : Int32) : Nil
      touch_line(x, y, 0)
    end

    def touched_lines : Int32
      count = 0
      @touched.each do |line|
        count += 1 unless line.nil?
      end
      count
    end

    def set_cell(x : Int32, y : Int32, cell : Cell?) : Nil
      unless Ultraviolet.cell_equal?(cell_at(x, y), cell)
        width = 1
        width = cell.width if cell && cell.width > 0
        touch_line(x, y, width)
      end
      super
    end

    def insert_line(y : Int32, n : Int32, cell : Cell?) : Nil
      insert_line_area(y, n, cell, bounds)
    end

    def insert_line_area(y : Int32, n : Int32, cell : Cell?, area : Rectangle) : Nil
      super
      i = area.min.y
      while i < area.max.y
        touch_line(area.min.x, i, area.max.x - area.min.x)
        touch_line(area.min.x, i - n, area.max.x - area.min.x)
        i += 1
      end
    end

    def delete_line(y : Int32, n : Int32, cell : Cell?) : Nil
      delete_line_area(y, n, cell, bounds)
    end

    def delete_line_area(y : Int32, n : Int32, cell : Cell?, area : Rectangle) : Nil
      super
      i = area.min.y
      while i < area.max.y
        touch_line(area.min.x, i, area.max.x - area.min.x)
        touch_line(area.min.x, i + n, area.max.x - area.min.x)
        i += 1
      end
    end

    def insert_cell(x : Int32, y : Int32, n : Int32, cell : Cell?) : Nil
      insert_cell_area(x, y, n, cell, bounds)
    end

    def insert_cell_area(x : Int32, y : Int32, n : Int32, cell : Cell?, area : Rectangle) : Nil
      super
      count = n
      count = area.max.x - x if x + count > area.max.x
      touch_line(x, y, count)
    end

    def delete_cell(x : Int32, y : Int32, n : Int32, cell : Cell?) : Nil
      delete_cell_area(x, y, n, cell, bounds)
    end

    def delete_cell_area(x : Int32, y : Int32, n : Int32, cell : Cell?, area : Rectangle) : Nil
      super
      remaining = area.max.x - x
      count = n
      count = remaining if count > remaining
      touch_line(x, y, count)
    end
  end

  class ScreenBuffer < RenderBuffer
    include Screen

    property method : WidthMethod

    def initialize(width : Int32, height : Int32, @method : WidthMethod = DEFAULT_WIDTH_METHOD)
      super(width, height)
    end

    def width_method : WidthMethod
      @method
    end
  end

  def self.new_render_buffer(width : Int32, height : Int32) : RenderBuffer
    RenderBuffer.new(width, height)
  end

  def self.new_screen_buffer(width : Int32, height : Int32) : ScreenBuffer
    ScreenBuffer.new(width, height)
  end

  def self.trim_space(value : String) : String
    lines = value.split('\n', remove_empty: false)
    lines.map! do |line|
      has_cr = line.ends_with?("\r")
      line = line[0...-1] if has_cr
      while line.ends_with?(' ')
        line = line[0...-1]
      end
      line += "\r" if has_cr
      line
    end
    lines.join("\n")
  end

  # TODO: This is needed to handle empty lines correctly when scroll
  # optimizations are enabled. Instead, a nil check should be equivalent to
  # checking for an [EmptyCell], should it?
  # Investigate why when we assign the pointers to &[EmptyCell], this causes
  # scroll optimization related artifacts where excess lines are left behind
  # in empty lines after scrolling.
  def self.cell_equal?(a : Cell?, b : Cell?) : Bool
    return true if a == b
    return false if a.nil? || b.nil?
    a == b
  end
end
