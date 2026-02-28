require "./spec_helper"

describe "Borders" do
  it "constructs borders" do
    border = Ultraviolet.normal_border
    border.top.content.should eq("─")
    border.bottom.content.should eq("─")
    border.left.content.should eq("│")
    border.right.content.should eq("│")
    border.top_left.content.should eq("┌")
    border.top_right.content.should eq("┐")
    border.bottom_left.content.should eq("└")
    border.bottom_right.content.should eq("┘")

    border = Ultraviolet.rounded_border
    border.top_left.content.should eq("╭")
    border.top_right.content.should eq("╮")
    border.bottom_left.content.should eq("╰")
    border.bottom_right.content.should eq("╯")

    border = Ultraviolet.block_border
    border.top.content.should eq("█")
    border.bottom.content.should eq("█")
    border.left.content.should eq("█")
    border.right.content.should eq("█")
    border.top_left.content.should eq("█")
    border.top_right.content.should eq("█")
    border.bottom_left.content.should eq("█")
    border.bottom_right.content.should eq("█")

    border = Ultraviolet.outer_half_block_border
    border.top.content.should eq("▀")
    border.bottom.content.should eq("▄")
    border.left.content.should eq("▌")
    border.right.content.should eq("▐")

    border = Ultraviolet.inner_half_block_border
    border.top.content.should eq("▄")
    border.bottom.content.should eq("▀")
    border.left.content.should eq("▐")
    border.right.content.should eq("▌")

    border = Ultraviolet.thick_border
    border.top_left.content.should eq("┏")
    border.top_right.content.should eq("┓")
    border.bottom_left.content.should eq("┗")
    border.bottom_right.content.should eq("┛")

    border = Ultraviolet.double_border
    border.top.content.should eq("═")
    border.bottom.content.should eq("═")
    border.left.content.should eq("║")
    border.right.content.should eq("║")
    border.top_left.content.should eq("╔")
    border.top_right.content.should eq("╗")
    border.bottom_left.content.should eq("╚")
    border.bottom_right.content.should eq("╝")

    border = Ultraviolet.hidden_border
    border.top.content.should eq(" ")
    border.bottom.content.should eq(" ")
    border.left.content.should eq(" ")
    border.right.content.should eq(" ")
    border.top_left.content.should eq(" ")
    border.top_right.content.should eq(" ")
    border.bottom_left.content.should eq(" ")
    border.bottom_right.content.should eq(" ")

    border = Ultraviolet.markdown_border
    border.top.content.should eq("")
    border.bottom.content.should eq("")
    border.left.content.should eq("|")
    border.right.content.should eq("|")
    border.top_left.content.should eq("|")
    border.top_right.content.should eq("|")
    border.bottom_left.content.should eq("|")
    border.bottom_right.content.should eq("|")

    border = Ultraviolet.ascii_border
    border.top.content.should eq("-")
    border.bottom.content.should eq("-")
    border.left.content.should eq("|")
    border.right.content.should eq("|")
    border.top_left.content.should eq("+")
    border.top_right.content.should eq("+")
    border.bottom_left.content.should eq("+")
    border.bottom_right.content.should eq("+")
  end

  it "applies styles and links without mutating base" do
    base = Ultraviolet.normal_border
    style = Ultraviolet::Style.new(attrs: Ultraviolet::Attr::BOLD)
    link = Ultraviolet.new_link("https://example.com", ["id=1"])

    border = base.style(style).link(link)

    border.top.style.should eq(style)
    border.bottom.style.should eq(style)
    border.left.style.should eq(style)
    border.right.style.should eq(style)
    border.top_left.style.should eq(style)
    border.top_right.style.should eq(style)
    border.bottom_left.style.should eq(style)
    border.bottom_right.style.should eq(style)

    border.top.link.should eq(link)
    border.bottom.link.should eq(link)
    border.left.link.should eq(link)
    border.right.link.should eq(link)
    border.top_left.link.should eq(link)
    border.top_right.link.should eq(link)
    border.bottom_left.link.should eq(link)
    border.bottom_right.link.should eq(link)

    base.top.style.should eq(Ultraviolet::Style.new)
    base.top.link.should eq(Ultraviolet::Link.new)
  end

  it "draws borders" do
    dst = Ultraviolet::ScreenBuffer.new(20, 10)
    area = Ultraviolet.rect(1, 1, 6, 4)
    Ultraviolet.normal_border.draw(dst, area)

    dst.cell_at(1, 1).try(&.string).should eq("┌")
    dst.cell_at(6, 1).try(&.string).should eq("┐")
    dst.cell_at(1, 4).try(&.string).should eq("└")
    dst.cell_at(6, 4).try(&.string).should eq("┘")

    (2..5).each do |x|
      dst.cell_at(x, 1).try(&.string).should eq("─")
      dst.cell_at(x, 4).try(&.string).should eq("─")
    end

    (2..3).each do |y|
      dst.cell_at(1, y).try(&.string).should eq("│")
      dst.cell_at(6, y).try(&.string).should eq("│")
    end

    (2..3).each do |y|
      (2..5).each do |x|
        dst.cell_at(x, y).try(&.string).should eq(" ")
      end
    end
  end

  it "draws hidden borders with style and link" do
    dst = Ultraviolet::ScreenBuffer.new(10, 6)
    area = Ultraviolet.rect(2, 2, 5, 3)
    style = Ultraviolet::Style.new(attrs: Ultraviolet::Attr::BOLD)
    link = Ultraviolet.new_link("https://example.com")
    border = Ultraviolet.hidden_border.style(style).link(link)
    border.draw(dst, area)

    check_pos = [
      {2, 2}, {6, 2}, {2, 4}, {6, 4},
      {3, 2}, {4, 2}, {5, 2},
      {3, 4}, {4, 4}, {5, 4},
      {2, 3}, {6, 3},
    ]

    check_pos.each do |(x, y)|
      cell = dst.cell_at(x, y)
      if cell
        cell.string.should eq(" ")
        cell.style.should eq(style)
        cell.link.should eq(link)
      else
        fail "expected cell at #{x},#{y}"
      end
    end

    cell = dst.cell_at(4, 3)
    if cell
      cell.string.should eq(" ")
      cell.style.should eq(Ultraviolet::Style.new)
      cell.link.should eq(Ultraviolet::Link.new)
    else
      fail "expected interior cell"
    end
  end

  it "handles small areas" do
    dst = Ultraviolet::ScreenBuffer.new(3, 3)
    border = Ultraviolet.normal_border

    border.draw(dst, Ultraviolet.rect(0, 0, 1, 1))
    dst.cell_at(0, 0).try(&.string).should eq("┌")

    border.draw(dst, Ultraviolet.rect(0, 1, 1, 2))
    dst.cell_at(0, 1).try(&.string).should eq("┌")
    dst.cell_at(0, 2).try(&.string).should eq("└")
  end

  it "applies style and link to border like Go TestBorderStyleAndLink" do
    style = Ultraviolet::Style.new(fg: Ultraviolet::Color.new(255, 0, 0))
    link = Ultraviolet::Link.new("https://example.com")

    border = Ultraviolet.normal_border
      .style(style)
      .link(link)

    border.top.style.should eq(style)
    border.bottom.style.should eq(style)
    border.left.style.should eq(style)
    border.right.style.should eq(style)
    border.top_left.style.should eq(style)
    border.top_right.style.should eq(style)
    border.bottom_left.style.should eq(style)
    border.bottom_right.style.should eq(style)

    border.top.link.should eq(link)
    border.bottom.link.should eq(link)
    border.left.link.should eq(link)
    border.right.link.should eq(link)
    border.top_left.link.should eq(link)
    border.top_right.link.should eq(link)
    border.bottom_left.link.should eq(link)
    border.bottom_right.link.should eq(link)
  end

  it "draws normal border like Go TestBorderDrawNormal" do
    buffer = Ultraviolet::ScreenBuffer.new(10, 5)
    border = Ultraviolet.normal_border
    border.draw(buffer, Ultraviolet.rect(0, 0, 10, 5))

    # Check corners are drawn
    buffer.cell_at(0, 0).not_nil!.string.should eq("┌")
    buffer.cell_at(9, 0).not_nil!.string.should eq("┐")
    buffer.cell_at(0, 4).not_nil!.string.should eq("└")
    buffer.cell_at(9, 4).not_nil!.string.should eq("┘")

    # Check sides are drawn
    (1..8).each do |x|
      buffer.cell_at(x, 0).not_nil!.string.should eq("─")
      buffer.cell_at(x, 4).not_nil!.string.should eq("─")
    end

    (1..3).each do |y|
      buffer.cell_at(0, y).not_nil!.string.should eq("│")
      buffer.cell_at(9, y).not_nil!.string.should eq("│")
    end
  end

  it "draws hidden border with style and link like Go TestBorderDrawHiddenStyleLink" do
    buffer = Ultraviolet::ScreenBuffer.new(10, 5)
    style = Ultraviolet::Style.new(fg: Ultraviolet::Color.new(255, 0, 0))
    link = Ultraviolet::Link.new("https://example.com")

    border = Ultraviolet.hidden_border
      .style(style)
      .link(link)

    border.draw(buffer, Ultraviolet.rect(0, 0, 10, 5))

    # Hidden border should draw spaces with style and link
    cell = buffer.cell_at(0, 0)
    cell.should_not be_nil
    cell.not_nil!.string.should eq(" ")
    cell.not_nil!.style.fg.should eq(Ultraviolet::Color.new(255, 0, 0))
    cell.not_nil!.link.url.should eq("https://example.com")
  end

  it "draws borders on small areas like Go TestBorderDrawSmallAreas" do
    # Test 1x1 area
    buffer = Ultraviolet::ScreenBuffer.new(1, 1)
    border = Ultraviolet.normal_border
    border.draw(buffer, Ultraviolet.rect(0, 0, 1, 1))
    buffer.cell_at(0, 0).not_nil!.string.should eq("┌")

    # Test 2x2 area
    buffer = Ultraviolet::ScreenBuffer.new(2, 2)
    border = Ultraviolet.normal_border
    border.draw(buffer, Ultraviolet.rect(0, 0, 2, 2))
    buffer.cell_at(0, 0).not_nil!.string.should eq("┌")
    buffer.cell_at(1, 0).not_nil!.string.should eq("┐")
    buffer.cell_at(0, 1).not_nil!.string.should eq("└")
    buffer.cell_at(1, 1).not_nil!.string.should eq("┘")

    # Test 3x1 area (only top border)
    buffer = Ultraviolet::ScreenBuffer.new(3, 1)
    border = Ultraviolet.normal_border
    border.draw(buffer, Ultraviolet.rect(0, 0, 3, 1))
    buffer.cell_at(0, 0).not_nil!.string.should eq("┌")
    buffer.cell_at(1, 0).not_nil!.string.should eq("─")
    buffer.cell_at(2, 0).not_nil!.string.should eq("┐")
  end
end
