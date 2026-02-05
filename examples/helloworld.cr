require "../src/ultraviolet"

# Note: `crystal run` can interfere with interactive TTY input on some systems.
# If key events don't arrive, build and run a binary with `crystal build`.

env = ENV.map { |key, value| "#{key}=#{value}" }
term = Ultraviolet::Terminal.new(STDIN, STDOUT, env)

stop = Channel(Nil).new(1)
Signal::INT.trap { stop.send(nil) }
Signal::TERM.trap { stop.send(nil) }
Signal::TRAP.trap { stop.send(nil) }

term.start
term.enter_alt_screen

begin
  loop do
    event = nil
    select
    when stop.receive
      break
    when ev = term.events.receive
      event = ev
    when timeout(16.milliseconds)
    end

    if event
      if ENV["UV_DEBUG_EVENTS"]?
        STDERR.puts("event=#{event.class} #{event}")
        if event.is_a?(Ultraviolet::Key)
          key = event.as(Ultraviolet::Key)
          STDERR.puts("  key: code=#{key.code} text=#{key.text.inspect} mod=#{key.mod}")
        end
      end
      case event
      when Ultraviolet::WindowSizeEvent
        term.resize(event.width, event.height)
        term.erase
      when Ultraviolet::Key
        is_q = event.text == "q" || event.code == 'q'.ord
        is_ctrl_c = (event.mod & Ultraviolet::ModCtrl) != 0 && (event.code == 'c'.ord || event.text == "c")
        break if is_q || is_ctrl_c || event.match_string("q", "ctrl+c")
      end
    end

    "Hello, World!".each_char_with_index do |char, idx|
      term.set_cell(idx, 0, Ultraviolet::Cell.new(char.to_s, 1))
    end
    term.display
  end
ensure
  begin
    term.shutdown(1.second)
  rescue
  end
end
