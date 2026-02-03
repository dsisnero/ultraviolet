require "./spec_helper"

describe "Layout constraints" do
  it "computes ratio as percent" do
    tests = [
      {num: 1, den: 2, expected: 50},
      {num: 1, den: 4, expected: 25},
      {num: 3, den: 4, expected: 75},
      {num: 0, den: 1, expected: 0},
      {num: 1, den: 0, expected: 0},
      {num: 5, den: 5, expected: 100},
      {num: 2, den: 3, expected: 66},
    ]

    tests.each do |test_case|
      Ultraviolet.ratio(test_case[:num], test_case[:den]).value.should eq(test_case[:expected])
    end
  end

  it "applies percent constraints" do
    tests = [
      {percent: 50, size: 200, expected: 100},
      {percent: 25, size: 400, expected: 100},
      {percent: 75, size: 800, expected: 600},
      {percent: 0, size: 100, expected: 0},
      {percent: 100, size: 100, expected: 100},
      {percent: -10, size: 100, expected: 0},
      {percent: 150, size: 100, expected: 100},
    ]

    tests.each do |test_case|
      Ultraviolet::Percent.new(test_case[:percent]).apply(test_case[:size]).should eq(test_case[:expected])
    end
  end

  it "applies fixed constraints" do
    tests = [
      {fixed: 50, size: 200, expected: 50},
      {fixed: 150, size: 200, expected: 150},
      {fixed: 250, size: 200, expected: 200},
      {fixed: 0, size: 100, expected: 0},
      {fixed: -10, size: 100, expected: 0},
    ]

    tests.each do |test_case|
      Ultraviolet::Fixed.new(test_case[:fixed]).apply(test_case[:size]).should eq(test_case[:expected])
    end
  end
end

describe "Layout splitting" do
  it "splits vertically" do
    tests = [
      {
        area:       Ultraviolet::Rectangle.new(Ultraviolet::Position.new(0, 0), Ultraviolet::Position.new(100, 200)),
        constraint: Ultraviolet::Percent.new(50),
        top:        Ultraviolet::Rectangle.new(Ultraviolet::Position.new(0, 0), Ultraviolet::Position.new(100, 100)),
        bottom:     Ultraviolet::Rectangle.new(Ultraviolet::Position.new(0, 100), Ultraviolet::Position.new(100, 200)),
      },
      {
        area:       Ultraviolet::Rectangle.new(Ultraviolet::Position.new(0, 0), Ultraviolet::Position.new(100, 200)),
        constraint: Ultraviolet::Fixed.new(80),
        top:        Ultraviolet::Rectangle.new(Ultraviolet::Position.new(0, 0), Ultraviolet::Position.new(100, 80)),
        bottom:     Ultraviolet::Rectangle.new(Ultraviolet::Position.new(0, 80), Ultraviolet::Position.new(100, 200)),
      },
      {
        area:       Ultraviolet::Rectangle.new(Ultraviolet::Position.new(0, 0), Ultraviolet::Position.new(100, 200)),
        constraint: Ultraviolet::Percent.new(150),
        top:        Ultraviolet::Rectangle.new(Ultraviolet::Position.new(0, 0), Ultraviolet::Position.new(100, 200)),
        bottom:     Ultraviolet::Rectangle.new(Ultraviolet::Position.new(0, 200), Ultraviolet::Position.new(100, 200)),
      },
    ]

    tests.each do |test_case|
      top, bottom = Ultraviolet.split_vertical(test_case[:area], test_case[:constraint])
      top.should eq(test_case[:top])
      bottom.should eq(test_case[:bottom])
    end
  end

  it "splits horizontally" do
    tests = [
      {
        area:       Ultraviolet::Rectangle.new(Ultraviolet::Position.new(0, 0), Ultraviolet::Position.new(200, 100)),
        constraint: Ultraviolet::Percent.new(50),
        left:       Ultraviolet::Rectangle.new(Ultraviolet::Position.new(0, 0), Ultraviolet::Position.new(100, 100)),
        right:      Ultraviolet::Rectangle.new(Ultraviolet::Position.new(100, 0), Ultraviolet::Position.new(200, 100)),
      },
      {
        area:       Ultraviolet::Rectangle.new(Ultraviolet::Position.new(0, 0), Ultraviolet::Position.new(200, 100)),
        constraint: Ultraviolet::Fixed.new(80),
        left:       Ultraviolet::Rectangle.new(Ultraviolet::Position.new(0, 0), Ultraviolet::Position.new(80, 100)),
        right:      Ultraviolet::Rectangle.new(Ultraviolet::Position.new(80, 0), Ultraviolet::Position.new(200, 100)),
      },
      {
        area:       Ultraviolet::Rectangle.new(Ultraviolet::Position.new(0, 0), Ultraviolet::Position.new(200, 100)),
        constraint: Ultraviolet::Percent.new(150),
        left:       Ultraviolet::Rectangle.new(Ultraviolet::Position.new(0, 0), Ultraviolet::Position.new(200, 100)),
        right:      Ultraviolet::Rectangle.new(Ultraviolet::Position.new(200, 0), Ultraviolet::Position.new(200, 100)),
      },
    ]

    tests.each do |test_case|
      left, right = Ultraviolet.split_horizontal(test_case[:area], test_case[:constraint])
      left.should eq(test_case[:left])
      right.should eq(test_case[:right])
    end
  end
end
