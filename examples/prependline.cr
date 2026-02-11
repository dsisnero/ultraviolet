require "../src/ultraviolet"

term = Ultraviolet::Terminal.default_terminal
term.start
term.exit_alt_screen

width, _ = term.fetch_size
frame_height = 1
term.resize(width, frame_height)

style = Ultraviolet::Style.new
style.fg = Ultraviolet::Ansi::Black.to_color
style.bg = Ultraviolet::Ansi::BasicColor.new(rand(16).to_u8).to_color

render = -> do
  bg = Ultraviolet::EMPTY_CELL
  bg.style = style
  term.fill_area(bg, Ultraviolet.rect(0, 0, term.bounds.dx, 1))

  "Hello, World!".each_char_with_index do |r, i|
    term.set_cell(i, 0, Ultraviolet::Cell.new(r.to_s, 1, style))
  end
  term.display
end

begin
  render.call
  loop do
    ev = term.events.receive
    case ev
    when Ultraviolet::KeyPressEvent
      break if ev.match_string("q", "ctrl+c")
      term.prepend_string("#{ev.class} #{ev}")
      style.bg = Ultraviolet::Ansi::BasicColor.new(rand(16).to_u8).to_color
      render.call
    when Ultraviolet::WindowSizeEvent
      width = ev.width
      term.resize(width, frame_height)
      term.erase
      render.call
    end
  end
ensure
  term.shutdown(1.second)
end
