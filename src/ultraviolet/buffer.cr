require "./geometry"
require "./cell"

module Ultraviolet
  module Screen
    abstract def bounds : Rectangle
    abstract def set_cell(x : Int32, y : Int32, cell : Cell?) : Nil
    abstract def width : Int32
    abstract def height : Int32
  end

  module Drawable
    abstract def draw(screen : Screen, area : Rectangle) : Nil
  end

  class Line
    MAX_CELL_WIDTH = 5

    getter cells : Array(Cell)

    def initialize(width : Int32)
      @cells = Array(Cell).new(width, EMPTY_CELL)
    end

    def width : Int32
      @cells.size
    end

    def set(x : Int32, cell : Cell?) : Nil
      return if x < 0 || x >= @cells.size

      prev = at(x)
      if prev
        prev_width = prev.width
        if prev_width > 1
          j = 0
          while j < prev_width && x + j < @cells.size
            @cells[x + j] = prev.clone
            @cells[x + j].empty!
            j += 1
          end
        elsif prev_width == 0
          j = 1
          while j < MAX_CELL_WIDTH && x - j >= 0
            wide = at(x - j)
            if wide
              wide_width = wide.width
              if wide_width > 1 && j < wide_width
                k = 0
                while k < wide_width && x - j + k < @cells.size
                  @cells[x - j + k] = wide.clone
                  @cells[x - j + k].empty!
                  k += 1
                end
                break
              end
            end
            j += 1
          end
        end
      end

      if cell.nil?
        @cells[x] = EMPTY_CELL
        return
      end

      @cells[x] = cell.clone
      cell_width = cell.width
      if x + cell_width > @cells.size
        i = 0
        while i < cell_width && x + i < @cells.size
          @cells[x + i] = cell.clone
          @cells[x + i].empty!
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

    def at(x : Int32) : Cell?
      return nil if x < 0 || x >= @cells.size
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
          if !pen.zero?
            buf << "\e[0m"
            pen = Style.new
          end
          if !link.empty?
            buf << link.end_sequence
            link = Link.new
          end
          pending << ' '
          pending_count += 1
          next
        end

        if pending_count > 0
          buf << pending.to_s
          pending = String::Builder.new
          pending_count = 0
        end

        if cell.style.zero? && !pen.zero?
          buf << "\e[0m"
          pen = Style.new
        end
        if cell.style != pen
          buf << cell.style.diff(pen)
          pen = cell.style
        end

        if cell.link != link && !link.empty?
          buf << link.end_sequence
          link = Link.new
        end
        if cell.link != link
          buf << cell.link.start_sequence
          link = cell.link
        end

        buf << cell.string
      end

      if !link.empty?
        buf << link.end_sequence
      end
      if !pen.zero?
        buf << "\e[0m"
      end
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
      return nil if y < 0 || y >= @lines.size
      @lines[y]
    end

    def cell_at(x : Int32, y : Int32) : Cell?
      return nil if y < 0 || y >= @lines.size
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
      cell_width = cell.not_nil!.width if cell && cell.width > 1
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
      return nil unless area.in?(bounds)
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
      return if n <= 0 || y < area.min.y || y >= area.max.y || y >= height ||
        x < area.min.x || x >= area.max.x || x >= width

      count = n
      count = area.max.x - x if x + count > area.max.x

      i = area.max.x - 1
      while i >= x + count && i - count >= area.min.x
        @lines[y].cells[i] = @lines[y].cells[i - count]
        i -= 1
      end

      i = x
      while i < x + count && i < area.max.x
        set_cell(i, y, cell)
        i += 1
      end
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
  end
end
