require "../src/ultraviolet"

# Port of vendor/ultraviolet/examples/mouse/main.go
#
# Shows the last mouse button and its cell position on the first line, and
# prints every mouse event above the frame. Mouse reporting uses motion mode
# with SGR pixel coordinates; pixel positions are converted to cells with the
# terminal's window size.
#
# Differences from the Go example:
#   - Go never enters the alternate screen here, so neither does this port: the
#     frame is drawn inline.
term = Ultraviolet::Terminal.default_terminal
ws = term.get_winsize
term.start

term.set_mouse_mode(Ultraviolet::MouseMode::Motion)
term.set_mouse_encoding(Ultraviolet::MouseEncoding::SGRPixel)

last_button = Ultraviolet::MouseButton::None
last_x = 0
last_y = 0

# Width of the filled label row. It stays zero until the first WindowSizeEvent,
# so the first frame only paints the label cells.
width = 0

style = Ultraviolet::Style.new(bg: Ultraviolet::AnsiColor.basic(4), fg: Ultraviolet::AnsiColor.basic(0))

display = -> do
  label = " Button: #{last_button.string.ljust(12)} Position: (#{last_x}, #{last_y})"
  term.fill_area(Ultraviolet::Cell.new(" ", 1, style), Ultraviolet.rect(0, 0, width, 1))
  label.each_char_with_index do |char, x|
    term.set_cell(x, 0, Ultraviolet::Cell.new(char.to_s, 1, style))
  end
  term.display
end

# Initial render, before the event loop.
display.call

begin
  loop do
    case event = term.events.receive
    when Ultraviolet::WindowSizeEvent
      width = event.width
      ws = Ultraviolet::Winsize.new(event.height.to_u16, event.width.to_u16, ws.xpixel, ws.ypixel)
      term.resize(width, 1)

      # Query the pixel dimensions of the window in case this platform does not
      # report them through the winsize ioctl. Go calls `ansi.WindowOp(4)`,
      # which is XTWINOPS 4 -> `CSI 4 t`; `Ansi.window_op` cannot be called with
      # a lone op (its typed splat needs a second argument), so write it out.
      term.write_string("\e[4t")

      display.call
    when Ultraviolet::PixelSizeEvent
      ws = Ultraviolet::Winsize.new(ws.row, ws.col, event.width.to_u16, event.height.to_u16)
    when Ultraviolet::Key
      # Go matches only "q" and "ctrl+c" here.
      break if event.match_string("q", "ctrl+c")
    when Ultraviolet::MouseClickEvent, Ultraviolet::MouseReleaseEvent,
         Ultraviolet::MouseWheelEvent, Ultraviolet::MouseMotionEvent
      mouse = Ultraviolet.mouse_pixel_to_cell(event.mouse, ws)
      last_x = mouse.x
      last_y = mouse.y
      last_button = mouse.button unless mouse.button == Ultraviolet::MouseButton::None
      term.prepend_string("#{event.string.ljust(20)} (#{mouse.x}, #{mouse.y}) #{mouse.button.string}\n")
      display.call
    end
  end
ensure
  # Go's Terminal.Stop restores the screen state, which now includes the mouse
  # mode and encoding this example set, so nothing is reset by hand.
  term.stop
end
