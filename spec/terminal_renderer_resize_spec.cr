require "./spec_helper"

module RendererResizeSpecHelper
  def self.renderer(output : IO, env : Array(String) = ["TERM=xterm-256color"])
    Ultraviolet::TerminalRenderer.new(output, env)
  end

  def self.set_mark(buffer : Ultraviolet::RenderBuffer, x : Int32, y : Int32, content : String, width : Int32 = 1)
    buffer.set_cell(x, y, Ultraviolet::Cell.new(content, width))
  end

  def self.fill_row(buffer : Ultraviolet::RenderBuffer, y : Int32, width : Int32, content : String = "a")
    (0...width).each { |x| set_mark(buffer, x, y, content) }
  end
end

describe "TerminalRenderer resize and damage parity" do
  it "keeps the inline cursor model across a no-op resize" do
    output = IO::Memory.new
    renderer = RendererResizeSpecHelper.renderer(output)
    renderer.relative_cursor = true
    renderer.resize(80, 24)

    cellbuf = Ultraviolet::RenderBuffer.new(80, 3)
    3.times { |y| RendererResizeSpecHelper.set_mark(cellbuf, 0, y, "a") }
    renderer.render(cellbuf)
    renderer.flush
    output.clear

    renderer.resize(80, 24)
    RendererResizeSpecHelper.set_mark(cellbuf, 0, 0, "b")
    renderer.render(cellbuf)
    renderer.flush

    output.to_s.should eq("\r\e[2Ab")
  end

  it "clears partially when an inline frame shrinks" do
    output = IO::Memory.new
    renderer = RendererResizeSpecHelper.renderer(output)
    renderer.relative_cursor = true
    renderer.resize(80, 24)

    cellbuf = Ultraviolet::RenderBuffer.new(80, 3)
    3.times { |y| RendererResizeSpecHelper.set_mark(cellbuf, 0, y, "a") }
    renderer.render(cellbuf)
    renderer.flush
    output.clear

    cellbuf.resize(80, 2)
    renderer.resize(80, 24)
    RendererResizeSpecHelper.set_mark(cellbuf, 0, 1, "b")
    renderer.render(cellbuf)
    renderer.flush

    output.to_s.should eq("\r\e[J\eMb\r")
  end

  it "erases rows an inline frame gives up across a width change" do
    output = IO::Memory.new
    renderer = RendererResizeSpecHelper.renderer(output)
    renderer.relative_cursor = true
    renderer.resize(6, 10)

    cellbuf = Ultraviolet::RenderBuffer.new(6, 4)
    RendererResizeSpecHelper.set_mark(cellbuf, 0, 2, "a")
    renderer.render(cellbuf)
    renderer.flush
    output.clear

    cellbuf.resize(23, 2)
    renderer.resize(23, 10)
    RendererResizeSpecHelper.set_mark(cellbuf, 0, 0, "b")
    renderer.render(cellbuf)
    renderer.flush

    output.to_s.should contain(Ansi::EraseScreenBelow)
  end

  it "leaves surviving inline rows alone when shrinking" do
    output = IO::Memory.new
    renderer = RendererResizeSpecHelper.renderer(output)
    renderer.relative_cursor = true
    renderer.resize(6, 10)

    cellbuf = Ultraviolet::RenderBuffer.new(6, 8)
    RendererResizeSpecHelper.set_mark(cellbuf, 0, 1, "a")
    renderer.render(cellbuf)
    renderer.flush
    output.clear

    cellbuf.resize(6, 2)
    renderer.render(cellbuf)
    renderer.flush

    output.to_s.should contain(Ansi::EraseScreenBelow)
    output.to_s.should_not contain("a")
  end

  it "keeps a collapsing inline frame below its origin" do
    output = IO::Memory.new
    renderer = RendererResizeSpecHelper.renderer(output)
    renderer.relative_cursor = true
    renderer.resize(10, 20)

    cellbuf = Ultraviolet::RenderBuffer.new(10, 4)
    RendererResizeSpecHelper.set_mark(cellbuf, 0, 0, "a")
    renderer.render(cellbuf)
    renderer.flush
    output.clear

    cellbuf.resize(10, 0)
    renderer.render(cellbuf)
    renderer.flush

    output.to_s.should_not contain("\e[1A")
    renderer.position[1].should be >= 0
  end

  it "erases an inline shrink from the top on a full repaint" do
    output = IO::Memory.new
    renderer = RendererResizeSpecHelper.renderer(output)
    renderer.relative_cursor = true
    renderer.resize(80, 24)

    cellbuf = Ultraviolet::RenderBuffer.new(80, 3)
    3.times { |y| RendererResizeSpecHelper.set_mark(cellbuf, 0, y, "a") }
    renderer.render(cellbuf)
    renderer.flush
    output.clear

    renderer.erase
    cellbuf.touched = [] of Ultraviolet::LineData?
    cellbuf.resize(80, 1)
    cellbuf.clear
    RendererResizeSpecHelper.set_mark(cellbuf, 0, 0, "b")
    renderer.render(cellbuf)
    renderer.flush

    output.to_s.should eq("\r\e[2A\e[Jb\r")
  end

  it "paints rows added by a fullscreen grow" do
    output = IO::Memory.new
    renderer = RendererResizeSpecHelper.renderer(output)
    renderer.fullscreen = true
    renderer.resize(10, 3)

    cellbuf = Ultraviolet::RenderBuffer.new(10, 3)
    RendererResizeSpecHelper.set_mark(cellbuf, 0, 0, "A")
    renderer.render(cellbuf)
    renderer.flush
    output.clear

    cellbuf.resize(10, 6)
    renderer.resize(10, 6)
    RendererResizeSpecHelper.set_mark(cellbuf, 0, 5, "Z")
    renderer.render(cellbuf)
    renderer.flush

    output.to_s.should eq("\e[H\e[2JA\r\e[6dZ")
  end

  it "repaints a fullscreen shrink that grew back before rendering" do
    output = IO::Memory.new
    renderer = RendererResizeSpecHelper.renderer(output)
    renderer.fullscreen = true
    renderer.resize(10, 4)

    cellbuf = Ultraviolet::RenderBuffer.new(10, 4)
    RendererResizeSpecHelper.set_mark(cellbuf, 0, 2, "a")
    renderer.render(cellbuf)
    renderer.flush
    output.clear

    renderer.resize(10, 2)
    renderer.resize(10, 4)
    renderer.render(cellbuf)
    renderer.flush

    output.to_s.should contain(Ansi::EraseEntireScreen)
  end

  it "repaints a fullscreen narrowing that grew back before rendering" do
    output = IO::Memory.new
    renderer = RendererResizeSpecHelper.renderer(output)
    renderer.fullscreen = true
    renderer.resize(20, 2)

    cellbuf = Ultraviolet::RenderBuffer.new(20, 2)
    RendererResizeSpecHelper.fill_row(cellbuf, 0, 20)
    renderer.render(cellbuf)
    renderer.flush
    output.clear

    renderer.resize(8, 2)
    renderer.resize(20, 2)
    renderer.render(cellbuf)
    renderer.flush

    output.to_s.should contain(Ansi::EraseEntireScreen)
  end

  it "latches only real resize changes" do
    output = IO::Memory.new
    renderer = RendererResizeSpecHelper.renderer(output)
    renderer.fullscreen = true
    renderer.resize(20, 8)

    screen = Ultraviolet::ScreenBuffer.new(20, 6)
    Ultraviolet::StyledString.new("hello").draw(screen, Ultraviolet.rect(0, 0, 20, 1))
    renderer.render(screen)
    renderer.flush

    3.times do
      output.clear
      renderer.resize(20, 8)
      renderer.render(screen)
      renderer.flush
      output.to_s.should_not contain(Ansi::EraseEntireScreen)
    end

    output.clear
    renderer.resize(20, 4)
    renderer.resize(20, 8)
    renderer.render(screen)
    renderer.flush
    output.to_s.should contain(Ansi::EraseEntireScreen)
  end

  it "paints drift-prone rows with autowrap off" do
    render = ->(content : String, width : Int32, y : Int32) do
      output = IO::Memory.new
      renderer = RendererResizeSpecHelper.renderer(output)
      renderer.fullscreen = true
      renderer.resize(width, 2)

      screen = Ultraviolet::ScreenBuffer.new(width, 2)
      Ultraviolet::StyledString.new(content).draw(screen, Ultraviolet.rect(0, y, width, 1))
      renderer.render(screen)
      renderer.flush
      output.to_s
    end

    [0, 1].each do |y|
      wide = render.call("世界", 6, y)
      wide.should contain(Ansi::ResetAutoWrapMode)
      wide.should contain(Ansi::SetAutoWrapMode)
    end

    narrow = render.call("abc", 6, 1)
    narrow.should_not contain(Ansi::ResetAutoWrapMode)
  end

  it "keeps autowrap on for a cluster at the margin" do
    paint = ->(content : String, y : Int32) do
      output = IO::Memory.new
      renderer = RendererResizeSpecHelper.renderer(output)
      renderer.fullscreen = true
      renderer.resize(6, 2)

      screen = Ultraviolet::ScreenBuffer.new(6, 2)
      Ultraviolet::StyledString.new(content).draw(screen, Ultraviolet.rect(0, y, 6, 1))
      renderer.render(screen)
      renderer.flush
      output.to_s
    end

    cluster = "e\u0301"
    [0, 1].each do |y|
      paint.call("###" + cluster * 3, y).should_not contain(Ansi::ResetAutoWrapMode)
    end
    paint.call("######", 1).should contain(Ansi::ResetAutoWrapMode)
  end

  it "repaints rows moved by a hardware scroll" do
    output = IO::Memory.new
    renderer = RendererResizeSpecHelper.renderer(output)
    renderer.fullscreen = true
    renderer.scroll_optim = true
    renderer.resize(4, 8)

    screen = Ultraviolet::ScreenBuffer.new(4, 8)
    Ultraviolet::StyledString.new("aa").draw(screen, Ultraviolet.rect(0, 1, 4, 1))
    Ultraviolet::StyledString.new("bb").draw(screen, Ultraviolet.rect(0, 2, 4, 1))
    renderer.render(screen)
    renderer.flush
    output.clear

    Ultraviolet::StyledString.new("bb").draw(screen, Ultraviolet.rect(0, 0, 4, 1))
    Ultraviolet::StyledString.new("aa").draw(screen, Ultraviolet.rect(0, 2, 4, 1))
    renderer.render(screen)
    renderer.flush

    output.to_s.should contain(Ansi.scroll_up(2))
    output.to_s.scan("aa").size.should eq(2)
  end

  it "leaves no pending wrap after a corner cluster" do
    output = IO::Memory.new
    renderer = RendererResizeSpecHelper.renderer(output)
    renderer.fullscreen = true
    renderer.resize(6, 2)

    cellbuf = Ultraviolet::RenderBuffer.new(6, 2)
    6.times { |x| RendererResizeSpecHelper.set_mark(cellbuf, x, 1, "#") }
    RendererResizeSpecHelper.set_mark(cellbuf, 5, 1, "e\u0301")
    renderer.render(cellbuf)
    renderer.flush

    renderer.position[0].should be < cellbuf.width
  end

  it "sizes the damage record to the screen" do
    output = IO::Memory.new
    renderer = RendererResizeSpecHelper.renderer(output)
    renderer.fullscreen = true

    tall = Ultraviolet::RenderBuffer.new(4, 6)
    RendererResizeSpecHelper.set_mark(tall, 0, 5, "a")
    renderer.render(tall)
    renderer.damaged.size.should eq(6)

    renderer.damage(-3, 2)
    renderer.damage(6, 99)
    renderer.damaged.size.should eq(6)
    renderer.damaged.each { |damaged| damaged.should be_false }

    renderer.damage(4, 2)
    short = Ultraviolet::RenderBuffer.new(4, 2)
    RendererResizeSpecHelper.set_mark(short, 0, 0, "b")
    renderer.render(short)
    renderer.damaged.size.should eq(2)
  end

  it "survives a short touch list during scroll optimization" do
    output = IO::Memory.new
    renderer = RendererResizeSpecHelper.renderer(output)
    renderer.fullscreen = true
    renderer.scroll_optim = true

    cellbuf = Ultraviolet::RenderBuffer.new(5, 4)
    RendererResizeSpecHelper.set_mark(cellbuf, 0, 0, "a")
    renderer.render(cellbuf)
    renderer.flush

    cellbuf.touched = [] of Ultraviolet::LineData?
    RendererResizeSpecHelper.set_mark(cellbuf, 0, 0, "b")
    renderer.render(cellbuf)
    renderer.flush
  end

  it "repaints a resize even when the frame reports no touches" do
    output = IO::Memory.new
    renderer = RendererResizeSpecHelper.renderer(output)
    renderer.resize(20, 2)

    cellbuf = Ultraviolet::RenderBuffer.new(20, 2)
    RendererResizeSpecHelper.fill_row(cellbuf, 0, 20)
    renderer.render(cellbuf)
    renderer.flush

    cellbuf.touched = [] of Ultraviolet::LineData?
    cellbuf.touched_lines.should eq(0)

    output.clear
    renderer.resize(8, 2)
    renderer.resize(20, 2)
    renderer.render(cellbuf)
    renderer.flush

    output.to_s.should contain("a")
  end

  it "erases rows a frame gave back after collapsing" do
    output = IO::Memory.new
    renderer = RendererResizeSpecHelper.renderer(output)
    renderer.relative_cursor = true
    renderer.resize(6, 10)

    cellbuf = Ultraviolet::RenderBuffer.new(6, 2)
    RendererResizeSpecHelper.set_mark(cellbuf, 0, 0, "a")
    renderer.render(cellbuf)
    renderer.flush

    cellbuf.resize(6, 0)
    cellbuf.resize(6, 2)
    RendererResizeSpecHelper.set_mark(cellbuf, 0, 1, "b")
    output.clear
    renderer.render(cellbuf)
    renderer.flush

    output.to_s.should contain(Ansi::EraseLineRight)
  end

  it "limits height repaints to real fullscreen changes" do
    paint = ->(renderer : Ultraviolet::TerminalRenderer, width : Int32, height : Int32, mark : String) do
      buffer = Ultraviolet::RenderBuffer.new(width, height)
      RendererResizeSpecHelper.set_mark(buffer, 0, 0, mark) if width > 0 && height > 0
      renderer.render(buffer)
      renderer.flush
    end

    output = IO::Memory.new
    renderer = RendererResizeSpecHelper.renderer(output)
    renderer.relative_cursor = true
    paint.call(renderer, 10, 2, "a")
    output.clear
    paint.call(renderer, 10, 5, "a")
    output.to_s.should_not contain(Ansi::EraseEntireScreen)

    output = IO::Memory.new
    renderer = RendererResizeSpecHelper.renderer(output)
    renderer.fullscreen = true
    paint.call(renderer, 10, 3, "a")
    output.clear
    paint.call(renderer, 10, 3, "b")
    output.to_s.should_not contain(Ansi::EraseEntireScreen)

    output = IO::Memory.new
    renderer = RendererResizeSpecHelper.renderer(output)
    renderer.fullscreen = true
    paint.call(renderer, 10, 3, "a")
    [{0, 0}, {10, 0}, {0, 5}, {1, 1}].each do |size|
      renderer.resize(size[0], size[1])
      renderer.render(Ultraviolet::RenderBuffer.new(size[0], size[1]))
      renderer.flush
    end
  end

  it "repaints an inline frame after narrowing and growing back" do
    output = IO::Memory.new
    renderer = RendererResizeSpecHelper.renderer(output)
    renderer.relative_cursor = true
    renderer.resize(20, 2)

    cellbuf = Ultraviolet::RenderBuffer.new(20, 2)
    RendererResizeSpecHelper.fill_row(cellbuf, 0, 20)
    renderer.render(cellbuf)
    renderer.flush
    output.clear

    renderer.resize(8, 2)
    renderer.resize(20, 2)
    renderer.render(cellbuf)
    renderer.flush

    output.to_s.should contain("a")
  end

  it "only sends a carried sequence once" do
    apc = "\e_Ga=T\e\\"
    output = IO::Memory.new
    renderer = RendererResizeSpecHelper.renderer(output)
    renderer.fullscreen = true

    screen = Ultraviolet::ScreenBuffer.new(10, 2)
    Ultraviolet::StyledString.new(apc + "hi").draw(screen, Ultraviolet.rect(0, 0, 10, 1))
    renderer.render(screen)
    renderer.flush
    output.to_s.scan(apc).size.should eq(1)

    output.clear
    renderer.render(screen)
    renderer.flush
    output.to_s.scan(apc).size.should eq(0)
  end
end
