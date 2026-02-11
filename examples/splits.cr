require "../src/ultraviolet"

struct DemoLayout
  getter main : Ultraviolet::Rectangle
  getter footer : Ultraviolet::Rectangle
  getter sidebar : Ultraviolet::Rectangle

  def initialize(area : Ultraviolet::Rectangle)
    main_and_footer, @sidebar = Ultraviolet.split_horizontal(area, Ultraviolet::Percent.new(80))
    @main, @footer = Ultraviolet.split_vertical(main_and_footer, Ultraviolet::Fixed.new((area.dy - 7).clamp(0, area.dy)))
  end
end

term = Ultraviolet::Terminal.default_terminal
term.start

blue = Ultraviolet::EMPTY_CELL
blue.style.bg = Ultraviolet::Ansi::Blue.to_color
red = Ultraviolet::EMPTY_CELL
red.style.bg = Ultraviolet::Ansi::Red.to_color
green = Ultraviolet::EMPTY_CELL
green.style.bg = Ultraviolet::Ansi::Green.to_color

area = term.bounds

render = -> do
  layout = DemoLayout.new(area)
  term.fill_area(blue, layout.main)
  term.fill_area(red, layout.footer)
  term.fill_area(green, layout.sidebar)
  term.display
end

begin
  render.call
  loop do
    case ev = term.events.receive
    when Ultraviolet::WindowSizeEvent
      area = ev.bounds
      term.resize(area.dx, area.dy)
      term.erase
      render.call
    when Ultraviolet::KeyPressEvent
      break if ev.match_string("q", "ctrl+c")
    end
  end
ensure
  term.shutdown(1.second)
end
