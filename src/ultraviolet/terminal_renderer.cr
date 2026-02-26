require "uniwidth"
require "ansi"
require "./buffer"
require "./colorprofile"
require "./tabstop"
require "./terminal_renderer_hashmap"
require "./terminal_renderer_hardscroll"
require "./logger"

module Ultraviolet
  ErrInvalidDimensions = Exception.new("invalid dimensions")

  @[Flags]
  enum Capabilities
    None = 0
    VPA
    HPA
    CHA
    CHT
    CBT
    REP
    ECH
    ICH
    SD
    SU
    HT
    BS

    # Resets (clears) the given capabilities from this value.
    # Returns a new Capabilities value with the bits cleared.
    def reset(cap : Capabilities) : Capabilities
      self & ~cap
    end

    # Returns whether this capabilities value contains all the given capabilities.
    def contains(cap : Capabilities) : Bool
      (self & cap) == cap
    end
  end

  @[Flags]
  enum TerminalFlags
    None           = 0
    RelativeCursor
    Fullscreen
    MapNewline
    ScrollOptim

    # Resets (clears) the given flags from this value.
    # Returns a new TerminalFlags value with the bits cleared.
    def reset(flag : TerminalFlags) : TerminalFlags
      self & ~flag
    end

    # Returns whether this flags value contains all the given flags.
    def contains(flag : TerminalFlags) : Bool
      (self & flag) == flag
    end
  end

  struct CursorState
    property cell : Cell
    property position : Position

    def initialize(@cell : Cell = EMPTY_CELL, @position : Position = Position.new(-1, -1))
    end

    def x : Int32
      @position.x
    end

    def y : Int32
      @position.y
    end

    def x=(value : Int32) : Nil
      @position = Position.new(value, @position.y)
    end

    def y=(value : Int32) : Nil
      @position = Position.new(@position.x, value)
    end
  end

  class TerminalRenderer
    @writer : IO
    @buf : IO::Memory
    @curbuf : RenderBuffer?
    @tabs : TabStops?
    @flags : TerminalFlags
    @term : String
    @scroll_height : Int32
    @clear : Bool
    @caps : Capabilities
    @at_phantom : Bool
    @logger : Logger?
    @profile : ColorProfile
    @cur : CursorState
    @saved : CursorState
    @oldhash : Array(UInt64)
    @newhash : Array(UInt64)
    @hashtab : Array(HashMapEntry)
    @oldnum : Array(Int32)

    getter caps : Capabilities
    getter flags : TerminalFlags
    getter cur : CursorState

    def initialize(@writer : IO, env : Array(String) = [] of String)
      @profile = ColorProfile.detect(@writer, env)
      @buf = IO::Memory.new
      @term = Environ.new(env).getenv("TERM")
      @caps = xterm_caps(@term)
      @flags = TerminalFlags::None
      @cur = CursorState.new
      @saved = @cur
      @scroll_height = 0
      @clear = false
      @at_phantom = false
      @oldhash = [] of UInt64
      @newhash = [] of UInt64
      @hashtab = [] of HashMapEntry
      @oldnum = [] of Int32
    end

    def logger=(logger : Logger?) : Nil
      @logger = logger
    end

    def color_profile=(profile : ColorProfile) : Nil
      @profile = profile
    end

    def scroll_optim=(enabled : Bool) : Nil
      if enabled
        @flags |= TerminalFlags::ScrollOptim
      else
        @flags &= ~TerminalFlags::ScrollOptim
      end
    end

    def map_newline=(enabled : Bool) : Nil
      if enabled
        @flags |= TerminalFlags::MapNewline
      else
        @flags &= ~TerminalFlags::MapNewline
      end
    end

    def backspace=(enabled : Bool) : Nil
      if enabled
        @caps |= Capabilities::BS
      else
        @caps &= ~Capabilities::BS
      end
    end

    def tab_stops=(width : Int32) : Nil
      if width < 0 || @term.starts_with?("linux")
        @caps &= ~Capabilities::HT
      else
        @caps |= Capabilities::HT
        @tabs = TabStops.default(width)
      end
    end

    def fullscreen=(enabled : Bool) : Nil
      if enabled
        @flags |= TerminalFlags::Fullscreen
      else
        @flags &= ~TerminalFlags::Fullscreen
      end
    end

    def fullscreen? : Bool
      (@flags & TerminalFlags::Fullscreen) == TerminalFlags::Fullscreen
    end

    def relative_cursor=(enabled : Bool) : Nil
      if enabled
        @flags |= TerminalFlags::RelativeCursor
      else
        @flags &= ~TerminalFlags::RelativeCursor
      end
    end

    def save_cursor : Nil
      @saved = @cur
    end

    def restore_cursor : Nil
      @cur = @saved
    end

    def enter_alt_screen : Nil
      save_cursor
      @buf << Ansi::SetModeAltScreenSaveCursor
      self.fullscreen = true
      self.relative_cursor = false
      erase
    end

    def exit_alt_screen : Nil
      erase
      self.relative_cursor = true
      self.fullscreen = false
      @buf << Ansi::ResetModeAltScreenSaveCursor
      restore_cursor
    end

    def prepend_string(newbuf : RenderBuffer, value : String) : Nil
      return if value.empty?

      # TODO: Use scrolling region if available.
      # TODO: Use [Screen.Write] [io.Writer] interface.

      width = newbuf.width
      height = newbuf.height
      move(newbuf, 0, height - 1)

      lines = value.split("\n")
      offset = 0
      lines.each do |line|
        line_width = Ansi.string_width(line)
        if width > 0 && line_width > width
          offset += line_width // width
        end
        if line_width == 0 || width == 0 || (line_width % width) != 0
          offset += 1
        end
      end

      @buf << "\n" * offset
      @cur.y += offset

      move_cursor(newbuf, 0, 0, false)
      @buf << Ansi.insert_line(offset)
      lines.each do |line|
        @buf << line
        @buf << "\r\n"
      end
    end

    def move_cursor(newbuf : RenderBuffer?, x : Int32, y : Int32, overwrite : Bool) : Nil
      if !fullscreen? && (@flags & TerminalFlags::RelativeCursor) == TerminalFlags::RelativeCursor &&
         @cur.x == -1 && @cur.y == -1
        @buf << "\r"
        @cur.x = 0
        @cur.y = 0
      end

      seq, scroll_height = move_cursor_sequence(newbuf, x, y, overwrite)
      @scroll_height = Math.max(@scroll_height, scroll_height)
      @buf << seq
      @cur.x = x
      @cur.y = y
    end

    # ameba:disable Metrics/CyclomaticComplexity
    def move(newbuf : RenderBuffer?, x : Int32, y : Int32) : Nil
      width = 0
      height = 0
      if curbuf = @curbuf
        width = curbuf.width
        height = curbuf.height
      end
      if newbuf
        width = Math.max(newbuf.width, width)
        height = Math.max(newbuf.height, height)
      end

      if width > 0 && x >= width
        y += x // width
        x = x % width
      end

      blank = clear_blank
      reset_pen = y != @cur.y && blank != EMPTY_CELL
      update_pen(nil) if reset_pen

      if @at_phantom
        @cur.x = 0
        @buf << "\r"
        @at_phantom = false
      end

      # TODO: Investigate if we need to handle this case and/or if we need the
      # following code.
      #
      # if width > 0 && @cur.x >= width
      #   l := (@cur.x + 1) // width
      #
      #   @cur.y += l
      #   if height > 0 && @cur.y >= height
      #     l -= @cur.y - height - 1
      #   end
      #
      #   if l > 0
      #     @cur.x = 0

      if height > 0
        @cur.y = height - 1 if @cur.y > height - 1
        y = height - 1 if y > height - 1
      end

      return if x == @cur.x && y == @cur.y

      move_cursor(newbuf, x, y, true)
    end

    # ameba:enable Metrics/CyclomaticComplexity

    def put_cell(newbuf : RenderBuffer, cell : Cell?) : Nil
      width = newbuf.width
      height = newbuf.height
      if fullscreen? && @cur.x == width - 1 && @cur.y == height - 1
        put_cell_lr(newbuf, cell)
      else
        put_attr_cell(newbuf, cell)
      end
    end

    def wrap_cursor : Nil
      auto_right_margin = true
      if auto_right_margin
        @cur.x = 0
        @cur.y += 1
      else
        @cur.x -= 1
      end
    end

    def put_attr_cell(newbuf : RenderBuffer, cell : Cell?) : Nil
      if cell && cell.zero?
        return
      end

      if @at_phantom
        wrap_cursor
        @at_phantom = false
      end

      update_pen(cell)
      cell_width = 1
      if cell
        @buf << cell.content
        cell_width = cell.width
      else
        @buf << ' '
      end

      @cur.x += cell_width
      if @cur.x >= newbuf.width
        @at_phantom = true
      end
    end

    def put_cell_lr(newbuf : RenderBuffer, cell : Cell?) : Nil
      cur_x = @cur.x
      if cell.nil? || !cell.zero?
        @buf << Ansi::ResetAutoWrapMode
        put_attr_cell(newbuf, cell)
        @at_phantom = false
        @cur.x = cur_x
        @buf << Ansi::SetAutoWrapMode
      end
    end

    def update_pen(cell : Cell?) : Nil
      if cell.nil?
        unless @cur.cell.style.zero?
          @buf << Ansi::ResetStyle
          @cur.cell = Cell.new(@cur.cell.content, @cur.cell.width, Style.new, @cur.cell.link)
        end
        unless @cur.cell.link.empty?
          @buf << Ansi.reset_hyperlink
        end
        return
      end

      new_style = Ultraviolet.convert_style(cell.style, @profile)
      new_link = Ultraviolet.convert_link(cell.link, @profile)
      old_style = Ultraviolet.convert_style(@cur.cell.style, @profile)
      old_link = Ultraviolet.convert_link(@cur.cell.link, @profile)

      unless new_style == old_style
        seq = new_style.diff(old_style, @profile)
        if new_style.zero? && seq.bytesize > Ansi::ResetStyle.bytesize
          seq = Ansi::ResetStyle
        end
        @buf << seq
        @cur.cell = Cell.new(@cur.cell.content, @cur.cell.width, cell.style, @cur.cell.link)
      end

      unless new_link == old_link
        @buf << Ansi.set_hyperlink(new_link.url, new_link.params)
        @cur.cell = Cell.new(@cur.cell.content, @cur.cell.width, @cur.cell.style, cell.link)
      end
    end

    # ameba:disable Metrics/CyclomaticComplexity
    def emit_range(newbuf : RenderBuffer, line : Line, start : Int32, n : Int32) : Bool
      has_ech = (@caps & Capabilities::ECH) == Capabilities::ECH
      has_rep = (@caps & Capabilities::REP) == Capabilities::REP

      if has_ech || has_rep
        idx = start
        remaining = n
        while remaining > 0
          while remaining > 1 && !Ultraviolet.cell_equal?(line.at(idx), line.at(idx + 1))
            put_cell(newbuf, line.at(idx))
            idx += 1
            remaining -= 1
          end

          cell0 = line.at(idx)
          if remaining == 1
            put_cell(newbuf, cell0)
            return false
          end

          count = 2
          while count < remaining && Ultraviolet.cell_equal?(line.at(idx + count), cell0)
            count += 1
          end

          ech = Ansi.erase_character(count)
          cup = Ansi.cursor_position(@cur.x + count, @cur.y)
          rep = Ansi.repeat_previous_character(count)

          if has_ech && count > ech.bytesize + cup.bytesize && can_clear_with(cell0)
            update_pen(cell0)
            @buf << ech

            if count < remaining
              move(newbuf, @cur.x + count, @cur.y)
            else
              return true
            end
          elsif has_rep && count > rep.bytesize && cell0 &&
                cell0.content.bytesize == 1 &&
                cell0.content.bytes.first >= Ansi::US && cell0.content.bytes.first < Ansi::DEL
            wrap_possible = @cur.x + count >= newbuf.width
            rep_count = count
            rep_count -= 1 if wrap_possible

            update_pen(cell0)
            put_cell(newbuf, cell0)
            rep_count -= 1

            @buf << Ansi.repeat_previous_character(rep_count)
            @cur.x += rep_count
            put_cell(newbuf, cell0) if wrap_possible
          else
            i = 0
            while i < count
              put_cell(newbuf, line.at(idx + i))
              i += 1
            end
          end

          idx += count
          remaining -= count
        end

        return false
      end

      i = 0
      while i < n
        put_cell(newbuf, line.at(start + i))
        i += 1
      end

      false
    end

    # ameba:enable Metrics/CyclomaticComplexity

    def put_range(newbuf : RenderBuffer, old_line : Line, new_line : Line, y : Int32, start : Int32, finish : Int32) : Bool
      inline = Math.min(Ansi.cursor_position(start + 1, y + 1).bytesize,
        Math.min(Ansi.horizontal_position_absolute(start + 1).bytesize,
          Ansi.cursor_forward(start + 1).bytesize))

      if (finish - start + 1) > inline
        j = start
        same = 0
        while j <= finish
          old_cell = old_line.at(j)
          new_cell = new_line.at(j)
          if same == 0 && old_cell && old_cell.zero?
            j += 1
            next
          end
          if Ultraviolet.cell_equal?(old_cell, new_cell)
            same += 1
          else
            if same > finish - start
              emit_range(newbuf, new_line, start, j - same - start)
              move(newbuf, j, y)
              start = j
            end
            same = 0
          end
          j += 1
        end

        eoi = emit_range(newbuf, new_line, start, j - same - start)
        return true if same != 0
        return eoi
      end

      emit_range(newbuf, new_line, start, finish - start + 1)
    end

    def clear_to_end(newbuf : RenderBuffer, blank : Cell?, force : Bool) : Nil
      if @cur.y >= 0
        if curbuf = @curbuf
          curline = curbuf.line(@cur.y)
          if curline
            j = @cur.x
            while j < newbuf.width
              if j >= 0
                c = curline.at(j)
                unless Ultraviolet.cell_equal?(c, blank)
                  curline.set(j, blank)
                  force = true
                end
              end
              j += 1
            end
          end
        end
      end

      if force
        update_pen(blank)
        count = newbuf.width - @cur.x
        if el0_cost <= count
          @buf << Ansi::EraseLineRight
        else
          i = 0
          while i < count
            put_cell(newbuf, blank)
            i += 1
          end
        end
      end
    end

    def clear_blank : Cell?
      @cur.cell
    end

    def insert_cells(newbuf : RenderBuffer, cells : Array(Cell), count : Int32) : Nil
      supports_ich = (@caps & Capabilities::ICH) == Capabilities::ICH
      if supports_ich
        @buf << Ansi.insert_character(count)
      else
        @buf << Ansi::SetInsertReplaceMode
      end

      i = 0
      remaining = count
      while remaining > 0
        put_attr_cell(newbuf, cells[i])
        i += 1
        remaining -= 1
      end

      @buf << Ansi::ResetInsertReplaceMode unless supports_ich
    end

    def el0_cost : Int32
      return 0 if @caps != Capabilities::None
      Ansi::EraseLineRight.bytesize
    end

    # ameba:disable Metrics/CyclomaticComplexity
    def transform_line(newbuf : RenderBuffer, y : Int32) : Nil
      old_line = @curbuf.try &.line(y)
      new_line = newbuf.line_at(y)
      virtual_old = false
      if old_line.nil?
        old_line = Line.new(newbuf.width)
        virtual_old = true
      end

      first_cell = 0
      blank = new_line.at(0)

      if can_clear_with(blank)
        o_first = 0
        curbuf = @curbuf
        old_width = curbuf ? curbuf.width : old_line.width
        while o_first < old_width
          break unless Ultraviolet.cell_equal?(old_line.at(o_first), blank)
          o_first += 1
        end
        n_first = 0
        while n_first < newbuf.width
          break unless Ultraviolet.cell_equal?(new_line.at(n_first), blank)
          n_first += 1
        end

        if n_first == o_first
          first_cell = n_first
          while first_cell < newbuf.width && Ultraviolet.cell_equal?(old_line.at(first_cell), new_line.at(first_cell))
            first_cell += 1
          end
        elsif o_first > n_first
          first_cell = n_first
        else
          first_cell = o_first
          el1_cost = Ansi::EraseLineLeft.bytesize
          if el1_cost < n_first - o_first
            if n_first >= newbuf.width
              move(newbuf, 0, y)
              update_pen(blank)
              @buf << Ansi::EraseLineRight
            else
              move(newbuf, n_first - 1, y)
              update_pen(blank)
              @buf << Ansi::EraseLineLeft
            end

            while first_cell < n_first
              old_line.set(first_cell, blank)
              first_cell += 1
            end
          end
        end
      else
        while first_cell < newbuf.width && Ultraviolet.cell_equal?(new_line.at(first_cell), old_line.at(first_cell))
          first_cell += 1
        end
      end

      return if first_cell >= newbuf.width

      blank = new_line.at(newbuf.width - 1)
      if blank && !can_clear_with(blank)
        n_last = newbuf.width - 1
        while n_last > first_cell && Ultraviolet.cell_equal?(new_line.at(n_last), old_line.at(n_last))
          n_last -= 1
        end

        if n_last >= first_cell
          move(newbuf, first_cell, y)
          put_range(newbuf, old_line, new_line, y, first_cell, n_last)
          copy_line(old_line, new_line, first_cell) unless virtual_old
        end

        return
      end

      o_last = newbuf.width - 1
      while o_last > first_cell && Ultraviolet.cell_equal?(old_line.at(o_last), blank)
        o_last -= 1
      end

      n_last = newbuf.width - 1
      while n_last > first_cell && Ultraviolet.cell_equal?(new_line.at(n_last), blank)
        n_last -= 1
      end

      if n_last == first_cell && el0_cost < o_last - n_last
        move(newbuf, first_cell, y)
        if !Ultraviolet.cell_equal?(new_line.at(first_cell), blank)
          put_cell(newbuf, new_line.at(first_cell))
        end
        clear_to_end(newbuf, blank, false)
      elsif n_last != o_last && !Ultraviolet.cell_equal?(new_line.at(n_last), old_line.at(o_last))
        move(newbuf, first_cell, y)
        if o_last - n_last > el0_cost
          if put_range(newbuf, old_line, new_line, y, first_cell, n_last)
            move(newbuf, n_last + 1, y)
          end
          clear_to_end(newbuf, blank, false)
        else
          n = Math.max(n_last, o_last)
          put_range(newbuf, old_line, new_line, y, first_cell, n)
        end
      else
        n_last_non_blank = n_last
        o_last_non_blank = o_last

        while Ultraviolet.cell_equal?(new_line.at(n_last), old_line.at(o_last))
          break unless Ultraviolet.cell_equal?(new_line.at(n_last - 1), old_line.at(o_last - 1))
          n_last -= 1
          o_last -= 1
          break if n_last == -1 || o_last == -1
        end

        n = Math.min(o_last, n_last)
        if n >= first_cell
          move(newbuf, first_cell, y)
          put_range(newbuf, old_line, new_line, y, first_cell, n)
        end

        if o_last < n_last
          m = Math.max(n_last_non_blank, o_last_non_blank)
          if n != 0
            while n > 0
              wide = new_line.at(n + 1)
              break if wide.nil? || !wide.zero?
              n -= 1
              o_last -= 1
            end
          elsif n >= first_cell && (cell = new_line.at(n)) && cell.width > 1
            next_cell = new_line.at(n + 1)
            while next_cell && next_cell.zero?
              n += 1
              o_last += 1
              next_cell = new_line.at(n + 1)
            end
          end

          # TODO: This can sometimes send unnecessary cursor movements with
          # negative or zero ranges. This could happen on a screen resize
          # where o_last < n_last and o_last is -1 or less.
          # Investigate and fix.
          move(newbuf, n + 1, y)
          ich_cost = 3 + n_last - o_last
          if (@caps & Capabilities::ICH) == Capabilities::ICH && (n_last < n_last_non_blank || ich_cost > (m - n))
            put_range(newbuf, old_line, new_line, y, n + 1, m)
          else
            insert_cells(newbuf, new_line.cells[(n + 1)...], n_last - o_last)
          end
        elsif o_last > n_last
          move(newbuf, n + 1, y)
          dch_cost = 3 + o_last - n_last
          if dch_cost > Ansi::EraseLineRight.bytesize + n_last_non_blank - (n + 1)
            if put_range(newbuf, old_line, new_line, y, n + 1, n_last_non_blank)
              move(newbuf, n_last_non_blank + 1, y)
            end
            clear_to_end(newbuf, blank, false)
          else
            update_pen(blank)
            delete_cells(o_last - n_last)
          end
        end
      end

      copy_line(old_line, new_line, first_cell) unless virtual_old
    end

    # ameba:enable Metrics/CyclomaticComplexity

    def delete_cells(count : Int32) : Nil
      @buf << Ansi.delete_character(count)
    end

    def clear_to_bottom(blank : Cell?) : Nil
      row = @cur.y
      col = @cur.x
      row = 0 if row < 0

      update_pen(blank)
      @buf << Ansi::EraseScreenBelow
      if curbuf = @curbuf
        curbuf.clear_area(Ultraviolet.rect(col, row, curbuf.width - col, 1))
        curbuf.clear_area(Ultraviolet.rect(0, row + 1, curbuf.width, curbuf.height - row - 1))
      end
    end

    # ameba:disable Metrics/CyclomaticComplexity
    def clear_bottom(newbuf : RenderBuffer, total : Int32) : Int32
      return 0 if total <= 0

      top = total
      curbuf = @curbuf
      return 0 unless curbuf
      last = Math.min(curbuf.width, newbuf.width)
      blank = clear_blank
      can_clear = can_clear_with(blank)

      if can_clear
        row = total - 1
        while row >= 0
          old_line = curbuf.line(row)
          new_line = newbuf.line(row)

          col = 0
          ok = true
          if new_line
            while ok && col < last
              ok = Ultraviolet.cell_equal?(new_line.at(col), blank)
              col += 1
            end
          else
            ok = false
          end
          break unless ok

          col = 0
          if old_line
            while ok && col < last
              ok = Ultraviolet.cell_equal?(old_line.at(col), blank)
              col += 1
            end
          else
            ok = false
          end
          top = row unless ok
          row -= 1
        end

        if top < total
          move(newbuf, 0, Math.max(0, top - 1))
          clear_to_bottom(blank)
          if !@oldhash.empty? && !@newhash.empty?
            row = top
            while row < newbuf.height
              @oldhash[row] = @newhash[row]
              row += 1
            end
          end
        end
      end

      top
    end

    # ameba:enable Metrics/CyclomaticComplexity

    def clear_screen(blank : Cell?) : Nil
      update_pen(blank)
      @buf << Ansi::CursorHomePosition
      @buf << Ansi::EraseEntireScreen
      @cur.x = 0
      @cur.y = 0
      @curbuf.try &.fill(blank)
    end

    def clear_below(newbuf : RenderBuffer, blank : Cell?, row : Int32) : Nil
      move(newbuf, 0, row)
      clear_to_bottom(blank)
    end

    def clear_update(newbuf : RenderBuffer) : Nil
      blank = clear_blank
      non_empty = 0
      if fullscreen?
        curbuf = @curbuf
        return if curbuf.nil?
        non_empty = Math.max(curbuf.height, newbuf.height)
        clear_screen(blank)
      else
        non_empty = newbuf.height
        clear_below(newbuf, blank, 0)
      end
      non_empty = clear_bottom(newbuf, non_empty)
      i = 0
      while i < non_empty && i < newbuf.height
        transform_line(newbuf, i)
        i += 1
      end
    end

    def logf(format : String, *args) : Nil
      logger = @logger
      return unless logger
      logger.printf(format, *args)
    end

    def buffered : Int32
      @buf.size
    end

    def flush : Nil
      return if @buf.size == 0

      if @logger
        logf("output: %s", @buf.to_slice.inspect)
      end
      @writer.write(@buf.to_slice)
      @buf.clear
    end

    def touched(buffer : RenderBuffer) : Int32
      buffer.touched_lines
    end

    def redraw(newbuf : RenderBuffer) : Nil
      @clear = true
      render(newbuf)
    end

    # ameba:disable Metrics/CyclomaticComplexity
    def render(newbuf : RenderBuffer) : Nil
      touched_lines = newbuf.touched_lines
      return if !@clear && touched_lines == 0

      curbuf = @curbuf
      if curbuf.nil? || curbuf.bounds.empty?
        @curbuf = RenderBuffer.new(newbuf.width, newbuf.height)
      end

      new_width = newbuf.width
      new_height = newbuf.height
      curbuf = @curbuf
      return unless curbuf
      cur_width = curbuf.width
      cur_height = curbuf.height

      if cur_width != new_width || cur_height != new_height
        @oldhash.clear
        @newhash.clear
      end

      # TODO: Investigate whether this is necessary. Theoretically, terminals
      # can add/remove tab stops and we should be able to handle that. We could
      # use [ansi.DECTABSR] to read the tab stops, but that's not implemented in
      # most terminals :/
      # // Are we using hard tabs? If so, ensure tabs are using the
      # // default interval using [ansi.DECST8C].
      # if s.opts.HardTabs && !s.initTabs {
      #   s.buf.WriteString(ansi.SetTabEvery8Columns)
      #   s.initTabs = true
      # }

      partial_clear = !fullscreen? && @cur.x != -1 && @cur.y != -1 &&
                      cur_width == new_width && cur_height > 0 && cur_height > new_height

      if !@clear && partial_clear
        clear_below(newbuf, nil, new_height - 1)
      end

      if @clear
        clear_update(newbuf)
        @clear = false
      elsif touched_lines > 0
        if (@flags & TerminalFlags::ScrollOptim) == TerminalFlags::ScrollOptim && fullscreen?
          # Optimize scrolling for the alternate screen buffer.
          # TODO: Should we optimize for inline mode as well? If so, we need
          # to know the actual cursor position to use [ansi.DECSTBM].
          scroll_optimize(newbuf)
        end

        non_empty = fullscreen? ? Math.min(cur_height, new_height) : new_height
        non_empty = clear_bottom(newbuf, non_empty)

        i = 0
        while i < non_empty && i < new_height
          touched_line = newbuf.touched[i]?
          if touched_line.nil? || touched_line.first_cell != -1 || touched_line.last_cell != -1
            transform_line(newbuf, i)
          end

          if i < newbuf.touched.size
            newbuf.touched[i] = LineData.new(-1, -1)
          end
          if current = @curbuf
            if i < current.touched.size
              current.touched[i] = LineData.new(-1, -1)
            end
          end
          i += 1
        end
      end

      if !fullscreen? && @scroll_height < new_height - 1
        move(newbuf, 0, new_height - 1)
      end

      newbuf.touched = Array(LineData?).new(new_height) { LineData.new(-1, -1) }
      if current = @curbuf
        current.touched = Array(LineData?).new(current.height) { LineData.new(-1, -1) }
      end

      if cur_width != new_width || cur_height != new_height
        curbuf.resize(new_width, new_height)
        i = cur_height - 1
        while i < new_height
          line = curbuf.line_at(i)
          new_line = newbuf.line_at(i)
          copy_line(line, new_line, 0)
          i += 1
        end
      end

      update_pen(nil)
    end

    # ameba:enable Metrics/CyclomaticComplexity

    def erase : Nil
      @clear = true
    end

    def resize(width : Int32, _height : Int32) : Nil
      @tabs.try &.resize(width)
      @scroll_height = 0
    end

    def position : {Int32, Int32}
      {@cur.x, @cur.y}
    end

    def set_position(x : Int32, y : Int32) : Nil
      @cur.x = x
      @cur.y = y
    end

    def write_string(value : String) : Int32
      @buf << value
      value.bytesize
    end

    def write(bytes : Bytes) : Int32
      @buf.write(bytes)
      bytes.size
    end

    def move_to(x : Int32, y : Int32) : Nil
      move(nil, x, y)
    end

    private def can_clear_with(cell : Cell?) : Bool
      return true if cell.nil?
      return false unless cell.width == 1 && cell.content == " "
      style = cell.style
      style.underline == Underline::None &&
        (style.attrs & ~(Attr::BOLD | Attr::FAINT | Attr::ITALIC | Attr::BLINK | Attr::RAPID_BLINK)) == 0 &&
        cell.link.empty?
    end

    private def copy_line(old_line : Line, new_line : Line, start : Int32) : Nil
      idx = start
      while idx < new_line.width && idx < old_line.width
        old_line.cells[idx] = new_line.cells[idx]
        idx += 1
      end
    end

    private def not_local(cols : Int32, fx : Int32, fy : Int32, tx : Int32, ty : Int32) : Bool
      long_dist = 7
      tx > long_dist && tx < cols - 1 - long_dist && (Ultraviolet.abs(ty - fy) + Ultraviolet.abs(tx - fx) > long_dist)
    end

    # ameba:disable Metrics/CyclomaticComplexity
    private def relative_cursor_move(
      newbuf : RenderBuffer?,
      fx : Int32,
      fy : Int32,
      tx : Int32,
      ty : Int32,
      overwrite : Bool,
      use_tabs : Bool,
      use_backspace : Bool,
    ) : {String, Int32}
      seq = String::Builder.new
      scroll_height = 0
      overwrite_allowed = overwrite
      overwrite_allowed = false unless newbuf

      if ty != fy
        yseq = ""
        if (@caps & Capabilities::VPA) == Capabilities::VPA && (@flags & TerminalFlags::RelativeCursor) == TerminalFlags::None
          yseq = Ansi.vertical_position_absolute(ty + 1)
        end

        if ty > fy
          n = ty - fy
          cud = Ansi.cursor_down(n)
          yseq = cud if yseq.empty? || cud.bytesize < yseq.bytesize
          should_scroll = !fullscreen? && ty > @scroll_height
          if should_scroll || n < yseq.bytesize
            yseq = "\n" * n
            scroll_height = ty
            fx = 0 if (@flags & TerminalFlags::MapNewline) == TerminalFlags::MapNewline
          end
        elsif ty < fy
          n = fy - ty
          cuu = Ansi.cursor_up(n)
          yseq = cuu if yseq.empty? || cuu.bytesize < yseq.bytesize
          if n == 1 && fy - 1 > 0
            # TODO: Ensure we're not unintentionally scrolling the screen up.
            yseq = "\eM"
          end
        end

        seq << yseq
      end

      if tx != fx
        xseq = ""
        if (@flags & TerminalFlags::RelativeCursor) == TerminalFlags::None
          if (@caps & Capabilities::HPA) == Capabilities::HPA
            xseq = Ansi.horizontal_position_absolute(tx + 1)
          elsif (@caps & Capabilities::CHA) == Capabilities::CHA
            xseq = Ansi.cursor_horizontal_absolute(tx + 1)
          end
        end

        if tx > fx
          n = tx - fx
          if use_tabs && (tabs = @tabs)
            tabs_count = 0
            col = fx
            while tabs.next(col) <= tx
              tabs_count += 1
              col = tabs.next(col)
              break if col == tabs.next(col) || col >= tabs.width - 1
            end

            if tabs_count > 0
              # TODO: The linux console and some terminals such as
              # Alacritty don't support [ansi.CHT]. Enable this when
              # we have a way to detect this, or after 5 years when
              # we're sure everyone has updated their terminals :P
              # if (@caps & Capabilities::CHT) == Capabilities::CHT
              #   seq << Ansi.cursor_horizontal_forward_tab(tabs_count)
              # else
              tab = "\t" * tabs_count
              seq << tab
              # end
              n = tx - col
              fx = col
            end
          end

          cuf = Ansi.cursor_forward(n)
          xseq = cuf if xseq.empty? || cuf.bytesize < xseq.bytesize

          if overwrite_allowed && ty >= 0
            i = 0
            while i < n
              cell = newbuf.try &.cell_at(fx + i, ty)
              if cell && cell.width > 0
                i += cell.width - 1
                if cell.style != @cur.cell.style || cell.link != @cur.cell.link
                  overwrite_allowed = false
                  break
                end
              end
              i += 1
            end
          end

          if overwrite_allowed && ty >= 0
            ovw = String::Builder.new
            i = 0
            while i < n
              cell = newbuf.try &.cell_at(fx + i, ty)
              if cell && cell.width > 0
                ovw << cell.content
                i += cell.width - 1
              else
                ovw << ' '
              end
              i += 1
            end
            xseq = ovw.to_s if ovw.bytesize < xseq.bytesize
          end
        elsif tx < fx
          n = fx - tx
          if use_tabs && (tabs = @tabs) && (@caps & Capabilities::CBT) == Capabilities::CBT
            col = fx
            cbt = 0
            while tabs.prev(col) >= tx
              col = tabs.prev(col)
              cbt += 1
              break if col == tabs.prev(col) || col <= 0
            end

            if cbt > 0
              seq << Ansi.cursor_backward_tab(cbt)
              n = col - tx
            end
          end

          cub = Ansi.cursor_backward(n)
          xseq = cub if xseq.empty? || cub.bytesize < xseq.bytesize
          if use_backspace && n < xseq.bytesize
            xseq = "\b" * n
          end
        end

        seq << xseq
      end

      {seq.to_s, scroll_height}
    end

    # ameba:enable Metrics/CyclomaticComplexity

    # ameba:disable Metrics/CyclomaticComplexity
    private def move_cursor_sequence(newbuf : RenderBuffer?, x : Int32, y : Int32, overwrite : Bool) : {String, Int32}
      fx = @cur.x
      fy = @cur.y
      seq = ""
      scroll_height = 0

      if (@flags & TerminalFlags::RelativeCursor) == TerminalFlags::None
        width = -1
        if tabs = @tabs
          width = tabs.width
        end
        width = newbuf.width if newbuf && width == -1
        seq = Ansi.cursor_position(x + 1, y + 1)
        if fx == -1 || fy == -1 || width == -1 || not_local(width, fx, fy, x, y)
          return {seq, 0}
        end
      end

      trials = 0
      trials |= 2 if (@caps & Capabilities::HT) == Capabilities::HT
      trials |= 1 if (@caps & Capabilities::BS) == Capabilities::BS

      i = 0
      while i <= trials
        if (i & ~trials) != 0
          i += 1
          next
        end

        use_tabs = (i & 2) != 0
        use_backspace = (i & 1) != 0

        nseq1, nscroll1 = relative_cursor_move(newbuf, fx, fy, x, y, overwrite, use_tabs, use_backspace)
        if (i == 0 && seq.empty?) || nseq1.bytesize < seq.bytesize
          seq = nseq1
          scroll_height = Math.max(scroll_height, nscroll1)
        end

        nseq2, nscroll2 = relative_cursor_move(newbuf, 0, fy, x, y, overwrite, use_tabs, use_backspace)
        nseq2 = "\r" + nseq2
        if nseq2.bytesize < seq.bytesize
          seq = nseq2
          scroll_height = Math.max(scroll_height, nscroll2)
        end

        if (@flags & TerminalFlags::RelativeCursor) == TerminalFlags::None
          nseq3, nscroll3 = relative_cursor_move(newbuf, 0, 0, x, y, overwrite, use_tabs, use_backspace)
          nseq3 = Ansi::CursorHomePosition + nseq3
          if nseq3.bytesize < seq.bytesize
            seq = nseq3
            scroll_height = Math.max(scroll_height, nscroll3)
          end
        end

        i += 1
      end

      {seq, scroll_height}
    end

    # ameba:enable Metrics/CyclomaticComplexity

    private def xterm_caps(termtype : String) : Capabilities
      parts = termtype.split('-')
      return Capabilities::None if parts.empty?

      caps = Capabilities::None
      base = parts[0]?
      case base
      when "contour", "foot", "ghostty", "kitty", "rio", "st", "tmux", "wezterm"
        caps = all_caps
      when "xterm"
        if parts.size > 1 && {"ghostty", "kitty", "rio"}.includes?(parts[1])
          caps = all_caps
        else
          caps = all_caps
          caps &= ~Capabilities::HPA
          caps &= ~Capabilities::CHT
          caps &= ~Capabilities::REP
        end
      when "alacritty"
        caps = all_caps
        caps &= ~Capabilities::CHT
      when "screen"
        caps = all_caps
        caps &= ~Capabilities::REP
      when "linux"
        caps = Capabilities::VPA | Capabilities::CHA | Capabilities::HPA | Capabilities::ECH | Capabilities::ICH
      end

      caps
    end

    private def all_caps : Capabilities
      Capabilities::VPA | Capabilities::HPA | Capabilities::CHA | Capabilities::CHT | Capabilities::CBT |
        Capabilities::REP | Capabilities::ECH | Capabilities::ICH | Capabilities::SD | Capabilities::SU
    end
  end
end
