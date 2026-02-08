require "../src/ultraviolet"

module DrawExample
  extend self

  def run
    t = Ultraviolet::Terminal.default_terminal
    begin
      t.start
    rescue ex
      STDERR.puts "failed to start program: #{ex.message}"
      exit 1
    end

    modes = {
      Ultraviolet::Ansi::ModeMouseButtonEvent,
      Ultraviolet::Ansi::ModeMouseExtSgr,
      Ultraviolet::Ansi::ModeFocusEvent,
    }

    t.write_string(Ultraviolet::Ansi.set_mode(*modes))

    width, height = t.fetch_size

    # Listen for input and mouse events.
    ctx = Channel(Nil).new

    help = %(Welcome to Draw Example!

Use the mouse to draw on the screen.
Press ctrl+c to exit.
Press esc to clear the screen.
Press alt+esc to reset the pen character, color, and the screen.
Press 0-9 to set the foreground color.
Press any other key to set the pen character.
Press ctrl+h for this help message.

Press any key to continue...)

    help_comp = Ultraviolet::StyledString.new(help)
    help_area = help_comp.bounds
    help_w, help_h = help_area.dx, help_area.dy

    prev_help_buf = nil
    showing_help = true

    display_help = ->(show : Bool) do
      mid_x, mid_y = width // 2, height // 2
      x, y = mid_x - help_w // 2, mid_y - help_h // 2
      mid_area = Ultraviolet.rect(x, y, help_w, help_h)
      if show
        # Save the area under the help to restore it later.
        prev_help_buf = Ultraviolet::Screen.clone_area(t, mid_area)
        help_comp.draw(t, mid_area)
      elsif buf = prev_help_buf
        # Restore saved area under the help.
        buf.draw(t, mid_area)
      end
      t.display
    end

    clear_screen = -> do
      Ultraviolet::Screen.clear(t)
      t.display
    end

    # Display first frame.
    display_help.call(showing_help)

    default_char = "█"
    pen = Ultraviolet::EMPTY_CELL
    pen.content = default_char

    draw = ->(ev : Ultraviolet::MouseClickEvent | Ultraviolet::MouseMotionEvent) do
      m = ev.mouse
      cur = t.cell_at(m.x, m.y)
      return unless cur

      if cur.zero? && pen.width == 1
        # Find the previous wide cell.
        wide = nil
        wide_x, wide_y = 0, 0
        i = 1
        while i < 5 && m.x - i >= 0
          wide = t.cell_at(m.x - i, m.y)
          if wide && !wide.zero? && wide.width > 1
            wide_x, wide_y = m.x - i, m.y
            break
          end
          i += 1
        end

        if wide
          # Found a wide cell, make all cells blank.
          wc = wide.clone
          wc.empty!
          t.set_cell(wide_x, wide_y, wc)
        end
      end

      # Can we fit the cell?
      fit = true
      if w = pen.width
        w > 1
        if cur.zero? || cur.width > 1
          fit = false
        else
          i = 1
          while i < w
            cur = t.cell_at(m.x + i, m.y)
            unless cur && cur.zero? && cur.width > 1
              fit = false
              break
            end
            i += 1
          end
        end
      end
      return unless fit

      t.set_cell(m.x, m.y, pen)
      t.display
    end

    loop do
      select
      when ctx.receive
        break
      when ev = t.events.receive
        case ev
        when Ultraviolet::WindowSizeEvent
          if showing_help
            display_help.call(false)
          end
          width, height = ev.width, ev.height
          t.resize(ev.width, ev.height)
          t.erase
          if showing_help
            display_help.call(showing_help)
          end
        when Ultraviolet::KeyPressEvent
          if showing_help
            showing_help = false
            display_help.call(showing_help)
            next
          end
          case
          when ev.match_string("ctrl+c")
            ctx.send(nil)
          when ev.match_string("alt+esc")
            pen.style = Ultraviolet::Style.new
            pen.content = default_char
            # fallthrough
          when ev.match_string("esc")
            clear_screen.call
          when ev.match_string("ctrl+h")
            showing_help = true
            display_help.call(showing_help)
          else
            text = ev.text
            if text.empty?
              next
            end
            r = text[0]
            rw = UnicodeCharWidth.width(r.to_s)
            if rw == 1 && r.number?
              pen.style.fg = (Ultraviolet::Ansi::Black + Ultraviolet::Ansi::BasicColor.new((r - '0').to_u8)).to_color
              next
            end
            pen.content = text
            pen.width = rw
          end
        when Ultraviolet::MouseClickEvent
          next if showing_help
          draw.call(ev)
        when Ultraviolet::MouseMotionEvent
          next if showing_help || ev.mouse.button == Ultraviolet::MouseButton::None
          draw.call(ev)
        end
      end
    end

    t.write_string(Ultraviolet::Ansi.reset_mode(*modes))

    # Shutdown the program.
    unless t.shutdown(5.seconds)
      STDERR.puts "failed to shutdown program: timeout"
      exit 1
    end
  end
end

DrawExample.run if __FILE__ == $0
