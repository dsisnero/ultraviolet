require "./spec_helper"

describe Ultraviolet do
  it "sets and reads cells from the buffer" do
    buffer = Ultraviolet::Buffer.new(4, 2)
    cell = Ultraviolet::Cell.new("A", 1)
    buffer.set_cell(1, 0, cell)

    fetched = buffer.cell_at(1, 0)
    if fetched
      fetched.string.should eq("A")
    else
      fail "expected cell at (1, 0)"
    end
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
    if clone
      cell = clone.cell_at(0, 0)
      if cell
        cell.string.should eq("X")
      else
        fail "expected cloned cell at (0, 0)"
      end

      cell = clone.cell_at(1, 1)
      if cell
        cell.string.should eq("Y")
      else
        fail "expected cloned cell at (1, 1)"
      end
    else
      fail "expected cloned buffer"
    end
  end
end
