require "../src/ultraviolet"

# Port of vendor/ultraviolet/examples/altscreen.
#
# Prints which screen mode is active plus a help line: space toggles between
# inline and alternate screen mode, and any other key exits.
term = Ultraviolet::Terminal.default_terminal
screen = term

begin
  term.start
rescue ex
  STDERR.puts "failed to start program: #{ex.message}"
  exit 1
end

# Go's TerminalScreen starts in inline mode; this port's Terminal starts in the
# alternate screen, so leave it inline before the first frame.
screen.exit_alt_screen

help = "Press space to toggle screen mode or any other key to exit."
alt_screen = false

# Go starts with a zero-sized screen, so its first display paints nothing and
# the first painted frame is the one the initial WindowSizeEvent triggers. Size
# the frame here so the startup paint lands on that frame.
physical_width, physical_height = term.fetch_size

display = -> do
  screen.resize(physical_width, alt_screen ? physical_height : 2)

  line = alt_screen ? "This is using alternate screen mode." : "This is using inline mode."

  Ultraviolet::Screen.clear(screen)
  Ultraviolet::Screen::Context.new(screen).print("#{line}\n#{help}")
  screen.display
end

begin
  # The first frame is painted by the initial WindowSizeEvent, as in Go.
  loop do
    case event = term.events.receive
    when Ultraviolet::WindowSizeEvent
      physical_width = event.width
      physical_height = event.height
      display.call
    when Ultraviolet::KeyPressEvent
      if event.match_string("space")
        if alt_screen
          screen.exit_alt_screen
          screen.resize(physical_width, 2)
        else
          screen.enter_alt_screen
          screen.resize(physical_width, physical_height)
        end
        alt_screen = !alt_screen
        display.call
      else
        break
      end
    end
  end
ensure
  # Go defers t.Stop().
  term.stop
end
