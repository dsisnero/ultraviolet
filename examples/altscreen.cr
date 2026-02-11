require "../src/ultraviolet"

term = Ultraviolet::Terminal.default_terminal
term.start

width, height = term.fetch_size
alt_screen = false
cursor_hidden = false

render = -> do
  frame_height = alt_screen ? height : 2
  if alt_screen
    term.enter_alt_screen
  else
    term.exit_alt_screen
  end

  term.resize(width, frame_height)
  term.erase

  mode = alt_screen ? "alternate screen" : "inline"
  text = "This is using #{mode} mode.\nPress space to toggle, q/ctrl+c to exit."
  Ultraviolet::StyledString.new(text).draw(term, term.bounds)
  term.display
end

begin
  render.call
  loop do
    case ev = term.events.receive
    when Ultraviolet::WindowSizeEvent
      width = ev.width
      height = ev.height
      render.call
    when Ultraviolet::KeyPressEvent
      if ev.match_string("q", "ctrl+c")
        break
      elsif ev.match_string("space")
        alt_screen = !alt_screen
        render.call
      else
        if cursor_hidden
          term.show_cursor
        else
          term.hide_cursor
        end
        cursor_hidden = !cursor_hidden
      end
    end
  end
ensure
  term.shutdown(1.second)
end
