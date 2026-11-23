require "../src/ultraviolet"

# Port of vendor/ultraviolet/examples/helloworld.
#
# Centers a two-line view, toggles the alternate screen with space, suspends
# with ctrl+z, and exits on any other key.
term = Ultraviolet::Terminal.default_terminal
screen = term

# Go calls scr.EnterAltScreen() before Start so the alternate screen is active
# for the first frame.
screen.enter_alt_screen
alt_screen = true

begin
  term.start
rescue ex
  STDERR.puts "failed to start program: #{ex.message}"
  exit 1
end

view = [
  "Hello, World!",
  "Press any key to exit.",
]
view_widths = view.map { |line| Ansi.string_width(line) }

display = -> do
  Ultraviolet::Screen.clear(screen)
  bounds = screen.bounds
  context = Ultraviolet::Screen::Context.new(screen)
  view.each_with_index do |line, index|
    x = (bounds.dx - view_widths[index]) // 2
    y = (bounds.dy - view.size) // 2 + index
    context.draw_string(line, x, y)
  end
  screen.display
end

physical_width = 0
physical_height = 0

begin
  display.call

  loop do
    case event = term.events.receive
    when Ultraviolet::WindowSizeEvent
      physical_width = event.width
      physical_height = event.height
      screen.resize(physical_width, alt_screen ? physical_height : view.size)
      display.call
    when Ultraviolet::Key
      if event.match_string("space")
        if alt_screen
          screen.exit_alt_screen
          alt_screen = false
          screen.resize(physical_width, view.size)
        else
          screen.enter_alt_screen
          alt_screen = true
          screen.resize(physical_width, physical_height)
        end
        display.call
      elsif event.match_string("ctrl+z")
        term.stop
        Ultraviolet.suspend
        term.start
      else
        break
      end
    end
  end
ensure
  # Go's last render runs on the way out, after Stop.
  begin
    display.call
  rescue
  end
  term.stop
end
