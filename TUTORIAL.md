# Hello World (Crystal)

This tutorial shows how to build a minimal Ultraviolet program in Crystal. It
creates a terminal, renders “Hello, World!”, and exits on <kbd>q</kbd> or
<kbd>ctrl+c</kbd>.

Note: `crystal run` can interfere with interactive TTY input on some systems.
If you don't see key events, build and run a binary with `crystal build`.

## Create A Terminal

```crystal
require "ultraviolet"

env = ENV.map { |key, value| "#{key}=#{value}" }
term = Ultraviolet::Terminal.new(STDIN, STDOUT, env)
stop = Channel(Nil).new(1)
Signal::INT.trap { stop.send(nil) }
Signal::TERM.trap { stop.send(nil) }
Signal::TRAP.trap { stop.send(nil) }
# Or simply:
# term = Ultraviolet::Terminal.default
```

Starting a terminal will:

- Enter raw mode (so key presses arrive as events).
- Initialize the renderer and buffers.
- Begin input/event loops.

```crystal
term.start
term.enter_alt_screen
```

## Render Content

Ultraviolet uses a screen buffer. Set cells and render the buffer to the
terminal with `display`.

```crystal
"Hello, World!".each_char_with_index do |char, idx|
  term.set_cell(idx, 0, Ultraviolet::Cell.new(char.to_s, 1))
end

term.display
```

## Handle Events

The terminal exposes a channel of events. You can resize your buffer on
`WindowSizeEvent` and exit on key presses.

```crystal
loop do
  event = term.events.receive
  case event
  when Ultraviolet::WindowSizeEvent
    term.resize(event.width, event.height)
    term.erase
  when Ultraviolet::Key
    break if event.match_string("q", "ctrl+c")
  end

  "Hello, World!".each_char_with_index do |char, idx|
    term.set_cell(idx, 0, Ultraviolet::Cell.new(char.to_s, 1))
  end
  term.display
end
```

## Shutdown Cleanly

```crystal
term.shutdown(1.second)
```

## Full Example

```crystal
require "ultraviolet"

env = ENV.map { |key, value| "#{key}=#{value}" }
term = Ultraviolet::Terminal.new(STDIN, STDOUT, env)
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
```
