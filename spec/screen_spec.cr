require "./spec_helper"

class MockScreen
  include Ultraviolet::Screen
  include Ultraviolet::ScreenClear
  include Ultraviolet::ScreenClearArea
  include Ultraviolet::ScreenFill
  include Ultraviolet::ScreenFillArea
  include Ultraviolet::ScreenClone
  include Ultraviolet::ScreenCloneArea

  getter buffer : Ultraviolet::Buffer
  getter method : Ultraviolet::WidthMethod

  def initialize(width : Int32, height : Int32)
    @buffer = Ultraviolet::Buffer.new(width, height)
    @method = Ultraviolet::DEFAULT_WIDTH_METHOD
  end

  def bounds : Ultraviolet::Rectangle
    @buffer.bounds
  end

  def cell_at(x : Int32, y : Int32) : Ultraviolet::Cell?
    @buffer.cell_at(x, y)
  end

  def set_cell(x : Int32, y : Int32, cell : Ultraviolet::Cell?) : Nil
    @buffer.set_cell(x, y, cell)
  end

  def width : Int32
    @buffer.width
  end

  def height : Int32
    @buffer.height
  end

  def width_method : Ultraviolet::WidthMethod
    @method
  end

  def clear : Nil
    @buffer.clear
  end

  def clear_area(area : Ultraviolet::Rectangle) : Nil
    @buffer.clear_area(area)
  end

  def fill(cell : Ultraviolet::Cell?) : Nil
    @buffer.fill(cell)
  end

  def fill_area(cell : Ultraviolet::Cell?, area : Ultraviolet::Rectangle) : Nil
    @buffer.fill_area(cell, area)
  end

  def clone : Ultraviolet::Buffer
    @buffer.clone
  end

  def clone_area(area : Ultraviolet::Rectangle) : Ultraviolet::Buffer?
    @buffer.clone_area(area)
  end
end

class MinimalMockScreen
  include Ultraviolet::Screen

  getter method : Ultraviolet::WidthMethod

  def initialize(@width : Int32, @height : Int32)
    @cells = Array(Array(Ultraviolet::Cell)).new(@height) do
      Array(Ultraviolet::Cell).new(@width, Ultraviolet::EMPTY_CELL)
    end
    @method = Ultraviolet::DEFAULT_WIDTH_METHOD
  end

  def bounds : Ultraviolet::Rectangle
    Ultraviolet.rect(0, 0, @width, @height)
  end

  def cell_at(x : Int32, y : Int32) : Ultraviolet::Cell?
    return if x < 0 || x >= @width || y < 0 || y >= @height
    @cells[y][x]
  end

  def set_cell(x : Int32, y : Int32, cell : Ultraviolet::Cell?) : Nil
    return if x < 0 || x >= @width || y < 0 || y >= @height
    @cells[y][x] = cell ? cell.clone : Ultraviolet::EMPTY_CELL
  end

  def width : Int32
    @width
  end

  def height : Int32
    @height
  end

  def width_method : Ultraviolet::WidthMethod
    @method
  end
end

class NilCellMockScreen
  include Ultraviolet::Screen

  getter method : Ultraviolet::WidthMethod

  def initialize(@width : Int32, @height : Int32)
    @cells = {} of String => Ultraviolet::Cell
    @nil_positions = {} of String => Bool
    @method = Ultraviolet::DEFAULT_WIDTH_METHOD
  end

  def bounds : Ultraviolet::Rectangle
    Ultraviolet.rect(0, 0, @width, @height)
  end

  def cell_at(x : Int32, y : Int32) : Ultraviolet::Cell?
    return if x < 0 || x >= @width || y < 0 || y >= @height
    key = "#{x},#{y}"
    return if @nil_positions[key]?
    if cell = @cells[key]?
      cell
    else
      Ultraviolet::EMPTY_CELL
    end
  end

  def set_cell(x : Int32, y : Int32, cell : Ultraviolet::Cell?) : Nil
    return if x < 0 || x >= @width || y < 0 || y >= @height
    key = "#{x},#{y}"
    @cells[key] = cell ? cell.clone : Ultraviolet::EMPTY_CELL
  end

  def set_nil_at(x : Int32, y : Int32) : Nil
    @nil_positions["#{x},#{y}"] = true
  end

  def width : Int32
    @width
  end

  def height : Int32
    @height
  end

  def width_method : Ultraviolet::WidthMethod
    @method
  end
