# Hello World!

Building a terminal application with Ultraviolet. Based on the Go
[TUTORIAL.md](https://github.com/charmbracelet/ultraviolet/blob/main/TUTORIAL.md),
adapted for Crystal.

## Creating a Terminal

A `Terminal` manages the screen, input, and lifecycle of a terminal
application. Create one with standard I/O:

```crystal
require "ultraviolet"

term = Ultraviolet::Terminal.new(STDIN, STDOUT, ENV.map { |k, v| "#{k}=#{v}" })
```

The `Terminal` provides:
- Raw mode (`start` enters raw mode automatically)
- Event channel for keyboard, mouse, resize events
- Cell-based screen buffer for rendering content

## Configuration

Customize behavior with `Options`:

```crystal
opts = Ultraviolet::Options.new(
  buffer_size: 8192,
  event_timeout: 50.milliseconds,
  lookup_keys: true,
  use_terminfo_keys: false,
)
term = Ultraviolet::Terminal.new(Ultraviolet::Console.default, opts)
```

## Starting the Terminal

```crystal
term.start
term.enter_alt_screen
```

`start` puts the terminal in raw mode and begins the event loop.
`enter_alt_screen` switches to the alternate screen buffer so your
application doesn't scroll the terminal history.

Always restore before exit:

```crystal
ensure
  term.shutdown(1.second)
end
```

## Displaying Content

Write cells into the screen buffer, then render and flush:

```crystal
"Hello, World!".each_char_with_index do |char, idx|
  term.set_cell(idx, 0, Ultraviolet::Cell.new(char.to_s, 1))
end
term.display
```

`set_cell(x, y, cell)` writes a `Cell` at position `(x, y)`. Each cell has
a content string, a display width, and optional Style/Link.

`display` renders the buffer and flushes to the terminal. The renderer
computes a diff against the previous frame and emits only the ANSI
sequences needed to update changed cells.

## Handling Input

The event channel delivers keyboard, mouse, and window events:

```crystal
stop = Channel(Nil).new(1)
Signal::INT.trap { stop.send(nil) }
Signal::TERM.trap { stop.send(nil) }

loop do
  event = nil
  select
  when stop.receive
    break
  when ev = term.events.receive
    event = ev
  when timeout(16.milliseconds)
  end

  case event
  when Ultraviolet::WindowSizeEvent
    term.resize(event.width, event.height)
    term.erase
  when Ultraviolet::Key
    break if event.match_string("q", "ctrl+c")
  when Ultraviolet::MouseClickEvent
    # handle mouse click at (event.x, event.y)
  end

  # Redraw content
  "Hello, World!".each_char_with_index do |char, idx|
    term.set_cell(idx, 0, Ultraviolet::Cell.new(char.to_s, 1))
  end
  term.display
end
```

## Using Styled Strings

Render ANSI-escaped text with `StyledString`:

```crystal
styled = Ultraviolet::StyledString.new("\e[1;31mHello\e[m, World!")
styled.draw(term, term.bounds)
term.render
term.flush
```

`StyledString` parses SGR attributes (bold, colors, underline, etc.)
and hyperlinks (OSC 8), producing correctly styled cells on the buffer.

## Keyboard Enhancements

Enable Kitty keyboard protocol for key release events and modifier
disambiguation:

```crystal
enh = Ultraviolet::KeyboardEnhancements.new(
  disambiguate_escape_codes: true,
  report_event_types: true,
)
term.set_keyboard_enhancements(enh)
```

## Bracketed Paste

Detect pasted text as atomic operations:

```crystal
term.enable_bracketed_paste

# Events will include PasteStartEvent, PasteEvent, PasteEndEvent
# instead of individual Key events for each pasted character
```

## Mouse Support

```crystal
term.set_mouse_mode(Ultraviolet::MouseMode::Click)

# Now receives MouseClickEvent, MouseReleaseEvent, MouseMotionEvent, MouseWheelEvent
```

## Full Application

A complete interactive terminal app:

```crystal
require "ultraviolet"

term = Ultraviolet::Terminal.new(STDIN, STDOUT, ENV.map { |k, v| "#{k}=#{v}" })

stop = Channel(Nil).new(1)
Signal::INT.trap { stop.send(nil) }
Signal::TERM.trap { stop.send(nil) }

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
ensure
  term.shutdown(1.second)
end
```

See [examples/helloworld.cr](../examples/helloworld.cr) for a runnable version.

## Related

- [Parity Plan](../plans/parity.md) — Go-vs-Crystal feature tracking
- [Examples](../examples/) — altscreen, draw, layout, splits, image
- [Source code](../src/ultraviolet/) — full Crystal implementation
- [Upstream Go docs](https://pkg.go.dev/github.com/charmbracelet/ultraviolet)
