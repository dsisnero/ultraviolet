require "../src/ultraviolet"
require "stumpy_png"
require "base64"

# Port of vendor/ultraviolet/examples/advanced/rgbimage/main.go
#
# Draws a centered text block plus a 10x5-cell iTerm2 inline image of a random
# indexed color at a cell offset moved by the arrow keys.
#
# Divergences from the Go example:
#
# - Go calls `t.Screen()` for a TerminalScreen. Here `Terminal` includes
#   `Screen`, so the terminal is used as the screen directly (same as
#   examples/tv.cr). Go's `scr.Render()`/`scr.Flush()` map to
#   `Terminal#display`.
# - Go writes the encoded PNG into a temp directory before base64-ing it. That
#   file is a debugging artifact only (an inline iTerm2 image carries its bytes
#   in the escape sequence), so it is not written here.
# - Go encodes a 0x0 image until the terminal reports a pixel size. `png.Encode`
#   rejects that size and returns an error that the example ignores, leaving an
#   empty base64 payload, so the first frame carries `inline=1` with no image
#   data. StumpyPNG cannot write a 0x0 canvas either, so the same empty payload
#   is returned explicitly.

IMG_W = 10
IMG_H =  5

term = Ultraviolet::Terminal.default_terminal

begin
  term.start
rescue ex
  STDERR.puts "error starting terminal: #{ex.message}"
  exit 1
end

term.enter_alt_screen

keypress = ""
cell_width = 0
cell_height = 0
img_x_offset = 0
img_y_offset = 0

# Builds a solid-color RGBA image stretched to `w` x `h` cells and returns the
# base64-encoded PNG, matching the Go `createEncodedImage` helper.
create_encoded_image = ->(w : Int32, h : Int32, color : Ultraviolet::Color) : String do
  pixel_w = w * cell_width
  pixel_h = h * cell_height
  if pixel_w <= 0 || pixel_h <= 0
    # Go's png.Encode fails on a 0x0 image and the example ignores the error, so
    # the payload is empty until a PixelSizeEvent gives the cell size.
    ""
  else
    rgba = StumpyPNG::RGBA.new(
      color.r.to_u16 * 257_u16,
      color.g.to_u16 * 257_u16,
      color.b.to_u16 * 257_u16,
      0xffff_u16,
    )
    canvas = StumpyPNG::Canvas.new(pixel_w, pixel_h, rgba)
    io = IO::Memory.new
    # Go's PNG encoder writes 8-bit channels, so keep the same depth.
    StumpyPNG.write(canvas, io, bit_depth: 8)
    Base64.strict_encode(io.to_slice)
  end
end

display = -> do
  term.clear
  text = "Press any key to see its value. Press 'ctrl+c' to quit.\n\nLast key pressed: #{keypress}"
  ss = Ultraviolet::StyledString.new(text)
  bounds = term.bounds
  if bounds.empty?
    return
  end

  center = Ultraviolet.rect(
    (bounds.max.x - ss.unicode_width) // 2,
    (bounds.max.y - ss.height) // 2,
    ss.unicode_width,
    ss.height,
  )
  ss.draw(term, center)

  # Go renders and flushes here before placing the image cells.
  term.display

  color = Ultraviolet::AnsiColor.indexed(Random.rand(256))
  encoded_png = create_encoded_image.call(IMG_W, IMG_H, color)
  center_img = Ultraviolet.rect(img_x_offset, img_y_offset, IMG_W, IMG_H)

  y = center_img.min.y
  while y < center_img.max.y
    content = if y == center_img.min.y
                # The escape sequence is stored in one wide cell: the first row
                # emits the image and repositions the cursor, the remaining
                # rows only advance past the image.
                Ansi.iterm2(Ansi::Iterm2::File.new(
                  name: "img.png",
                  width: Ansi::Iterm2.cells(IMG_W),
                  height: Ansi::Iterm2.cells(IMG_H),
                  content: encoded_png.to_slice,
                  inline: true,
                  ignore_aspect_ratio: true,
                  do_not_move_cursor: false,
                ).to_s) + Ansi.cursor_position(center_img.min.x + IMG_W + 1, center_img.min.y + 1)
              else
                Ansi.cursor_forward(IMG_W)
              end

    term.set_cell(center_img.min.x, y, Ultraviolet::Cell.new(content, IMG_W))
    y += 1
  end

  term.display
end

begin
  display.call

  loop do
    case event = term.events.receive
    when Ultraviolet::PixelSizeEvent
      width = term.bounds.dx
      height = term.bounds.dy
      cell_width = width > 0 ? event.width // width : 0
      cell_height = height > 0 ? event.height // height : 0
    when Ultraviolet::WindowSizeEvent
      term.resize(event.width, event.height)
    when Ultraviolet::Key
      case event.string
      when "ctrl+c"
        break
      when "up"    then img_y_offset -= 1
      when "down"  then img_y_offset += 1
      when "left"  then img_x_offset -= 1
      when "right" then img_x_offset += 1
      end
      keypress = event.string
    end

    display.call
  end
ensure
  # Go clears, renders, resets the screen, then flushes; `stop` restores the
  # terminal (leaving the alternate screen) once the cleared frame is painted.
  term.clear
  term.display
  term.stop
end
