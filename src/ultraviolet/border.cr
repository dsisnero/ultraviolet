module Ultraviolet
  struct Side
    property content : String
    property style : Style
    property link : Link

    def initialize(
      @content : String = "",
      @style : Style = Style.new,
      @link : Link = Link.new,
    )
    end
  end

  struct Border
    property top : Side
    property bottom : Side
    property left : Side
    property right : Side
    property top_left : Side
    property top_right : Side
    property bottom_left : Side
    property bottom_right : Side

    def initialize(
      @top : Side = Side.new,
      @bottom : Side = Side.new,
      @left : Side = Side.new,
      @right : Side = Side.new,
      @top_left : Side = Side.new,
      @top_right : Side = Side.new,
      @bottom_left : Side = Side.new,
      @bottom_right : Side = Side.new,
    )
    end

    def style(style : Style) : Border
      border = self
      border.top.style = style
      border.bottom.style = style
      border.left.style = style
      border.right.style = style
      border.top_left.style = style
      border.top_right.style = style
      border.bottom_left.style = style
      border.bottom_right.style = style
      border
    end

    def link(link : Link) : Border
      border = self
      border.top.link = link
      border.bottom.link = link
      border.left.link = link
      border.right.link = link
      border.top_left.link = link
      border.top_right.link = link
      border.bottom_left.link = link
      border.bottom_right.link = link
      border
    end

    def draw(scr : Screen, area : Rectangle) : Nil
      y = area.min.y
      while y < area.max.y
        x = area.min.x
        while x < area.max.x
          cell = Ultraviolet.border_cell(scr, border_side(area, x, y))
          scr.set_cell(x, y, cell) if cell
          x += 1
        end
        y += 1
      end
    end

    private def border_side(area : Rectangle, x : Int32, y : Int32) : Side?
      if y == area.min.y
        return top_left if x == area.min.x
        return top_right if x == area.max.x - 1
        return top
      end

      if y == area.max.y - 1
        return bottom_left if x == area.min.x
        return bottom_right if x == area.max.x - 1
        return bottom
      end

      return left if x == area.min.x
      return right if x == area.max.x - 1
      nil
    end
  end

  def self.normal_border : Border
    Border.new(
      top: Side.new("─"),
      bottom: Side.new("─"),
      left: Side.new("│"),
      right: Side.new("│"),
      top_left: Side.new("┌"),
      top_right: Side.new("┐"),
      bottom_left: Side.new("└"),
      bottom_right: Side.new("┘")
    )
  end

  def self.rounded_border : Border
    Border.new(
      top: Side.new("─"),
      bottom: Side.new("─"),
      left: Side.new("│"),
      right: Side.new("│"),
      top_left: Side.new("╭"),
      top_right: Side.new("╮"),
      bottom_left: Side.new("╰"),
      bottom_right: Side.new("╯")
    )
  end

  def self.block_border : Border
    Border.new(
      top: Side.new("█"),
      bottom: Side.new("█"),
      left: Side.new("█"),
      right: Side.new("█"),
      top_left: Side.new("█"),
      top_right: Side.new("█"),
      bottom_left: Side.new("█"),
      bottom_right: Side.new("█")
    )
  end

  def self.outer_half_block_border : Border
    Border.new(
      top: Side.new("▀"),
      bottom: Side.new("▄"),
      left: Side.new("▌"),
      right: Side.new("▐"),
      top_left: Side.new("▛"),
      top_right: Side.new("▜"),
      bottom_left: Side.new("▙"),
      bottom_right: Side.new("▟")
    )
  end

  def self.inner_half_block_border : Border
    Border.new(
      top: Side.new("▄"),
      bottom: Side.new("▀"),
      left: Side.new("▐"),
      right: Side.new("▌"),
      top_left: Side.new("▗"),
      top_right: Side.new("▖"),
      bottom_left: Side.new("▝"),
      bottom_right: Side.new("▘")
    )
  end

  def self.thick_border : Border
    Border.new(
      top: Side.new("━"),
      bottom: Side.new("━"),
      left: Side.new("┃"),
      right: Side.new("┃"),
      top_left: Side.new("┏"),
      top_right: Side.new("┓"),
      bottom_left: Side.new("┗"),
      bottom_right: Side.new("┛")
    )
  end

  def self.double_border : Border
    Border.new(
      top: Side.new("═"),
      bottom: Side.new("═"),
      left: Side.new("║"),
      right: Side.new("║"),
      top_left: Side.new("╔"),
      top_right: Side.new("╗"),
      bottom_left: Side.new("╚"),
      bottom_right: Side.new("╝")
    )
  end

  def self.hidden_border : Border
    Border.new(
      top: Side.new(" "),
      bottom: Side.new(" "),
      left: Side.new(" "),
      right: Side.new(" "),
      top_left: Side.new(" "),
      top_right: Side.new(" "),
      bottom_left: Side.new(" "),
      bottom_right: Side.new(" ")
    )
  end

  def self.markdown_border : Border
    Border.new(
      left: Side.new("|"),
      right: Side.new("|"),
      top_left: Side.new("|"),
      top_right: Side.new("|"),
      bottom_left: Side.new("|"),
      bottom_right: Side.new("|")
    )
  end

  def self.ascii_border : Border
    Border.new(
      top: Side.new("-"),
      bottom: Side.new("-"),
      left: Side.new("|"),
      right: Side.new("|"),
      top_left: Side.new("+"),
      top_right: Side.new("+"),
      bottom_left: Side.new("+"),
      bottom_right: Side.new("+")
    )
  end

  def self.border_cell(scr : Screen, side : Side?) : Cell?
    return nil if side.nil?
    cell = Cell.new_cell(scr.width_method, side.content)
    cell.style = side.style
    cell.link = side.link
    cell
  end

  # Border constructor functions matching Go ultraviolet API

  def self.normal_border : Border
    Border.new(
      top: Side.new("─"),
      bottom: Side.new("─"),
      left: Side.new("│"),
      right: Side.new("│"),
      top_left: Side.new("┌"),
      top_right: Side.new("┐"),
      bottom_left: Side.new("└"),
      bottom_right: Side.new("┘")
    )
  end

  def self.rounded_border : Border
    Border.new(
      top: Side.new("─"),
      bottom: Side.new("─"),
      left: Side.new("│"),
      right: Side.new("│"),
      top_left: Side.new("╭"),
      top_right: Side.new("╮"),
      bottom_left: Side.new("╰"),
      bottom_right: Side.new("╯")
    )
  end

  def self.block_border : Border
    Border.new(
      top: Side.new("█"),
      bottom: Side.new("█"),
      left: Side.new("█"),
      right: Side.new("█"),
      top_left: Side.new("█"),
      top_right: Side.new("█"),
      bottom_left: Side.new("█"),
      bottom_right: Side.new("█")
    )
  end

  def self.outer_half_block_border : Border
    Border.new(
      top: Side.new("▀"),
      bottom: Side.new("▄"),
      left: Side.new("▌"),
      right: Side.new("▐"),
      top_left: Side.new("▛"),
      top_right: Side.new("▜"),
      bottom_left: Side.new("▙"),
      bottom_right: Side.new("▟")
    )
  end

  def self.inner_half_block_border : Border
    Border.new(
      top: Side.new("▄"),
      bottom: Side.new("▀"),
      left: Side.new("▐"),
      right: Side.new("▌"),
      top_left: Side.new("▗"),
      top_right: Side.new("▖"),
      bottom_left: Side.new("▝"),
      bottom_right: Side.new("▘")
    )
  end

  def self.thick_border : Border
    Border.new(
      top: Side.new("━"),
      bottom: Side.new("━"),
      left: Side.new("┃"),
      right: Side.new("┃"),
      top_left: Side.new("┏"),
      top_right: Side.new("┓"),
      bottom_left: Side.new("┗"),
      bottom_right: Side.new("┛")
    )
  end

  def self.double_border : Border
    Border.new(
      top: Side.new("═"),
      bottom: Side.new("═"),
      left: Side.new("║"),
      right: Side.new("║"),
      top_left: Side.new("╔"),
      top_right: Side.new("╗"),
      bottom_left: Side.new("╚"),
      bottom_right: Side.new("╝")
    )
  end

  def self.hidden_border : Border
    Border.new(
      top: Side.new(" "),
      bottom: Side.new(" "),
      left: Side.new(" "),
      right: Side.new(" "),
      top_left: Side.new(" "),
      top_right: Side.new(" "),
      bottom_left: Side.new(" "),
      bottom_right: Side.new(" ")
    )
  end

  def self.markdown_border : Border
    Border.new(
      top: Side.new(""),
      bottom: Side.new(""),
      left: Side.new("|"),
      right: Side.new("|"),
      top_left: Side.new("|"),
      top_right: Side.new("|"),
      bottom_left: Side.new("|"),
      bottom_right: Side.new("|")
    )
  end

  def self.ascii_border : Border
    Border.new(
      top: Side.new("-"),
      bottom: Side.new("-"),
      left: Side.new("|"),
      right: Side.new("|"),
      top_left: Side.new("+"),
      top_right: Side.new("+"),
      bottom_left: Side.new("+"),
      bottom_right: Side.new("+")
    )
  end
end
