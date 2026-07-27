require "./spec_helper"

describe "Layout::Flex" do
  it "defines flex strategies" do
    Ultraviolet::Layout::Flex::Start.value.should eq(0)
    Ultraviolet::Layout::Flex::Legacy.value.should eq(1)
    Ultraviolet::Layout::Flex::End.value.should eq(2)
    Ultraviolet::Layout::Flex::Center.value.should eq(3)
    Ultraviolet::Layout::Flex::SpaceBetween.value.should eq(4)
    Ultraviolet::Layout::Flex::SpaceEvenly.value.should eq(5)
    Ultraviolet::Layout::Flex::SpaceAround.value.should eq(6)
  end
end

describe "Layout::Direction" do
  it "defines directions" do
    Ultraviolet::Layout::Direction::Vertical.value.should eq(0)
    Ultraviolet::Layout::Direction::Horizontal.value.should eq(1)
  end
end

describe "Layout::Padding" do
  it "builds from CSS shorthand" do
    Ultraviolet::Layout.pad.should eq(Ultraviolet::Layout::Padding.new(0, 0, 0, 0))
    Ultraviolet::Layout.pad(2).should eq(Ultraviolet::Layout::Padding.new(2, 2, 2, 2))
    Ultraviolet::Layout.pad(1, 2).should eq(Ultraviolet::Layout::Padding.new(1, 2, 1, 2))
    Ultraviolet::Layout.pad(1, 2, 3, 4).should eq(Ultraviolet::Layout::Padding.new(1, 2, 3, 4))
  end

  it "applies padding to area" do
    area = Ultraviolet.rect(0, 0, 100, 50)
    p = Ultraviolet::Layout::Padding.new(1, 2, 3, 4)
    inner = p.apply(area)
    inner.min.x.should eq(4)
    inner.min.y.should eq(1)
    inner.dx.should eq(94)
    inner.dy.should eq(46)
  end
end

describe "Layout::Constraint" do
  it "creates Min constraint" do
    c = Ultraviolet::Layout::Min.new(10)
    c.value.should eq(10)
  end

  it "creates Max constraint" do
    c = Ultraviolet::Layout::Max.new(20)
    c.value.should eq(20)
  end

  it "creates Len constraint" do
    c = Ultraviolet::Layout::Len.new(15)
    c.value.should eq(15)
  end

  it "creates Percent constraint" do
    c = Ultraviolet::Layout::Percent.new(50)
    c.value.should eq(50)
  end

  it "creates Ratio constraint" do
    c = Ultraviolet::Layout::Ratio.new(1, 3)
    c.num.should eq(1)
    c.den.should eq(3)
  end

  it "creates Fill constraint" do
    c = Ultraviolet::Layout::Fill.new(1)
    c.value.should eq(1)
  end
end

describe "Layout" do
  it "creates vertical layout" do
    l = Ultraviolet::Layout.vertical(Ultraviolet::Layout::Len.new(5), Ultraviolet::Layout::Fill.new(1))
    l.direction.should eq(Ultraviolet::Layout::Direction::Vertical)
    l.constraints.size.should eq(2)
  end

  it "creates horizontal layout" do
    l = Ultraviolet::Layout.horizontal(Ultraviolet::Layout::Len.new(5), Ultraviolet::Layout::Fill.new(1))
    l.direction.should eq(Ultraviolet::Layout::Direction::Horizontal)
    l.constraints.size.should eq(2)
  end

  it "splits with len constraints (flex start)" do
    area = Ultraviolet.rect(0, 0, 100, 1)
    result = Ultraviolet::Layout.horizontal(
      Ultraviolet::Layout::Len.new(25),
      Ultraviolet::Layout::Len.new(25)
    ).with_flex(Ultraviolet::Layout::Flex::Start).split(area)

    result.size.should eq(2)
    result[0].dx.should eq(25)
    result[0].min.x.should eq(0)
    result[1].dx.should eq(25)
    result[1].min.x.should eq(25)
  end

  it "splits with len constraints (legacy)" do
    area = Ultraviolet.rect(0, 0, 100, 1)
    result = Ultraviolet::Layout.horizontal(
      Ultraviolet::Layout::Len.new(25),
      Ultraviolet::Layout::Len.new(25)
    ).with_flex(Ultraviolet::Layout::Flex::Legacy).split(area)

    result.size.should eq(2)
    result[0].dx.should eq(25)
    result[1].min.x.should eq(25)
  end

  it "splits with len constraints (end)" do
    area = Ultraviolet.rect(0, 0, 100, 1)
    result = Ultraviolet::Layout.horizontal(
      Ultraviolet::Layout::Len.new(25),
      Ultraviolet::Layout::Len.new(25)
    ).with_flex(Ultraviolet::Layout::Flex::End).split(area)

    result.size.should eq(2)
    result[0].min.x.should eq(50)
    result[0].dx.should eq(25)
    result[1].min.x.should eq(75)
    result[1].dx.should eq(25)
  end

  it "splits with len constraints (center)" do
    area = Ultraviolet.rect(0, 0, 100, 1)
    result = Ultraviolet::Layout.horizontal(
      Ultraviolet::Layout::Len.new(25),
      Ultraviolet::Layout::Len.new(25)
    ).with_flex(Ultraviolet::Layout::Flex::Center).split(area)

    result.size.should eq(2)
    result[0].min.x.should eq(25)
    result[0].dx.should eq(25)
    result[1].min.x.should eq(50)
    result[1].dx.should eq(25)
  end

  it "splits with percent constraints" do
    area = Ultraviolet.rect(0, 0, 100, 1)
    result = Ultraviolet::Layout.horizontal(
      Ultraviolet::Layout::Percent.new(25),
      Ultraviolet::Layout::Percent.new(25)
    ).with_flex(Ultraviolet::Layout::Flex::Start).split(area)

    result.size.should eq(2)
    result[0].dx.should eq(25)
    result[1].dx.should eq(25)
  end

  it "handles spacing" do
    area = Ultraviolet.rect(0, 0, 100, 1)
    result = Ultraviolet::Layout.horizontal(
      Ultraviolet::Layout::Len.new(20),
      Ultraviolet::Layout::Len.new(20),
      Ultraviolet::Layout::Len.new(20)
    ).with_flex(Ultraviolet::Layout::Flex::Start).with_spacing(2).split(area)

    result.size.should eq(3)
    result[0].dx.should eq(20)
    result[1].min.x.should eq(22)
    result[1].dx.should eq(20)
    result[2].min.x.should eq(44)
    result[2].dx.should eq(20)
  end

  it "uses builder methods" do
    l = Ultraviolet::Layout
      .horizontal(Ultraviolet::Layout::Len.new(10))
      .with_direction(Ultraviolet::Layout::Direction::Vertical)
      .with_padding(Ultraviolet::Layout.pad(1))
      .with_spacing(0)
      .with_flex(Ultraviolet::Layout::Flex::Start)

    l.direction.should eq(Ultraviolet::Layout::Direction::Vertical)
    l.padding.should eq(Ultraviolet::Layout::Padding.new(1, 1, 1, 1))
    l.spacing.should eq(0)
    l.flex.should eq(Ultraviolet::Layout::Flex::Start)
  end

  it "splits vertically" do
    area = Ultraviolet.rect(0, 0, 1, 100)
    result = Ultraviolet::Layout.vertical(
      Ultraviolet::Layout::Len.new(30),
      Ultraviolet::Layout::Fill.new(1)
    ).with_flex(Ultraviolet::Layout::Flex::Start).split(area)

    result.size.should eq(2)
    result[0].dy.should eq(30)
    result[0].min.y.should eq(0)
  end
end
