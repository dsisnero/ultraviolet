require "textseg"
require "uniwidth"
require "./spec_helper"

describe Ultraviolet::Buffer do
  def buffer_width(value : String) : Int32
    max = 0
    value.split('\n', remove_empty: false).each do |line|
      max = {max, UnicodeCharWidth.width(line)}.max
    end
    max
  end

  def buffer_height(value : String) : Int32
    value.count('\n') + 1
  end

  it "renders graphemes using unicode widths" do
    cases = [
      {name: "empty buffer", input: "", expected: ""},
      {name: "single line", input: "Hello, World!", expected: "Hello, World!"},
      {
        name:     "multiple lines",
        input:    "Hello, World!\nThis is a test.\nGoodbye!",
        expected: "Hello, World!\nThis is a test.\nGoodbye!",
      },
    ]

    cases.each do |test_case|
      buf = Ultraviolet::Buffer.new(buffer_width(test_case[:input]), buffer_height(test_case[:input]))
      test_case[:input].split('\n', remove_empty: false).each_with_index do |line, y|
        x = 0
        TextSegment.each_grapheme(line) do |cluster|
          grapheme = cluster.str
          cell = Ultraviolet::Cell.new(grapheme, UnicodeCharWidth.width(grapheme))
          buf.set_cell(x, y, cell)
          x += cell.width
        end
      end

      Ultraviolet.trim_space(buf.string).should eq(test_case[:expected]), test_case[:name]
    end
  end
end

describe Ultraviolet::Line do
  it "sets cells with wide handling" do
    line = Ultraviolet::Line.new(10)
    line.set(5, Ultraviolet::Cell.new("a", 1))
    line.cells[5].string.should eq("a")

    line.set(-1, Ultraviolet::Cell.new("a", 1))
    line.set(10, Ultraviolet::Cell.new("a", 1))

    line.set(2, Ultraviolet::Cell.new("你", 2))
    line.set(2, Ultraviolet::Cell.new("a", 1))
    line.cells[2].string.should eq("a")

    line.set(2, Ultraviolet::Cell.new("你", 2))
    line.set(3, Ultraviolet::Cell.new("a", 1))
    line.cells[3].string.should eq("a")
    line.cells[2].string.should eq(" ")

    line.set(9, Ultraviolet::Cell.new("你", 2))
    line.cells[9].string.should eq(" ")
  end

  it "renders line string" do
    line = Ultraviolet::Line.new(5)
    line.string.should eq("")

    line = Ultraviolet::Line.new(5)
    line.cells[0] = Ultraviolet::Cell.new("H", 1)
    line.cells[1] = Ultraviolet::Cell.new("e", 1)
    line.cells[2] = Ultraviolet::Cell.new("l", 1)
    line.cells[3] = Ultraviolet::Cell.new("l", 1)
    line.cells[4] = Ultraviolet::Cell.new("o", 1)
    line.string.should eq("Hello")

    line = Ultraviolet::Line.new(6)
    line.cells[0] = Ultraviolet::Cell.new("你", 2)
    line.cells[1] = Ultraviolet::Cell.new
    line.cells[2] = Ultraviolet::Cell.new("好", 2)
    line.cells[3] = Ultraviolet::Cell.new
    line.cells[4] = Ultraviolet::Cell.new("!", 1)
    line.cells[5] = Ultraviolet::Cell.new(" ", 1)
    line.string.should eq("你好!")

    line = Ultraviolet::Line.new(10)
    line.cells[0] = Ultraviolet::Cell.new("H", 1)
    line.cells[1] = Ultraviolet::Cell.new("i", 1)
    line.string.should eq("Hi")
  end
end

