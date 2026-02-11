require "../src/ultraviolet"

term = Ultraviolet::Terminal.default_terminal
term.start
term.exit_alt_screen

counter = 5
last_tick = Time.monotonic
running = true

view = ->(value : Int32) { "Panicking after #{value} seconds...\nPress q or ctrl+c to exit." }

begin
  while running
    if Time.monotonic - last_tick >= 1.second
      counter -= 1
      last_tick = Time.monotonic
      raise "Time's up!" if counter < 0
    end

    select
    when ev = term.events.receive
      if ev.is_a?(Ultraviolet::KeyPressEvent) && ev.match_string("q", "ctrl+c")
        running = false
      end
    when timeout(16.milliseconds)
    end

    Ultraviolet::StyledString.new(view.call(counter)).draw(term, term.bounds)
    term.display
  end
rescue ex
  STDERR.puts "\nRecovered from panic: #{ex.message}"
ensure
  term.shutdown(1.second)
end
