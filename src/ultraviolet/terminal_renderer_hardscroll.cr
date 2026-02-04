module Ultraviolet
  class TerminalRenderer
    # ameba:disable Metrics/CyclomaticComplexity
    private def scroll_optimize(newbuf : RenderBuffer) : Nil
      height = newbuf.height
      if @oldnum.size < height
        @oldnum.concat(Array(Int32).new(height - @oldnum.size, 0))
      end

      update_hashmap(newbuf)
      return if @hashtab.size < height

      i = 0
      while i < height
        while i < height && (@oldnum[i] == NEW_INDEX || @oldnum[i] <= i)
          i += 1
        end
        break if i >= height

        shift = @oldnum[i] - i
        start = i

        i += 1
        while i < height && @oldnum[i] != NEW_INDEX && @oldnum[i] - i == shift
          i += 1
        end
        finish = i - 1 + shift

        scrolln(newbuf, shift, start, finish, height - 1)
      end

      i = height - 1
      while i >= 0
        while i >= 0 && (@oldnum[i] == NEW_INDEX || @oldnum[i] >= i)
          i -= 1
        end
        break if i < 0

        shift = @oldnum[i] - i
        finish = i

        i -= 1
        while i >= 0 && @oldnum[i] != NEW_INDEX && @oldnum[i] - i == shift
          i -= 1
        end

        start = i + 1 - (-shift)
        scrolln(newbuf, shift, start, finish, height - 1)
      end
    end

    # ameba:enable Metrics/CyclomaticComplexity

    private def scrolln(newbuf : RenderBuffer, n : Int32, top : Int32, bot : Int32, max_y : Int32) : Bool
      blank = clear_blank
      if n > 0
        ok = scroll_up(newbuf, n, top, bot, 0, max_y, blank)
        unless ok
          @buf << Ansi.set_top_bottom_margins(top + 1, bot + 1)
          @cur.x = -1
          @cur.y = -1
          ok = scroll_up(newbuf, n, top, bot, top, bot, blank)
          @buf << Ansi.set_top_bottom_margins(1, max_y + 1)
          @cur.x = -1
          @cur.y = -1
        end

        ok = scroll_idl(newbuf, n, top, bot - n + 1, blank) unless ok
        return false unless ok
      elsif n < 0
        ok = scroll_down(newbuf, -n, top, bot, 0, max_y, blank)
        unless ok
          @buf << Ansi.set_top_bottom_margins(top + 1, bot + 1)
          @cur.x = -1
          @cur.y = -1
          ok = scroll_down(newbuf, -n, top, bot, top, bot, blank)
          @buf << Ansi.set_top_bottom_margins(1, max_y + 1)
          @cur.x = -1
          @cur.y = -1
          ok = scroll_idl(newbuf, -n, bot + n + 1, top, blank) unless ok
        end
        return false unless ok
      else
        return false
      end

      curbuf = @curbuf
      return false unless curbuf
      scroll_buffer(curbuf, n, top, bot, blank)
      scroll_oldhash(n, top, bot)
      true
    end

    # ameba:disable Metrics/CyclomaticComplexity
    private def scroll_buffer(buffer : RenderBuffer, n : Int32, top : Int32, bot : Int32, blank : Cell?) : Nil
      return if top < 0 || bot < top || bot >= buffer.height

      if n < 0
        limit = top - n
        line = bot
        while line >= limit && line >= 0 && line >= top
          copy_line(buffer.line_at(line), buffer.line_at(line + n), 0)
          line -= 1
        end
        line = top
        while line < limit && line <= buffer.height - 1 && line <= bot
          buffer.fill_area(blank, Ultraviolet.rect(0, line, buffer.width, 1))
          line += 1
        end
      end

      if n > 0
        limit = bot - n
        line = top
        while line <= limit && line <= buffer.height - 1 && line <= bot
          copy_line(buffer.line_at(line), buffer.line_at(line + n), 0)
          line += 1
        end
        line = bot
        while line > limit && line >= 0 && line >= top
          buffer.fill_area(blank, Ultraviolet.rect(0, line, buffer.width, 1))
          line -= 1
        end
      end

      touch_line(buffer, top, bot - top + 1, true)
    end

    # ameba:enable Metrics/CyclomaticComplexity

    private def touch_line(newbuf : RenderBuffer, y : Int32, n : Int32, changed : Bool) : Nil
      height = newbuf.height
      return if n < 0 || y < 0 || y >= height || newbuf.touched.size < height

      width = newbuf.width
      i = y
      while i < y + n && i < height && i < newbuf.touched.size
        if changed
          newbuf.touch_line(0, i, width)
        else
          newbuf.touched[i] = nil
        end
        i += 1
      end
    end

    private def scroll_up(
      newbuf : RenderBuffer,
      n : Int32,
      top : Int32,
      bot : Int32,
      min_y : Int32,
      max_y : Int32,
      blank : Cell?,
    ) : Bool
      if n == 1 && top == min_y && bot == max_y
        move(newbuf, 0, bot)
        update_pen(blank)
        @buf << "\n"
      elsif n == 1 && bot == max_y
        move(newbuf, 0, top)
        update_pen(blank)
        @buf << Ansi.delete_line(1)
      elsif top == min_y && bot == max_y
        move(newbuf, 0, bot)
        update_pen(blank)
        if (@caps & Capabilities::SU) == Capabilities::SU
          @buf << Ansi.scroll_up(n)
        else
          @buf << "\n" * n
        end
      elsif bot == max_y
        move(newbuf, 0, top)
        update_pen(blank)
        @buf << Ansi.delete_line(n)
      else
        return false
      end
      true
    end

    private def scroll_down(
      newbuf : RenderBuffer,
      n : Int32,
      top : Int32,
      bot : Int32,
      min_y : Int32,
      max_y : Int32,
      blank : Cell?,
    ) : Bool
      if n == 1 && top == min_y && bot == max_y
        move(newbuf, 0, top)
        update_pen(blank)
        @buf << Ansi.reverse_index
      elsif n == 1 && bot == max_y
        move(newbuf, 0, top)
        update_pen(blank)
        @buf << Ansi.insert_line(1)
      elsif top == min_y && bot == max_y
        move(newbuf, 0, top)
        update_pen(blank)
        if (@caps & Capabilities::SD) == Capabilities::SD
          @buf << Ansi.scroll_down(n)
        else
          @buf << Ansi.reverse_index * n
        end
      elsif bot == max_y
        move(newbuf, 0, top)
        update_pen(blank)
        @buf << Ansi.insert_line(n)
      else
        return false
      end
      true
    end

    private def scroll_idl(newbuf : RenderBuffer, n : Int32, del : Int32, ins : Int32, blank : Cell?) : Bool
      return false if n < 0

      move(newbuf, 0, del)
      update_pen(blank)
      @buf << Ansi.delete_line(n)

      move(newbuf, 0, ins)
      update_pen(blank)
      @buf << Ansi.insert_line(n)

      true
    end
  end
end
