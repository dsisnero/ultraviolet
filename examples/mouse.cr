require "../src/ultraviolet"

term = Ultraviolet::Terminal.default_terminal
ws = term.get_winsize
term.start
term.enter_alt_screen

mouse_mode = String.build { |io| Ultraviolet.encode_mouse_mode(io, Ultraviolet::MouseMode::Motion) }
mouse_encoding = String.build { |io| Ultraviolet.encode_mouse_encoding(io, Ultraviolet::MouseEncoding::SGRPixel) }
term.write_string(mouse_mode + mouse_encoding)

last_button = Ultraviolet::MouseButton::None
last_x = 0
last_y = 0

style = Ultraviolet::Style.new(bg: Ultraviolet::AnsiColor.basic(4), fg: Ultraviolet::AnsiColor.basic(0))

display = -> do
  label = " Button: #{last_button.to_s.ljust(12)} Position: (#{last_x}, #{last_y})"
  term.fill_area(Ultraviolet::Cell.new(" ", 1, style), Ultraviolet.rect(0, 0, term.width, 1))
  label.each_char_with_index do |char, x|
    term.set_cell(x, 0, Ultraviolet::Cell.new(char.to_s, 1, style))
  end
  term.display
end

display.call

begin
  loop do
    case event = term.events.receive
    when Ultraviolet::WindowSizeEvent
      term.resize(event.width, 1)
      ws = Ultraviolet::Winsize.new(event.height.to_u16, event.width.to_u16, ws.xpixel, ws.ypixel)

      # A terminal does not always report pixel dimensions through the winsize
      # ioctl, and `mouse_pixel_to_cell` needs them: without Xpixel/Ypixel it
      # returns (0, 0) for every event, so the position never moves.
      #
      # XTWINOPS 14 asks for the text area size in pixels; the reply
      # (`CSI 4 ; height ; width t`) decodes to a PixelSizeEvent on the next
      # branch. The Go example sends `ansi.WindowOp(4)`, which xterm reads as a
      # *resize* request and answers with nothing, so this is deliberately one
      # number off upstream.
      term.write_string("\e[14t")

      display.call
    when Ultraviolet::PixelSizeEvent
      ws = Ultraviolet::Winsize.new(ws.row, ws.col, event.width.to_u16, event.height.to_u16)
    when Ultraviolet::Key
      break if event.match_string("q", "ctrl+c", "esc")
    when Ultraviolet::MouseClickEvent, Ultraviolet::MouseReleaseEvent,
         Ultraviolet::MouseWheelEvent, Ultraviolet::MouseMotionEvent
      mouse = Ultraviolet.mouse_pixel_to_cell(event.mouse, ws)
      last_x = mouse.x
      last_y = mouse.y
      last_button = mouse.button unless mouse.button == Ultraviolet::MouseButton::None
      term.prepend_string("#{event.string} (#{mouse.x}, #{mouse.y}) #{mouse.button}\n")
      display.call
    end
  end
ensure
  term.write_string(Ansi::ResetModeMouseExtSgrPixel + Ansi::ResetModeMouseButtonEvent)
  term.stop
end
