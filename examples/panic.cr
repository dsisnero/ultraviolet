require "../src/ultraviolet"

# Port of vendor/ultraviolet/examples/panic.
#
# Counts down from five and panics when the count runs out. A tick arrives once
# a second and redraws the view; q or ctrl+c exits before that.
term = Ultraviolet::Terminal.default_terminal

begin
  term.start
rescue ex
  STDERR.puts "failed to start terminal: #{ex.message}"
  exit 1
end

# Go's TerminalScreen starts in inline mode; this port's Terminal starts in the
# alternate screen, so leave it inline before the first frame.
term.exit_alt_screen

counter = 5

# Go runs a ticker goroutine that sends a tickEvent through the terminal every
# second; a fiber and a channel do the same here.
ticks = Channel(Nil).new(1)
spawn do
  loop do
    sleep 1.second
    ticks.send(nil)
  end
end

# Go keeps its "Panicing" typo; the text is part of the port.
view = ->(value : Int32) { "Panicing after #{value} seconds...\nPress 'q' or 'Ctrl+C' to exit." }

display = ->(text : String) do
  Ultraviolet::Screen.clear(term)
  Ultraviolet::StyledString.new(text).draw(term, term.bounds)
  term.display
end

running = true

begin
  # Go paints its first frame when Terminal.Start sends the initial
  # WindowSizeEvent. This port's start already knows the terminal size and sends
  # no event, so show that frame here, at the inline height the handler uses.
  physical_width, _ = term.fetch_size
  term.resize(physical_width, 2)
  display.call(view.call(counter))

  while running
    select
    when ticks.receive
      counter -= 1
      raise "Time's up!\n" if counter < 0
    when event = term.events.receive
      case event
      when Ultraviolet::WindowSizeEvent
        term.resize(event.width, 2)
      when Ultraviolet::KeyPressEvent
        running = false if event.match_string("q", "ctrl+c")
      end
    end

    break unless running

    # Go redraws after every event, including the ones it ignores.
    display.call(view.call(counter))
  end

  display.call(view.call(counter) + "\n")
rescue ex
  # Go's deferred recover stops the terminal, then reports the panic.
  term.stop
  STDERR.puts "\r\nrecovered from panic: #{ex.message}"
  ex.backtrace.each { |line| STDERR.puts line }
ensure
  term.stop
end