describe Ultraviolet::Buffer do
  it "handles core buffer operations" do
    buffer = Ultraviolet::Buffer.new(0, 0)
    buffer.width.should eq(0)

    buffer = Ultraviolet::Buffer.new(10, 5)
    buffer.width.should eq(10)

    buffer.set_cell(2, 1, Ultraviolet::Cell.new("X", 1))
    cell = buffer.cell_at(2, 1)
    if cell
      cell.string.should eq("X")
    else
      fail "expected cell at (2, 1)"
    end

    buffer.cell_at(-1, 0).should be_nil
    buffer.cell_at(0, -1).should be_nil
    buffer.cell_at(10, 0).should be_nil
    buffer.cell_at(0, 5).should be_nil

    buffer.set_cell(2, 1, Ultraviolet::Cell.new("A", 1))
    buffer.set_cell(-1, 0, Ultraviolet::Cell.new("B", 1))
    buffer.set_cell(0, -1, Ultraviolet::Cell.new("C", 1))
    buffer.set_cell(10, 0, Ultraviolet::Cell.new("D", 1))
    buffer.set_cell(0, 5, Ultraviolet::Cell.new("E", 1))
    buffer.set_cell(3, 1, nil)

    buffer.resize(5, 3)
    buffer.width.should eq(5)
    buffer.height.should eq(3)

    buffer.resize(15, 10)
    buffer.width.should eq(15)
    buffer.height.should eq(10)

    buffer.resize(15, 10)
    buffer.width.should eq(15)
    buffer.height.should eq(10)
  end

  it "fills, clears, clones, and draws" do
    buffer = Ultraviolet::Buffer.new(10, 5)
    buffer.fill_area(Ultraviolet::Cell.new("X", 1), Ultraviolet.rect(2, 1, 3, 2))

    (1...3).each do |y|
      (2...5).each do |x|
        cell = buffer.cell_at(x, y)
        if cell
          cell.string.should eq("X")
        else
          fail "expected cell at (#{x}, #{y})"
        end
      end
    end

    buffer.fill_area(nil, Ultraviolet.rect(0, 0, 2, 2))

    buffer.set_cell(2, 1, Ultraviolet::Cell.new("X", 1))
    buffer.clear
    (0...buffer.height).each do |y|
      (0...buffer.width).each do |x|
        cell = buffer.cell_at(x, y)
        if cell
          cell.string.should eq(" ")
        end
      end
    end

    buffer.set_cell(2, 1, Ultraviolet::Cell.new("X", 1))
    clone = buffer.clone
    clone_cell = clone.cell_at(2, 1)
    if clone_cell
      clone_cell.string.should eq("X")
    else
      fail "expected clone cell"
    end
    clone.set_cell(2, 1, Ultraviolet::Cell.new("Y", 1))
    buffer.cell_at(2, 1).try(&.string).should eq("X")

    buffer = Ultraviolet::Buffer.new(10, 5)
    buffer.set_cell(2, 1, Ultraviolet::Cell.new("X", 1))
    buffer.set_cell(3, 2, Ultraviolet::Cell.new("Y", 1))
    area_clone = buffer.clone_area(Ultraviolet.rect(2, 1, 2, 2))
    if area_clone
      area_clone.width.should eq(2)
      area_clone.height.should eq(2)
      area_clone.cell_at(0, 0).try(&.string).should eq("X")
      area_clone.cell_at(1, 1).try(&.string).should eq("Y")
    else
      fail "expected area clone"
    end

    src = Ultraviolet::Buffer.new(3, 3)
    src.set_cell(1, 1, Ultraviolet::Cell.new("S", 1))
    dst = Ultraviolet::ScreenBuffer.new(10, 5)
    dst.set_cell(2, 2, Ultraviolet::Cell.new("D", 1))
    src.draw(dst, Ultraviolet.rect(1, 1, 3, 3))
    dst.cell_at(2, 2).try(&.string).should eq("S")
  end

  it "renders buffer text" do
    buffer = Ultraviolet::Buffer.new(5, 2)
    buffer.set_cell(0, 0, Ultraviolet::Cell.new("H", 1))
    buffer.set_cell(1, 0, Ultraviolet::Cell.new("i", 1))
    buffer.set_cell(0, 1, Ultraviolet::Cell.new("!", 1))
    buffer.render.should contain("Hi")
  end
end

