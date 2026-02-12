require "../src/ultraviolet"
require "mosaic"
require "stumpy_core"
require "stumpy_png"
require "base64"
require "colorful"

module Ultraviolet
  # Helper to convert Ansi::Color to Colorful::Color
  def self.colorful_color(color : Ansi::Color) : Colorful::Color
    Colorful::Color.rgb(color.r, color.g, color.b)
  end
end

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

enum ImageEncoding
  Blocks
  Sixel
  Iterm
  Kitty
  Unknown
end

class ImageExample
  @term : Ultraviolet::Terminal
  @canvas : StumpyCore::Canvas
  @encoding : ImageEncoding
  @desired_encoding : ImageEncoding
  @win_size : Ultraviolet::WindowSizeEvent
  @pix_size : Ultraviolet::PixelSizeEvent
  @transmit_kitty : Bool = false
  @img_cell_w : Int32 = 0
  @img_cell_h : Int32 = 0
  @img_offset_x : Int32 = 0
  @img_offset_y : Int32 = 0
  @charm_img_b64 : String? = nil

  def initialize(width = 120, height = 80)
    @term = Ultraviolet::Terminal.default_terminal
    @canvas = gradient_canvas(width, height)
    @encoding = ImageEncoding::Blocks
    @desired_encoding = ImageEncoding::Unknown
    @win_size = Ultraviolet::WindowSizeEvent.new(0, 0)
    @pix_size = Ultraviolet::PixelSizeEvent.new(0, 0)
    parse_args
  end

  def parse_args
    ARGV.each do |arg|
      if arg.starts_with?("--encoding=")
        enc = arg.split("=", 2)[1]
        @desired_encoding = case enc.downcase
                            when "blocks" then ImageEncoding::Blocks
                            when "sixel" then ImageEncoding::Sixel
                            when "iterm", "iterm2" then ImageEncoding::Iterm
                            when "kitty" then ImageEncoding::Kitty
                            else ImageEncoding::Unknown
                            end
      end
    end
  end

  def upgrade_encoding(enc : ImageEncoding)
    return if @desired_encoding != ImageEncoding::Unknown
    if enc > @encoding
      @encoding = enc
    end
  end

  def img_cell_size : {Int32, Int32}
    if @win_size.width == 0 || @win_size.height == 0 || @pix_size.width == 0 || @pix_size.height == 0
      return {0, 0}
    end
    cell_w = @pix_size.width // @win_size.width
    cell_h = @pix_size.height // @win_size.height
    img_w = @canvas.width
    img_h = @canvas.height
    {img_w // cell_w, img_h // cell_h}
  end

  def display_img
    width = @win_size.width
    height = @win_size.height
    img_w, img_h = img_cell_size
    img_offset_x = width // 2 - img_w // 2
    img_offset_y = height // 2 - img_h // 2
    @img_offset_x = img_offset_x
    @img_offset_y = img_offset_y
    @img_cell_w = img_w
    @img_cell_h = img_h

    image_area = Ultraviolet.rect(img_offset_x, img_offset_y, img_w, img_h)
    if !image_area.in?(@win_size.bounds)
      image_area = image_area.intersect(@win_size.bounds)
      # TODO: Crop image
    end

    @term.clear
    fill_style = Ultraviolet::Style.new(fg: Ultraviolet::Color.new(100_u8, 100_u8, 100_u8))
    fill_cell = Ultraviolet::Cell.new("/", 1, fill_style)
    @term.fill_area(fill_cell, @term.bounds)

    case @encoding
    when ImageEncoding::Blocks
      blocks = Mosaic::Renderer.new.width(img_w).height(img_h).scale(2)
      ss = Ultraviolet::StyledString.new(blocks.render(@canvas))
      ss.draw(@term, image_area)
    when ImageEncoding::Iterm, ImageEncoding::Sixel
      # Clear area where image will be drawn
      @term.fill_area(Ultraviolet::Cell.empty, image_area)
    when ImageEncoding::Kitty
      # Kitty graphics transmission
      unless @transmit_kitty
        transmit_kitty_image(image_area)
        @transmit_kitty = true
        @term.flush
      end
      draw_kitty_placeholders(image_area)
    end

    @term.display

    case @encoding
    when ImageEncoding::Sixel
      draw_sixel(image_area)
    when ImageEncoding::Iterm
      draw_iterm(image_area)
    end

    @term.flush if @term.buffered > 0
  end

  def transmit_kitty_image(area : Ultraviolet::Rectangle)
    # Convert canvas to Ansi::Image (RGBA)
    image = Ansi::RGBAImage.new(@canvas.width, @canvas.height)
    @canvas.width.times do |x|
      @canvas.height.times do |y|
        rgba = @canvas[x, y]
        color = Ansi::Color.new(rgba.r.to_u8, rgba.g.to_u8, rgba.b.to_u8, rgba.a.to_u8)
        image.set(x, y, color)
      end
    end

    options = Ansi::Kitty::Options.new
    options.id = 31
    options.action = Ansi::Kitty::TransmitAndPut
    options.transmission = Ansi::Kitty::Direct
    options.format = Ansi::Kitty::RGBA
    options.size = @canvas.width * @canvas.height * 4
    options.image_width = @canvas.width
    options.image_height = @canvas.height
    options.columns = area.dx
    options.rows = area.dy
    options.virtual_placement = true
    options.quite = 2

    io = IO::Memory.new
    Ansi::Kitty.encode_graphics(io, image, options)
    @term.write_string(io.to_s)
  end

  def draw_kitty_placeholders(area : Ultraviolet::Rectangle)
    id = 31
    r = (id >> 16) & 0xff
    g = (id >> 8) & 0xff
    b = id & 0xff
    extra = (id >> 24) & 0xff

    fg = if r == 0 && g == 0
           Ultraviolet::AnsiColor.indexed(b)
         else
           Ultraviolet::Color.new(r.to_u8, g.to_u8, b.to_u8)
         end

    area.dy.times do |y|
      content = [] of Char
      content << Ansi::Kitty::Placeholder
      content << Ansi::Kitty.diacritic(y)
      content << Ansi::Kitty.diacritic(0)
      if extra > 0
        content << Ansi::Kitty.diacritic(extra)
      end
      @term.set_cell(area.min.x, area.min.y + y,
        Ultraviolet::Cell.new(content.join, 1, Ultraviolet::Style.new(fg: fg)))
      (1...area.dx).each do |x|
        @term.set_cell(area.min.x + x, area.min.y + y,
          Ultraviolet::Cell.new(Ansi::Kitty::Placeholder.to_s, 1, Ultraviolet::Style.new(fg: fg)))
      end
    end
  end

  def draw_sixel(area : Ultraviolet::Rectangle)
    # Convert canvas to Ansi::Image
    image = Ansi::RGBAImage.new(@canvas.width, @canvas.height)
    @canvas.width.times do |x|
      @canvas.height.times do |y|
        rgba = @canvas[x, y]
        color = Ansi::Color.new(rgba.r.to_u8, rgba.g.to_u8, rgba.b.to_u8, rgba.a.to_u8)
        image.set(x, y, color)
      end
    end

    io = IO::Memory.new
    encoder = Ansi::Sixel::Encoder.new
    encoder.encode(io, image)
    sixel_data = io.to_s
    six = Ansi.sixel_graphics(0, 1, 0, sixel_data.to_slice)
    # Move cursor to image area
    if area.min.y > 0
      @term.move_to(area.min.x, area.min.y + 1)
    else
      @term.move_to(area.min.x, area.min.y)
    end
    @term.write_string(six)
    @term.write_string(Ansi.cursor_position(area.min.x + 1, area.min.y + 1))
  end

  def draw_iterm(area : Ultraviolet::Rectangle)
    # Encode canvas to JPEG? For simplicity, use PNG base64.
    # Since we don't have JPEG encoder, use PNG via stumpy_png
    png_io = IO::Memory.new
    png_canvas = StumpyPNG::Canvas.new(@canvas.width, @canvas.height)
    @canvas.width.times do |x|
      @canvas.height.times do |y|
        rgba = @canvas[x, y]
        png_canvas[x, y] = StumpyPNG::RGBA.new(rgba.r, rgba.g, rgba.b, rgba.a)
      end
    end
    StumpyPNG.write(png_canvas, png_io)
    b64 = Base64.strict_encode(png_io.to_slice)
    @charm_img_b64 = b64

    file = Ansi::Iterm2::File.new(
      name: "gradient.png",
      width: Ansi::Iterm2.cells(area.dx),
      height: Ansi::Iterm2.cells(area.dy),
      inline: true,
      content: b64.to_slice,
      ignore_aspect_ratio: true
    )
    data = Ansi.iterm2(file.to_s)

    cup = Ansi.cursor_position(area.min.x + 1, area.min.y + 1)
    @term.move_to(area.min.x, area.min.y)
    @term.write_string(data)
    @term.write_string(cup)
  end

  def query_capabilities
    @term.write_string(Ansi::RequestPrimaryDeviceAttributes)   # Query Sixel support
    @term.write_string(Ansi::RequestNameVersion)               # Query terminal version
    @term.write_string(Ansi.window_op(14, 0)) # Request window size
    # Query Kitty Graphics support using random id=31
    @term.write_string(Ansi.kitty_graphics("AAAA".to_slice, ["i=31", "s=1", "v=1", "a=q", "t=d", "f=24"]))
  end

  def run
    @term.start
    @term.enter_alt_screen
    @term.write_string(Ansi.set_mode(Ansi::ModeMouseButtonEvent, Ansi::ModeMouseExtSgr))

    size = @term.size
    width = size.width
    height = size.height
    @win_size = Ultraviolet::WindowSizeEvent.new(width, height)
    @term.resize(width, height)

    query_capabilities
    display_img

    loop do
      event = @term.events.receive
      case event
      when Ultraviolet::PixelSizeEvent
        @pix_size = event
        @img_cell_w, @img_cell_h = img_cell_size
        @img_offset_x = @win_size.width // 2 - @img_cell_w // 2
        @img_offset_y = @win_size.height // 2 - @img_cell_h // 2
        display_img
      when Ultraviolet::WindowSizeEvent
        @win_size = event
        @img_cell_w, @img_cell_h = img_cell_size
        @img_offset_x = @win_size.width // 2 - @img_cell_w // 2
        @img_offset_y = @win_size.height // 2 - @img_cell_h // 2
        @term.erase
        @term.resize(event.width, event.height)
        display_img
      when Ultraviolet::KeyPressEvent
        break if event.match_string("q", "ctrl+c")
        if event.match_string("up", "k")
          @img_offset_y -= 1
        elsif event.match_string("down", "j")
          @img_offset_y += 1
        elsif event.match_string("left", "h")
          @img_offset_x -= 1
        elsif event.match_string("right", "l")
          @img_offset_x += 1
        end
        display_img
      when Ultraviolet::MouseClickEvent
        @img_offset_x = event.x - (@img_cell_w // 2)
        @img_offset_y = event.y - (@img_cell_h // 2)
        display_img
      when Ultraviolet::PrimaryDeviceAttributesEvent
        if event.includes?(4)  # Sixel support
          upgrade_encoding(ImageEncoding::Sixel)
          display_img
        end
      when Ultraviolet::TerminalVersionEvent
        if event.name.includes?("iTerm") || event.name.includes?("WezTerm")
          upgrade_encoding(ImageEncoding::Iterm)
          display_img
        end
      when Ultraviolet::WindowOpEvent
        if event.op == 4 && event.args.size >= 2
          @pix_size.height = event.args[0]
          @pix_size.width = event.args[1]
        end
      when Ultraviolet::KittyGraphicsEvent
        # Skip WezTerm detection (doesn't support Kitty Unicode Graphics)
        term_prog = ENV["TERM_PROGRAM"]? || ""
        term_version = ENV["TERM_VERSION"]? || ""
        term_type = ENV["TERM"]? || ""
        if term_prog.includes?("WezTerm") || term_version.includes?("WezTerm") || term_type.includes?("wezterm")
          # skip
        else
          if event.options["i"]? == "31"
            upgrade_encoding(ImageEncoding::Kitty)
          end
        end
        display_img
      end
    end
  ensure
    @term.write_string(Ansi.reset_mode(Ansi::ModeMouseButtonEvent, Ansi::ModeMouseExtSgr))
    @term.shutdown(1.second)
  end
end

ImageExample.new.run