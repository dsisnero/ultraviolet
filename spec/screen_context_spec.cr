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
end
