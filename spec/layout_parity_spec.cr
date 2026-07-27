require "./spec_helper"

LE = Ultraviolet::Layout::Len
MA = Ultraviolet::Layout::Max
MI = Ultraviolet::Layout::Min
PE = Ultraviolet::Layout::Percent
RA = Ultraviolet::Layout::Ratio

FXS = Ultraviolet::Layout::Flex::Start
FXL = Ultraviolet::Layout::Flex::Legacy
FXE = Ultraviolet::Layout::Flex::End
FXC = Ultraviolet::Layout::Flex::Center
FXSB = Ultraviolet::Layout::Flex::SpaceBetween
FXSE = Ultraviolet::Layout::Flex::SpaceEvenly
FXSA = Ultraviolet::Layout::Flex::SpaceAround

def assert_layout(flex, constraints, width, expected)
  area = Ultraviolet.rect(0, 0, width, 1)
  arr = Array(Ultraviolet::Layout::Constraint).new
  constraints.each { |c| arr << c }
  splitter = Ultraviolet::Layout::Splitter.new(Ultraviolet::Layout::Direction::Horizontal, arr, flex: flex)
  result = splitter.split(area)

  got = Ultraviolet::ScreenBuffer.new(area.dx, area.dy)
  latin = ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j']

  limit = {constraints.size, result.size}.min
  limit.times do |i|
    c = latin[i]
    seg = result[i]
    s = c.to_s * seg.dx
    buf = Ultraviolet::ScreenBuffer.new(seg.dx, seg.dy)
    Ultraviolet::Screen::Context.new(buf).write_string(s)
    buf.draw(got, seg)
  end

  got_str = String.build do |sb|
    got.height.times do |y|
      got.width.times do |x|
        cell = got.cell_at(x, y)
        sb << (cell && !cell.content.empty? ? cell.content : " ")
      end
    end
  end

  got_str.should eq(expected)
end

def assert_ranges(flex, constraints, width, expected)
  arr = Array(Ultraviolet::Layout::Constraint).new
  constraints.each { |c| arr << c }
  splitter = Ultraviolet::Layout::Splitter.new(Ultraviolet::Layout::Direction::Horizontal, arr, flex: flex)
  result = splitter.split(Ultraviolet.rect(0, 0, width, 1))
  expected.each_with_index do |exp, i|
    result[i].min.x.should eq(exp[0]), "segment #{i} min.x"
    result[i].dx.should eq(exp[1]), "segment #{i} dx"
  end
end

