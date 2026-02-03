require "./spec_helper"

describe Ultraviolet do
  it "sets and reads cells from the buffer" do
    buffer = Ultraviolet::Buffer.new(4, 2)
    cell = Ultraviolet::Cell.new("A", 1)
    buffer.set_cell(1, 0, cell)

    fetched = buffer.cell_at(1, 0)
    fetched.should_not be_nil
    fetched.not_nil!.string.should eq("A")
  end

  it "renders lines without styles" do
    line = Ultraviolet::Line.new(3)
    line.set(0, Ultraviolet::Cell.new("H", 1))
    line.set(1, Ultraviolet::Cell.new("i", 1))

    line.string.should eq("Hi")
    line.render.should eq("Hi")
  end

  it "clones areas of a buffer" do
    buffer = Ultraviolet::Buffer.new(3, 3)
    buffer.set_cell(0, 0, Ultraviolet::Cell.new("X", 1))
    buffer.set_cell(1, 1, Ultraviolet::Cell.new("Y", 1))

    area = Ultraviolet.rect(0, 0, 2, 2)
    clone = buffer.clone_area(area)
    clone.should_not be_nil
    clone.not_nil!.cell_at(0, 0).not_nil!.string.should eq("X")
    clone.not_nil!.cell_at(1, 1).not_nil!.string.should eq("Y")
  end
end