describe "Buffer line and cell operations" do
  it "inserts and deletes lines" do
    buffer = Ultraviolet::Buffer.new(5, 3)
    buffer.set_cell(0, 0, Ultraviolet::Cell.new("A", 1))
    buffer.set_cell(0, 1, Ultraviolet::Cell.new("B", 1))
    buffer.set_cell(0, 2, Ultraviolet::Cell.new("C", 1))

    buffer.insert_line(1, 1, nil)
    buffer.cell_at(0, 2).try(&.string).should eq("B")
    buffer.cell_at(0, 1).try(&.string).should eq(" ")

    buffer = Ultraviolet::Buffer.new(5, 5)
    buffer.set_cell(0, 1, Ultraviolet::Cell.new("A", 1))
    buffer.set_cell(0, 2, Ultraviolet::Cell.new("B", 1))
    buffer.insert_line_area(2, 1, nil, Ultraviolet.rect(0, 1, 5, 3))
    buffer.cell_at(0, 3).try(&.string).should eq("B")

    buffer = Ultraviolet::Buffer.new(5, 3)
    buffer.set_cell(0, 0, Ultraviolet::Cell.new("A", 1))
    buffer.set_cell(0, 1, Ultraviolet::Cell.new("B", 1))
    buffer.set_cell(0, 2, Ultraviolet::Cell.new("C", 1))
    buffer.delete_line(1, 1, nil)
    buffer.cell_at(0, 1).try(&.string).should eq("C")
    buffer.cell_at(0, 2).try(&.string).should eq(" ")

    buffer = Ultraviolet::Buffer.new(5, 5)
    buffer.set_cell(0, 1, Ultraviolet::Cell.new("A", 1))
    buffer.set_cell(0, 2, Ultraviolet::Cell.new("B", 1))
    buffer.set_cell(0, 3, Ultraviolet::Cell.new("C", 1))
    buffer.delete_line_area(2, 1, nil, Ultraviolet.rect(0, 1, 5, 3))
    buffer.cell_at(0, 2).try(&.string).should eq("C")
  end

  it "inserts and deletes cells" do
    buffer = Ultraviolet::Buffer.new(5, 2)
    if line = buffer.line(0)
      line.cells[0] = Ultraviolet::Cell.new("A", 1)
      line.cells[1] = Ultraviolet::Cell.new("B", 1)
      line.cells[2] = Ultraviolet::Cell.new("C", 1)
    end
    buffer.insert_cell(1, 0, 1, nil)
    buffer.cell_at(2, 0).try(&.string).should eq("B")

    buffer = Ultraviolet::Buffer.new(5, 3)
    if line = buffer.line(1)
      line.cells[1] = Ultraviolet::Cell.new("A", 1)
      line.cells[2] = Ultraviolet::Cell.new("B", 1)
    end
    buffer.insert_cell_area(1, 1, 1, nil, Ultraviolet.rect(1, 1, 3, 1))
    buffer.cell_at(2, 1).try(&.string).should eq("A")

    buffer = Ultraviolet::Buffer.new(5, 2)
    if line = buffer.line(0)
      line.cells[0] = Ultraviolet::Cell.new("A", 1)
      line.cells[1] = Ultraviolet::Cell.new("B", 1)
      line.cells[2] = Ultraviolet::Cell.new("C", 1)
    end
    buffer.delete_cell(1, 0, 1, nil)
    buffer.cell_at(1, 0).try(&.string).should eq("C")

    buffer = Ultraviolet::Buffer.new(5, 3)
    if line = buffer.line(1)
      line.cells[1] = Ultraviolet::Cell.new("A", 1)
      line.cells[2] = Ultraviolet::Cell.new("B", 1)
      line.cells[3] = Ultraviolet::Cell.new("C", 1)
    end
    buffer.delete_cell_area(2, 1, 1, nil, Ultraviolet.rect(1, 1, 3, 1))
    buffer.cell_at(2, 1).try(&.string).should eq("C")
  end
end

describe Ultraviolet::ScreenBuffer do
  it "exposes default width method" do
    buffer = Ultraviolet::ScreenBuffer.new(10, 5)
    method = buffer.width_method
    method.call("a").should eq(1)
  end
end

describe Ultraviolet::Line do
  it "renders styles and links" do
    line = Ultraviolet::Line.new(5)
    line.cells[0] = Ultraviolet::Cell.new("H", 1, Ultraviolet::Style.new(fg: Ultraviolet::Color.new(255_u8, 0_u8, 0_u8)))
    line.cells[1] = Ultraviolet::Cell.new("i", 1)
    output = line.render
    output.should contain("H")
    output.should contain("i")

    line = Ultraviolet::Line.new(5)
    link = Ultraviolet::Link.new("http://example.com")
    line.cells[0] = Ultraviolet::Cell.new("L", 1, Ultraviolet::Style.new, link)
    line.cells[1] = Ultraviolet::Cell.new("i", 1, Ultraviolet::Style.new, link)
    line.cells[2] = Ultraviolet::Cell.new("n", 1, Ultraviolet::Style.new, link)
    line.cells[3] = Ultraviolet::Cell.new("k", 1, Ultraviolet::Style.new, link)
    output = line.render
    output.should contain("Link")
  end
end