describe "Layout parity with Go" do
  describe "Length constraints" do
    cases = [
      {flex: FXL, width: 1, constraints: [LE.new(0)], expected: "a"},
      {flex: FXL, width: 1, constraints: [LE.new(1)], expected: "a"},
      {flex: FXL, width: 2, constraints: [LE.new(0)], expected: "aa"},
      {flex: FXL, width: 2, constraints: [LE.new(1), LE.new(0)], expected: "ab"},
      {flex: FXL, width: 2, constraints: [LE.new(1), LE.new(1)], expected: "ab"},
      {flex: FXL, width: 2, constraints: [LE.new(2), LE.new(0)], expected: "aa"},
      {flex: FXL, width: 3, constraints: [LE.new(2), LE.new(2)], expected: "aab"},
      {flex: FXS, width: 100, constraints: [LE.new(25), LE.new(25)], expected: "a" * 25 + "b" * 25 + " " * 50},
      {flex: FXE, width: 100, constraints: [LE.new(25), LE.new(25)], expected: " " * 50 + "a" * 25 + "b" * 25},
      {flex: FXC, width: 100, constraints: [LE.new(25), LE.new(25)], expected: " " * 25 + "a" * 25 + "b" * 25 + " " * 25},
      {flex: FXSB, width: 100, constraints: [LE.new(25), LE.new(25)], expected: "a" * 25 + " " * 50 + "b" * 25},
      {flex: FXSE, width: 100, constraints: [LE.new(25), LE.new(25)], expected: " " * 17 + "a" * 25 + " " * 16 + "b" * 25 + " " * 17},
      {flex: FXSA, width: 100, constraints: [LE.new(25), LE.new(25)], expected: " " * 13 + "a" * 25 + " " * 24 + "b" * 25 + " " * 13},
    ]

    cases.each do |tc|
      it "Len #{tc[:flex]} w=#{tc[:width]}" do
        assert_layout(tc[:flex], tc[:constraints], tc[:width], tc[:expected])
      end
    end
  end

  describe "Percent constraints" do
    cases = [
      {flex: FXS, width: 10, constraints: [PE.new(0), PE.new(0)], expected: "          "},
      {flex: FXS, width: 10, constraints: [PE.new(0), PE.new(25)], expected: "bbb       "},
      {flex: FXS, width: 10, constraints: [PE.new(0), PE.new(50)], expected: "bbbbb     "},
      {flex: FXS, width: 10, constraints: [PE.new(0), PE.new(100)], expected: "bbbbbbbbbb"},
      {flex: FXS, width: 10, constraints: [PE.new(0), PE.new(200)], expected: "bbbbbbbbbb"},
      {flex: FXS, width: 10, constraints: [PE.new(10), PE.new(0)], expected: "a         "},
      {flex: FXS, width: 10, constraints: [PE.new(10), PE.new(25)], expected: "abbb      "},
      {flex: FXS, width: 10, constraints: [PE.new(10), PE.new(50)], expected: "abbbbb    "},
      {flex: FXS, width: 10, constraints: [PE.new(10), PE.new(100)], expected: "abbbbbbbbb"},
      {flex: FXS, width: 10, constraints: [PE.new(10), PE.new(200)], expected: "abbbbbbbbb"},
      {flex: FXS, width: 10, constraints: [PE.new(25), PE.new(0)], expected: "aaa       "},
      {flex: FXS, width: 10, constraints: [PE.new(25), PE.new(25)], expected: "aaabb     "},
      {flex: FXS, width: 10, constraints: [PE.new(25), PE.new(50)], expected: "aaabbbbb  "},
      {flex: FXS, width: 10, constraints: [PE.new(25), PE.new(100)], expected: "aaabbbbbbb"},
      {flex: FXS, width: 10, constraints: [PE.new(50), PE.new(0)], expected: "aaaaa     "},
      {flex: FXS, width: 10, constraints: [PE.new(50), PE.new(50)], expected: "aaaaabbbbb"},
      {flex: FXS, width: 10, constraints: [PE.new(50), PE.new(100)], expected: "aaaaabbbbb"},
      {flex: FXS, width: 10, constraints: [PE.new(100), PE.new(0)], expected: "aaaaaaaaaa"},
      {flex: FXS, width: 10, constraints: [PE.new(100), PE.new(50)], expected: "aaaaabbbbb"},
      {flex: FXS, width: 10, constraints: [PE.new(100), PE.new(100)], expected: "aaaaabbbbb"},
      {flex: FXS, width: 10, constraints: [PE.new(100), PE.new(200)], expected: "aaaaabbbbb"},
      {flex: FXSB, width: 10, constraints: [PE.new(0), PE.new(0)], expected: "          "},
      {flex: FXSB, width: 10, constraints: [PE.new(0), PE.new(25)], expected: "        bb"},
      {flex: FXSB, width: 10, constraints: [PE.new(0), PE.new(50)], expected: "     bbbbb"},
      {flex: FXSB, width: 10, constraints: [PE.new(0), PE.new(100)], expected: "bbbbbbbbbb"},
      {flex: FXSB, width: 10, constraints: [PE.new(10), PE.new(0)], expected: "a         "},
      {flex: FXSB, width: 10, constraints: [PE.new(10), PE.new(25)], expected: "a       bb"},
      {flex: FXSB, width: 10, constraints: [PE.new(10), PE.new(50)], expected: "a    bbbbb"},
      {flex: FXSB, width: 10, constraints: [PE.new(10), PE.new(100)], expected: "abbbbbbbbb"},
      {flex: FXSB, width: 10, constraints: [PE.new(25), PE.new(0)], expected: "aaa       "},
      {flex: FXSB, width: 10, constraints: [PE.new(25), PE.new(25)], expected: "aaa     bb"},
      {flex: FXSB, width: 10, constraints: [PE.new(25), PE.new(50)], expected: "aaa  bbbbb"},
      {flex: FXSB, width: 10, constraints: [PE.new(25), PE.new(100)], expected: "aaabbbbbbb"},
      {flex: FXL, width: 10, constraints: [PE.new(25), PE.new(200)], expected: "aaabbbbbbb"},
      {flex: FXSB, width: 10, constraints: [PE.new(50), PE.new(0)], expected: "aaaaa     "},
      {flex: FXSB, width: 10, constraints: [PE.new(50), PE.new(50)], expected: "aaaaabbbbb"},
      {flex: FXSB, width: 10, constraints: [PE.new(100), PE.new(0)], expected: "aaaaaaaaaa"},
      {flex: FXSB, width: 10, constraints: [PE.new(100), PE.new(50)], expected: "aaaaabbbbb"},
    ]

    cases.each do |tc|
      it "Percent w=#{tc[:width]}" do
        assert_layout(tc[:flex], tc[:constraints], tc[:width], tc[:expected])
      end
    end
  end

  describe "Ratio constraints" do
    cases = [
      {flex: FXL, width: 1, constraints: [RA.new(0, 1)], expected: "a"},
      {flex: FXL, width: 2, constraints: [RA.new(0, 1)], expected: "aa"},
      {flex: FXL, width: 10, constraints: [RA.new(0, 1), RA.new(0, 1)], expected: "bbbbbbbbbb"},
      {flex: FXL, width: 10, constraints: [RA.new(1, 10), RA.new(0, 1)], expected: "abbbbbbbbb"},
      {flex: FXL, width: 10, constraints: [RA.new(1, 4), RA.new(0, 1)], expected: "aaabbbbbbb"},
      {flex: FXL, width: 10, constraints: [RA.new(1, 2), RA.new(0, 1)], expected: "aaaaabbbbb"},
      {flex: FXL, width: 10, constraints: [RA.new(1, 1), RA.new(0, 1)], expected: "aaaaaaaaaa"},
      {flex: FXS, width: 10, constraints: [RA.new(0, 1), RA.new(0, 1)], expected: "          "},
      {flex: FXS, width: 10, constraints: [RA.new(0, 1), RA.new(1, 4)], expected: "bbb       "},
      {flex: FXS, width: 10, constraints: [RA.new(0, 1), RA.new(1, 2)], expected: "bbbbb     "},
      {flex: FXS, width: 10, constraints: [RA.new(0, 1), RA.new(1, 1)], expected: "bbbbbbbbbb"},
      {flex: FXS, width: 10, constraints: [RA.new(1, 10), RA.new(0, 1)], expected: "a         "},
      {flex: FXS, width: 10, constraints: [RA.new(1, 10), RA.new(1, 4)], expected: "abbb      "},
      {flex: FXS, width: 10, constraints: [RA.new(1, 10), RA.new(1, 2)], expected: "abbbbb    "},
      {flex: FXS, width: 10, constraints: [RA.new(1, 10), RA.new(1, 1)], expected: "abbbbbbbbb"},
      {flex: FXS, width: 10, constraints: [RA.new(1, 4), RA.new(0, 1)], expected: "aaa       "},
      {flex: FXS, width: 10, constraints: [RA.new(1, 4), RA.new(1, 4)], expected: "aaabb     "},
      {flex: FXS, width: 10, constraints: [RA.new(1, 4), RA.new(1, 2)], expected: "aaabbbbb  "},
      {flex: FXS, width: 10, constraints: [RA.new(1, 4), RA.new(1, 1)], expected: "aaabbbbbbb"},
      {flex: FXS, width: 10, constraints: [RA.new(1, 2), RA.new(0, 1)], expected: "aaaaa     "},
      {flex: FXS, width: 10, constraints: [RA.new(1, 2), RA.new(1, 2)], expected: "aaaaabbbbb"},
      {flex: FXS, width: 10, constraints: [RA.new(1, 1), RA.new(0, 1)], expected: "aaaaaaaaaa"},
    ]

    cases.each do |tc|
      it "Ratio w=#{tc[:width]}" do
        assert_layout(tc[:flex], tc[:constraints], tc[:width], tc[:expected])
      end
    end
  end

  describe "Edge cases" do
    it "50% 50% min(0) vertical" do
      result = Ultraviolet::Layout.vertical(PE.new(50), PE.new(50), MI.new(0)).split(Ultraviolet.rect(0, 0, 1, 1))
      result[0].dy.should eq(1)
      result[1].dy.should eq(0)
      result[2].dy.should eq(0)
    end

    it "max(1) 99% min(0) vertical" do
      result = Ultraviolet::Layout.vertical(MA.new(1), PE.new(99), MI.new(0)).split(Ultraviolet.rect(0, 0, 1, 1))
      result[0].dy.should eq(0)
      result[1].dy.should eq(1)
      result[2].dy.should eq(0)
    end

    it "min(1) len(0) min(1) horizontal" do
      result = Ultraviolet::Layout.horizontal(MI.new(1), LE.new(0), MI.new(1)).split(Ultraviolet.rect(0, 0, 1, 1))
      result[0].dx.should eq(1)
      result[1].dx.should eq(0)
      result[2].dx.should eq(0)
    end
  end

  describe "Flex spacing" do
    it "FlexStart spacing=2" do
      assert_ranges(FXS, [LE.new(20), LE.new(20), LE.new(20)], 100, [[0, 20], [22, 20], [44, 20]])
    end

    it "FlexStart spacing=-1" do
      assert_ranges(FXS, [LE.new(20), LE.new(20), LE.new(20)], 100, [[0, 20], [19, 20], [38, 20]])
    end

    it "FlexCenter spacing=2" do
      assert_ranges(FXC, [LE.new(20), LE.new(20), LE.new(20)], 100, [[18, 20], [40, 20], [62, 20]])
    end

    it "FlexEnd spacing=2" do
      assert_ranges(FXE, [LE.new(20), LE.new(20), LE.new(20)], 100, [[36, 20], [58, 20], [80, 20]])
    end

    it "FlexLegacy spacing=2" do
      assert_ranges(FXL, [LE.new(20), LE.new(20), LE.new(20)], 100, [[0, 20], [22, 20], [44, 56]])
    end
  end
end
