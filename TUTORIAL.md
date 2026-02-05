# Hello World (Crystal)

This tutorial shows how to build a minimal Ultraviolet program in Crystal. It
creates a terminal, renders “Hello, World!”, and exits on <kbd>q</kbd> or
<kbd>ctrl+c</kbd>.

## Create A Terminal

```crystal
require "ultraviolet"

env = ENV.map { |key, value| "#{key}=#{value}" }
term = Ultraviolet::Terminal.new(STDIN, STDOUT, env)
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

term.shutdown(1.second)
```
