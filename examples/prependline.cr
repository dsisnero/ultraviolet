require "../src/ultraviolet"

# Port of vendor/ultraviolet/examples/prependline.
#
# Paints a single line ("Hello, World!") and logs every event above it, so the
# log scrolls up the screen while the frame stays put. The background colour is
# random on each frame; q or ctrl+c quits.
#
# Like Go's, this example stays on the normal screen buffer (no EnterAltScreen),
# so the prepended lines are still in the scrollback once it exits.

term = Ultraviolet::Terminal.default_terminal
screen = term
term.start

# Go logs each event with `fmt.Sprintf("%T %v", ev, ev)`: the package-qualified
# type name followed by the value, using the event's String method when it has
# one. Crystal has neither %T nor %v, so mirror the upstream names and values
# for the events this example can receive.
def event_text(event : Ultraviolet::Event) : String
  case event
  when Ultraviolet::WindowSizeEvent
    "uv.WindowSizeEvent {#{event.width} #{event.height}}"
  when Ultraviolet::PixelSizeEvent
    "uv.PixelSizeEvent {#{event.width} #{event.height}}"
  when Ultraviolet::CellSizeEvent
    "uv.CellSizeEvent {#{event.width} #{event.height}}"
  when Ultraviolet::ModeReportEvent
    "uv.ModeReportEvent {#{event.mode} #{event.value}}"
  when Ultraviolet::Key
    "uv.KeyPressEvent #{event.string}"
  when Ultraviolet::MultiEvent
    "uv.MultiEvent #{Ultraviolet.multi_event_string(event)}"
  else
    name = event.class.name.split("::").last
    value = event.responds_to?(:string) ? event.string : event
    "uv.#{name} #{value}"
  end
end

screen.write_string(Ansi.set_window_title("Hello, World!"))

style = Ultraviolet::Style.new(
  bg: Ultraviolet::AnsiColor.basic(1),
  fg: Ultraviolet::AnsiColor.basic(0),
)

# display paints the first row with style and the greeting on top of it, leaving
# the rest of the screen buffer alone so prepended lines land above the frame.
display = -> do
  bg = Ultraviolet::EMPTY_CELL
  bg.style = style
  screen.fill_area(bg, Ultraviolet.rect(0, 0, screen.bounds.dx, 1))
  "Hello, World!".each_char_with_index do |char, index|
    screen.set_cell(index, 0, Ultraviolet::Cell.new(char.to_s, 1, style))
  end
  screen.display
end

begin
  # Initial render.
  display.call

  loop do
    case event = screen.events.receive
    when Ultraviolet::WindowSizeEvent
      screen.resize(event.width, 1)
      display.call
    when Ultraviolet::Key
      break if event.match_string("q", "ctrl+c")

      style.bg = Ultraviolet::AnsiColor.basic(rand(16))
    end

    # Log the event above the frame, the way Go's InsertAbove does.
    screen.insert_above(event_text(event))

    style.bg = Ultraviolet::AnsiColor.basic(rand(8))
    display.call
  end
ensure
  screen.shutdown(1.second)
end