end

describe Ultraviolet::Screen do
  it "clears a screen" do
    screen = MockScreen.new(10, 5)
    test_cell = Ultraviolet::Cell.new("X", 1)
    screen.set_cell(0, 0, test_cell)
    screen.set_cell(5, 2, test_cell)

    Ultraviolet::Screen.clear(screen)

    screen.cell_at(0, 0).try(&.content).should eq(" ")
    screen.cell_at(5, 2).try(&.content).should eq(" ")
  end

  it "clears an area" do
    screen = MockScreen.new(10, 5)
    test_cell = Ultraviolet::Cell.new("X", 1)
    5.times do |y|
      10.times do |x|
        screen.set_cell(x, y, test_cell)
      end
    end

    area = Ultraviolet.rect(2, 1, 4, 2)
    Ultraviolet::Screen.clear_area(screen, area)

    5.times do |y|
      10.times do |x|
        cell = screen.cell_at(x, y)
        if x >= 2 && x < 6 && y >= 1 && y < 3
          cell.try(&.content).should eq(" ")
        else
          cell.try(&.content).should eq("X")
        end
      end
    end
  end

  it "fills a screen" do
    screen = MockScreen.new(10, 5)
    fill_cell = Ultraviolet::Cell.new("F", 1)
    Ultraviolet::Screen.fill(screen, fill_cell)

    5.times do |y|
      10.times do |x|
        screen.cell_at(x, y).try(&.content).should eq("F")
      end
    end
  end

  it "fills an area" do
    screen = MockScreen.new(10, 5)
    fill_cell = Ultraviolet::Cell.new("A", 1)
    area = Ultraviolet.rect(2, 1, 4, 2)
    Ultraviolet::Screen.fill_area(screen, fill_cell, area)

    5.times do |y|
      10.times do |x|
        next unless x >= 2 && x < 6 && y >= 1 && y < 3
        screen.cell_at(x, y).try(&.content).should eq("A")
      end
    end
  end

  it "clones a screen" do
    screen = MockScreen.new(10, 5)
    screen.set_cell(0, 0, Ultraviolet::Cell.new("A", 1))
    screen.set_cell(5, 2, Ultraviolet::Cell.new("B", 1))
    screen.set_cell(9, 4, Ultraviolet::Cell.new("C", 1))

    cloned = Ultraviolet::Screen.clone(screen)
    cloned.width.should eq(10)
    cloned.height.should eq(5)
    cloned.cell_at(0, 0).try(&.content).should eq("A")
    cloned.cell_at(5, 2).try(&.content).should eq("B")
    cloned.cell_at(9, 4).try(&.content).should eq("C")
  end

  it "clones an area" do
    screen = MockScreen.new(10, 5)
    5.times do |y|
      10.times do |x|
        content = ('A'.ord + y * 10 + x).chr.to_s
        screen.set_cell(x, y, Ultraviolet::Cell.new(content, 1))
      end
    end

    area = Ultraviolet.rect(2, 1, 4, 2)
    cloned = Ultraviolet::Screen.clone_area(screen, area)
    if cloned
      cloned.width.should eq(4)
      cloned.height.should eq(2)

      2.times do |y|
        4.times do |x|
          expected = ('A'.ord + (y + 1) * 10 + (x + 2)).chr.to_s
          cloned.cell_at(x, y).try(&.content).should eq(expected)
        end
      end
    else
      fail "CloneArea returned nil"
    end
  end

  it "handles empty screen" do
    screen = MockScreen.new(0, 0)
    Ultraviolet::Screen.clear(screen)
    Ultraviolet::Screen.fill(screen, Ultraviolet::Cell.new("X", 1))
    Ultraviolet::Screen.clear_area(screen, Ultraviolet.rect(0, 0, 1, 1))
    Ultraviolet::Screen.fill_area(screen, Ultraviolet::Cell.new("X", 1), Ultraviolet.rect(0, 0, 1, 1))
    Ultraviolet::Screen.clone(screen)
    Ultraviolet::Screen.clone_area(screen, Ultraviolet.rect(0, 0, 1, 1))
  end

  it "clones wide cells" do
    screen = Ultraviolet::ScreenBuffer.new(10, 5)
    wide_cell = Ultraviolet::Cell.new("😀", 2)
    screen.set_cell(0, 0, wide_cell)

    cloned = Ultraviolet::Screen.clone(screen)
    cloned.cell_at(0, 0).try(&.content).should eq("😀")
    cloned.cell_at(0, 0).try(&.width).should eq(2)

    Ultraviolet::Screen.fill_area(screen, wide_cell, Ultraviolet.rect(0, 1, 4, 1))
    (0...4).step(2) do |x|
      cell = screen.cell_at(x, 1)
      cell.try(&.content).should eq("😀")
      cell.try(&.width).should eq(2)
    end
  end

  it "clones styled cells" do
    screen = Ultraviolet::ScreenBuffer.new(10, 5)
    style = Ultraviolet::Style.new(attrs: Ultraviolet::Attr::BOLD | Ultraviolet::Attr::ITALIC)
    styled_cell = Ultraviolet::Cell.new("S", 1, style)
    screen.set_cell(0, 0, styled_cell)

    cloned = Ultraviolet::Screen.clone(screen)
    cell = cloned.cell_at(0, 0)
    cell.try(&.content).should eq("S")
    cell.not_nil!.style.attrs.should eq(style.attrs)
  end

  it "clones cells with links" do
    screen = Ultraviolet::ScreenBuffer.new(10, 5)
    linked_cell = Ultraviolet::Cell.new("L", 1, Ultraviolet::Style.new, Ultraviolet.new_link("https://example.com", ["id=test"]))
    screen.set_cell(0, 0, linked_cell)

    cloned = Ultraviolet::Screen.clone(screen)
    cloned.cell_at(0, 0).try(&.link.url).should eq("https://example.com")
  end

  it "uses minimal screen fallbacks" do
    screen = MinimalMockScreen.new(5, 3)
    test_cell = Ultraviolet::Cell.new("X", 1)
    screen.set_cell(0, 0, test_cell)
    screen.set_cell(2, 1, test_cell)
    screen.set_cell(4, 2, test_cell)

    Ultraviolet::Screen.clear(screen)

    3.times do |y|
      5.times do |x|
        screen.cell_at(x, y).try(&.content).should eq(" ")
      end
    end
  end

  it "clones with nil cells" do
    screen = NilCellMockScreen.new(10, 5)
    screen.set_cell(2, 1, Ultraviolet::Cell.new("A", 1))
    screen.set_cell(4, 2, Ultraviolet::Cell.new("B", 1))
    screen.set_nil_at(3, 1)
    screen.set_nil_at(5, 2)

    area = Ultraviolet.rect(2, 1, 4, 2)
    cloned = Ultraviolet::Screen.clone_area(screen, area)
    if cloned
      cloned.cell_at(0, 0).try(&.content).should eq("A")
      cloned.cell_at(2, 1).try(&.content).should eq("B")
      cloned.cell_at(1, 0).try(&.content).should eq(" ")
      cloned.cell_at(3, 1).try(&.content).should eq(" ")
    else
      fail "CloneArea returned nil"
    end
  end
end
