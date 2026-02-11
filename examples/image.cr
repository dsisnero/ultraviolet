require "../src/ultraviolet"
require "mosaic"
require "stumpy_core"

def gradient_canvas(width : Int32, height : Int32) : StumpyCore::Canvas
  canvas = StumpyCore::Canvas.new(width, height)
  (0...height).each do |y|
    (0...width).each do |x|
      r = ((x * 255) // Math.max(1, width - 1)).to_u8
      g = ((y * 255) // Math.max(1, height - 1)).to_u8
      b = (((x + y) * 255) // Math.max(1, width + height - 2)).to_u8
      canvas[x, y] = StumpyCore::RGBA.new(r, g, b, 255_u8)
    end
  end
  canvas
end

term = Ultraviolet::Terminal.default_terminal
term.start
term.enter_alt_screen

canvas = gradient_canvas(120, 80)
encoding = ARGV.find { |arg| arg.starts_with?("--encoding=") }.try { |arg| arg.split("=", 2)[1] } || "blocks"

render = -> do
  width = term.bounds.dx
  height = term.bounds.dy

  image_w = (width * 3) // 4
  image_h = (height * 3) // 4
  image_x = (width - image_w) // 2
  image_y = (height - image_h) // 2
  image_area = Ultraviolet.rect(image_x, image_y, image_w, image_h)

  term.clear
  term.fill_area(Ultraviolet::Cell.new("/", 1, Ultraviolet::Style.new(fg: Ultraviolet::Color.new(100_u8, 100_u8, 100_u8))), term.bounds)

  case encoding
  when "blocks"
    blocks = Mosaic::Renderer.new.width(image_w).height(image_h).scale(2)
    ss = Ultraviolet::StyledString.new(blocks.render(canvas))
    ss.draw(term, image_area)
  else
    fallback = Ultraviolet::StyledString.new("encoding=#{encoding} is not implemented in this Crystal example.\nUse --encoding=blocks.")
    fallback.draw(term, Ultraviolet.rect(0, 0, width, 3))
  end

  term.display
end

begin
  render.call
  loop do
    case ev = term.events.receive
    when Ultraviolet::WindowSizeEvent
      term.resize(ev.width, ev.height)
      term.erase
      render.call
    when Ultraviolet::KeyPressEvent
      break if ev.match_string("q", "ctrl+c")
      render.call if ev.match_string("r")
    end
  end
ensure
  term.shutdown(1.second)
end
