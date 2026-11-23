require "../src/ultraviolet"

# Layout example: header, two-column body, and footer using the Layout API.

term = Ultraviolet::Terminal.default_terminal
term.start
term.enter_alt_screen

style = ->(r : UInt8, g : UInt8, b : UInt8) do
  Ultraviolet::Style.new(bg: Ultraviolet::Color.new(r, g, b))
end

header_style = style.call(70_u8, 70_u8, 150_u8)
left_style = style.call(30_u8, 130_u8, 70_u8)
right_style = style.call(150_u8, 90_u8, 30_u8)
footer_style = style.call(120_u8, 40_u8, 120_u8)

render = -> do
  area = term.bounds
  rows = Ultraviolet::Layout.vertical(
    Ultraviolet::Layout::Len.new(2),
    Ultraviolet::Layout::Min.new(0),
    Ultraviolet::Layout::Len.new(1),
  ).split(area)

  header = rows[0]
  body = rows[1]
  footer = rows[2]
  columns = Ultraviolet::Layout.horizontal(
    Ultraviolet::Layout::Percent.new(60),
    Ultraviolet::Layout::Min.new(0),
  ).split(body)

  term.fill_area(Ultraviolet::Cell.new(" ", 1, header_style), header)
  term.fill_area(Ultraviolet::Cell.new(" ", 1, left_style), columns[0])
  term.fill_area(Ultraviolet::Cell.new(" ", 1, right_style), columns[1])
  term.fill_area(Ultraviolet::Cell.new(" ", 1, footer_style), footer)

  Ultraviolet::StyledString.new("Layout API").draw(term, header)
  Ultraviolet::StyledString.new("60%").draw(term, columns[0])
  Ultraviolet::StyledString.new("Min(0)").draw(term, columns[1])
  Ultraviolet::StyledString.new("footer").draw(term, footer)
  term.display
end

begin
  render.call
  loop do
    case event = term.events.receive
    when Ultraviolet::WindowSizeEvent
      term.resize(event.width, event.height)
      render.call
    when Ultraviolet::Key
      break if event.match_string("q", "ctrl+c", "esc")
    end
  end
ensure
  term.stop
end
