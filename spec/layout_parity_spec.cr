require "./spec_helper"

def layout_assert(flex, constraints, width, expected)
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

L = Ultraviolet::Layout::Len
M = Ultraviolet::Layout::Max
N = Ultraviolet::Layout::Min
P = Ultraviolet::Layout::Percent
R = Ultraviolet::Layout::Ratio
FXL = Ultraviolet::Layout::Flex::Legacy
FXS = Ultraviolet::Layout::Flex::Start
FXE = Ultraviolet::Layout::Flex::End
FXC = Ultraviolet::Layout::Flex::Center
FXSB = Ultraviolet::Layout::Flex::SpaceBetween
FXSE = Ultraviolet::Layout::Flex::SpaceEvenly
FXSA = Ultraviolet::Layout::Flex::SpaceAround

describe "Layout parity with Go" do

  describe "Length" do
    it "Legacy 2x Len(1)+Len(0)" do; layout_assert(FXL, [L.new(1), L.new(0)], 2, "ab"); end
    it "Legacy 2x Len(1)+Len(1)" do; layout_assert(FXL, [L.new(1), L.new(1)], 2, "ab"); end
    it "Legacy 3x Len(2)+Len(2)" do; layout_assert(FXL, [L.new(2), L.new(2)], 3, "aab"); end
    it "Start 100 Len(25)+Len(25)" do; layout_assert(FXS, [L.new(25), L.new(25)], 100, "a"*25 + "b"*25 + " "*50); end
    it "End 100 Len(25)+Len(25)" do; layout_assert(FXE, [L.new(25), L.new(25)], 100, " "*50 + "a"*25 + "b"*25); end
    it "Center 100 Len(25)+Len(25)" do; layout_assert(FXC, [L.new(25), L.new(25)], 100, " "*25 + "a"*25 + "b"*25 + " "*25); end
    it "SpaceBetween 100 Len(25)+Len(25)" do; layout_assert(FXSB, [L.new(25), L.new(25)], 100, "a"*25 + " "*50 + "b"*25); end
  end

  describe "Percent" do
    it "Start 10 P(0)+P(25)" do; layout_assert(FXS, [P.new(0), P.new(25)], 10, "bbb       "); end
    it "Start 10 P(0)+P(50)" do; layout_assert(FXS, [P.new(0), P.new(50)], 10, "bbbbb     "); end
    it "Start 10 P(0)+P(100)" do; layout_assert(FXS, [P.new(0), P.new(100)], 10, "bbbbbbbbbb"); end
    it "Start 10 P(10)+P(0)" do; layout_assert(FXS, [P.new(10), P.new(0)], 10, "a         "); end
    it "Start 10 P(10)+P(50)" do; layout_assert(FXS, [P.new(10), P.new(50)], 10, "abbbbb    "); end
    it "Start 10 P(25)+P(0)" do; layout_assert(FXS, [P.new(25), P.new(0)], 10, "aaa       "); end
    it "Start 10 P(25)+P(25)" do; layout_assert(FXS, [P.new(25), P.new(25)], 10, "aaabb     "); end
    it "Start 10 P(25)+P(50)" do; layout_assert(FXS, [P.new(25), P.new(50)], 10, "aaabbbbb  "); end
    it "Start 10 P(50)+P(0)" do; layout_assert(FXS, [P.new(50), P.new(0)], 10, "aaaaa     "); end
    it "Start 10 P(50)+P(50)" do; layout_assert(FXS, [P.new(50), P.new(50)], 10, "aaaaabbbbb"); end
    it "Start 10 P(100)+P(0)" do; layout_assert(FXS, [P.new(100), P.new(0)], 10, "aaaaaaaaaa"); end
    it "SpaceBetween 10 P(0)+P(25)" do; layout_assert(FXSB, [P.new(0), P.new(25)], 10, "        bb"); end
    it "SpaceBetween 10 P(10)+P(0)" do; layout_assert(FXSB, [P.new(10), P.new(0)], 10, "a         "); end
    it "SpaceBetween 10 P(25)+P(25)" do; layout_assert(FXSB, [P.new(25), P.new(25)], 10, "aaa     bb"); end
    it "SpaceBetween 10 P(50)+P(50)" do; layout_assert(FXSB, [P.new(50), P.new(50)], 10, "aaaaabbbbb"); end
    it "Legacy 10 P(25)+P(200)" do; layout_assert(FXL, [P.new(25), P.new(200)], 10, "aaabbbbbbb"); end
  end

  describe "Ratio" do
    it "Legacy 10 R(1,10)+R(0,1)" do; layout_assert(FXL, [R.new(1, 10), R.new(0, 1)], 10, "abbbbbbbbb"); end
    it "Legacy 10 R(1,4)+R(0,1)" do; layout_assert(FXL, [R.new(1, 4), R.new(0, 1)], 10, "aaabbbbbbb"); end
    it "Legacy 10 R(1,2)+R(0,1)" do; layout_assert(FXL, [R.new(1, 2), R.new(0, 1)], 10, "aaaaabbbbb"); end
    it "Start 10 R(0,1)+R(1,4)" do; layout_assert(FXS, [R.new(0, 1), R.new(1, 4)], 10, "bbb       "); end
    it "Start 10 R(1,10)+R(0,1)" do; layout_assert(FXS, [R.new(1, 10), R.new(0, 1)], 10, "a         "); end
    it "Start 10 R(1,4)+R(0,1)" do; layout_assert(FXS, [R.new(1, 4), R.new(0, 1)], 10, "aaa       "); end
    it "Start 10 R(1,4)+R(1,4)" do; layout_assert(FXS, [R.new(1, 4), R.new(1, 4)], 10, "aaabb     "); end
    it "Start 10 R(1,2)+R(0,1)" do; layout_assert(FXS, [R.new(1, 2), R.new(0, 1)], 10, "aaaaa     "); end
    it "Start 10 R(1,2)+R(1,2)" do; layout_assert(FXS, [R.new(1, 2), R.new(1, 2)], 10, "aaaaabbbbb"); end
    it "Start 10 R(1,1)+R(0,1)" do; layout_assert(FXS, [R.new(1, 1), R.new(0, 1)], 10, "aaaaaaaaaa"); end
  end
end
