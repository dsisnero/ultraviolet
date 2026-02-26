require "./spec_helper"

describe Ultraviolet::Screen::Context do
  it "tracks position and writes using the screen width method" do
    method = ->(value : String) do
      if value == "a" || value == "b"
        2
      else
        UnicodeCharWidth.width(value)
      end
    end

    screen = Ultraviolet::ScreenBuffer.new(4, 2, method)
    context = Ultraviolet::Screen::Context.new(screen)
    context.write_string("ab")

    context.position.should eq({0, 1})
    screen.cell_at(0, 0).try(&.string).should eq("a")
    screen.cell_at(2, 0).try(&.string).should eq("b")
  end

  it "returns copy contexts from with_ methods" do
    screen = Ultraviolet::ScreenBuffer.new(4, 2)
    context = Ultraviolet::Screen::Context.new(screen)
    copy = context.with_position(1, 1)

    context.position.should eq({0, 0})
    copy.position.should eq({1, 1})
  end

  it "prints and advances position with println spacing semantics" do
    screen = Ultraviolet::ScreenBuffer.new(12, 3)
    context = Ultraviolet::Screen::Context.new(screen)

    context.print("A", "B").should eq(2)
    context.println("C", "D").should eq(4)
    context.position.should eq({0, 1})
    screen.cell_at(0, 0).try(&.string).should eq("A")
    screen.cell_at(1, 0).try(&.string).should eq("B")
    screen.cell_at(2, 0).try(&.string).should eq("C")
    screen.cell_at(3, 0).try(&.string).should eq(" ")
    screen.cell_at(4, 0).try(&.string).should eq("D")
  end

  it "draw_string does not mutate context position" do
    screen = Ultraviolet::ScreenBuffer.new(6, 2)
    context = Ultraviolet::Screen::Context.new(screen)
    context.move_to(2, 1)
    context.draw_string("xy", 0, 0)

    context.position.should eq({2, 1})
    screen.cell_at(0, 0).try(&.string).should eq("x")
    screen.cell_at(1, 0).try(&.string).should eq("y")
  end

  it "writes hyperlink style with variadic URL params" do
    screen = Ultraviolet::ScreenBuffer.new(8, 2)
    context = Ultraviolet::Screen::Context.new(screen).with_url("https://example.com", "id=1", "k=v")
    context.write_string("X")

    link = screen.cell_at(0, 0).try(&.link)
    link.try(&.url).should eq("https://example.com")
    link.try(&.params).should eq("id=1:k=v")
  end
end
