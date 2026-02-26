require "./spec_helper"

describe Ultraviolet::TerminalScreen do
  it "clears the screen before display draws a drawable" do
    output = IO::Memory.new
    screen = Ultraviolet::TerminalScreen.new(output, ["TERM=xterm-256color"])
    screen.resize(4, 2)
    screen.set_cell(1, 0, Ultraviolet::Cell.new("X", 1))

    drawable = Ultraviolet::DrawableFunc.new do |scr, _area|
      scr.set_cell(0, 0, Ultraviolet::Cell.new("A", 1))
    end

    screen.display(drawable)
    screen.cell_at(0, 0).try(&.string).should eq("A")
    screen.cell_at(1, 0).try(&.string).should eq(" ")
  end

  it "supports inserting content above the current screen" do
    output = IO::Memory.new
    screen = Ultraviolet::TerminalScreen.new(output, ["TERM=xterm-256color"])
    screen.resize(4, 2)
    screen.set_cell(0, 0, Ultraviolet::Cell.new("B", 1))
    screen.render
    screen.flush

    screen.insert_above("Z")
    output.to_s.includes?("Z").should be_true
  end
end
