require "../src/ultraviolet"

# Port of upstream examples/advanced/splits/main.go.
#
# Renders a grid of cells, one per pair of layout constraints. Every cell shows
# its constraint pair as red / green / blue rectangles:
#
#   * red   - the left constraint of the pair
#   * green - `Min(0)`, filling the remaining space (dotted)
#   * blue  - the right constraint of the pair
module Splits
  alias Constraint = Ultraviolet::Layout::Constraint

  RED   = Ultraviolet::AnsiColor.basic(1)
  GREEN = Ultraviolet::AnsiColor.basic(2)
  BLUE  = Ultraviolet::AnsiColor.basic(4)

  record Example, name : String, constraints : Array(Constraint)

  private def self.constraints(*constraints : Constraint) : Array(Constraint)
    list = Array(Constraint).new(constraints.size)
    constraints.each { |constraint| list << constraint }
    list
  end

  EXAMPLES = [
    Example.new("Len", constraints(
      Ultraviolet::Layout::Len.new(0),
      Ultraviolet::Layout::Len.new(2),
      Ultraviolet::Layout::Len.new(3),
      Ultraviolet::Layout::Len.new(6),
      Ultraviolet::Layout::Len.new(10),
      Ultraviolet::Layout::Len.new(15),
    )),
    Example.new("Min", constraints(
      Ultraviolet::Layout::Min.new(0),
      Ultraviolet::Layout::Min.new(2),
      Ultraviolet::Layout::Min.new(3),
      Ultraviolet::Layout::Min.new(6),
      Ultraviolet::Layout::Min.new(10),
      Ultraviolet::Layout::Min.new(15),
    )),
    Example.new("Max", constraints(
      Ultraviolet::Layout::Max.new(0),
      Ultraviolet::Layout::Max.new(2),
      Ultraviolet::Layout::Max.new(3),
      Ultraviolet::Layout::Max.new(6),
      Ultraviolet::Layout::Max.new(10),
      Ultraviolet::Layout::Max.new(15),
    )),
    Example.new("Perc", constraints(
      Ultraviolet::Layout::Percent.new(0),
      Ultraviolet::Layout::Percent.new(25),
      Ultraviolet::Layout::Percent.new(50),
      Ultraviolet::Layout::Percent.new(75),
      Ultraviolet::Layout::Percent.new(100),
      Ultraviolet::Layout::Percent.new(150),
    )),
    Example.new("Ratio", constraints(
      Ultraviolet::Layout::Ratio.new(0, 4),
      Ultraviolet::Layout::Ratio.new(1, 4),
      Ultraviolet::Layout::Ratio.new(2, 4),
      Ultraviolet::Layout::Ratio.new(3, 4),
      Ultraviolet::Layout::Ratio.new(4, 4),
      Ultraviolet::Layout::Ratio.new(6, 4),
    )),
  ]

  HEADER = "Horizontal Layout Example. Press q to quit\n" \
           "Each line has 2 constraints, plus Min(0) to fill the remaining space.\n" \
           "E.g. the second line of the Len/Min box is [Len(2), Min(2), Min(0)]\n" \
           "Note: constraint labels that don't fit are truncated"

  def self.render(screen : Ultraviolet::Screen, area : Ultraviolet::Rectangle) : Nil
    # Header takes the first 7 rows; the grid gets what is left of `area`.
    text_rows = Ultraviolet::Layout.vertical(
      Ultraviolet::Layout::Len.new(7),
      Ultraviolet::Layout::Min.new(0),
    ).split(area)

    text_area = text_rows[0]
    area = text_rows[1]

    Ultraviolet::Screen::Context.new(screen)
      .draw_string_wrapped(HEADER, text_area.min.x, text_area.min.y)

    rows = Ultraviolet::Layout.vertical(
      Ultraviolet::Layout::Len.new(9),
      Ultraviolet::Layout::Len.new(9),
      Ultraviolet::Layout::Len.new(9),
      Ultraviolet::Layout::Len.new(9),
      Ultraviolet::Layout::Len.new(9),
      Ultraviolet::Layout::Min.new(0), # fills remaining space
    ).split(area)

    areas = [] of Ultraviolet::Rectangle

    rows.each do |row|
      cols = Ultraviolet::Layout.horizontal(
        Ultraviolet::Layout::Len.new(14),
        Ultraviolet::Layout::Len.new(14),
        Ultraviolet::Layout::Len.new(14),
        Ultraviolet::Layout::Len.new(14),
        Ultraviolet::Layout::Len.new(14),
        Ultraviolet::Layout::Min.new(0),
      ).split(row)

      # Ignore the trailing Min(0) column.
      areas.concat(cols[0, 5])
    end

    cartesian_product(EXAMPLES, EXAMPLES).each_with_index do |pair, i|
      left = pair[0]
      right = pair[1]

      render_example_combinations(
        screen,
        areas[i],
        "#{left.name} | #{right.name}",
        zip(left.constraints, right.constraints)
      )
    end
  end

  private def self.render_example_combinations(
    screen : Ultraviolet::Screen,
    area : Ultraviolet::Rectangle,
    title : String,
    constraints : Array({Constraint, Constraint}),
  ) : Nil
    row_constraints = Array(Constraint).new(constraints.size + 1) do
      Ultraviolet::Layout::Len.new(1)
    end

    rows = Ultraviolet::Layout::Splitter.new(
      direction: Ultraviolet::Layout::Direction::Vertical,
      constraints: row_constraints,
    ).with_padding(Ultraviolet::Layout.pad(1)).split(area)

    Ultraviolet::Screen::Context.new(screen)
      .draw_string(title, rows[0].min.x, rows[0].min.y - 1)

    zip(constraints, rows).each do |pair|
      left = pair[0]
      right = pair[1]

      render_example(screen, right, left[0], left[1], Ultraviolet::Layout::Min.new(0))
    end

    nums = "123456789012"
    row = rows[rows.size - 1]

    Ultraviolet::Screen::Context.new(screen)
      .draw_string(nums[0, Math.min(nums.size, row.dx)], row.min.x, row.min.y)
  end

  private def self.render_example(
    screen : Ultraviolet::Screen,
    area : Ultraviolet::Rectangle,
    *constraints : Constraint,
  ) : Nil
    segments = Ultraviolet::Layout.horizontal(*constraints).split(area)

    # Mirrors Go's `Split(area).Assign(&r, &b, &g)`: the second segment is blue.
    red = segments[0]
    blue = segments[1]
    green = segments[2]

    Ultraviolet::Screen.fill_area(screen, cell(RED), red)
    Ultraviolet::Screen.fill_area(screen, cell(GREEN), green)
    Ultraviolet::Screen.fill_area(screen, cell(BLUE), blue)

    draw = ->(bg : Ultraviolet::Color, text : String, rect : Ultraviolet::Rectangle) do
      ctx = Ultraviolet::Screen::Context.new(screen)
        .with_style(Ultraviolet::Style.new(bg: bg))
      ctx.draw_string(text[0, Math.min(text.size, rect.dx)], rect.min.x, rect.min.y)
    end

    draw.call(RED, constraint_label(constraints[0]), red)
    draw.call(GREEN, "." * green.dx, green)
    draw.call(BLUE, constraint_label(constraints[1]), blue)
  end

  private def self.constraint_label(constraint : Constraint) : String
    case constraint
    when Ultraviolet::Layout::Fill
      constraint.value.to_s
    when Ultraviolet::Layout::Len
      constraint.value.to_s
    when Ultraviolet::Layout::Max
      constraint.value.to_s
    when Ultraviolet::Layout::Min
      constraint.value.to_s
    when Ultraviolet::Layout::Percent
      constraint.value.to_s
    when Ultraviolet::Layout::Ratio
      "#{constraint.num}/#{constraint.den}"
    else
      ""
    end
  end

  private def self.cell(bg : Ultraviolet::Color) : Ultraviolet::Cell
    Ultraviolet::Cell.new(" ", 1, Ultraviolet::Style.new(bg: bg))
  end

  private def self.zip(left : Array(T), right : Array(U)) : Array({T, U}) forall T, U
    size = Math.min(left.size, right.size)
    Array({T, U}).new(size) { |i| {left[i], right[i]} }
  end

  private def self.cartesian_product(left : Array(T), right : Array(U)) : Array({T, U}) forall T, U
    product = [] of {T, U}
    left.each do |a|
      right.each { |b| product << {a, b} }
    end
    product
  end
end

term = Ultraviolet::Terminal.default_terminal
term.start
term.enter_alt_screen

render = ->(area : Ultraviolet::Rectangle) do
  Splits.render(term, area)
  term.display
end

begin
  # The buffer is 0x0 until the first WindowSizeEvent (as in Go), so there is
  # nothing to paint yet.
  area = term.bounds
  render.call(area) unless area.empty?

  loop do
    case event = term.events.receive
    when Ultraviolet::WindowSizeEvent
      area = event.bounds
      term.resize(area.dx, area.dy)
      Ultraviolet::Screen.clear(term)
      render.call(area)
    when Ultraviolet::KeyPressEvent
      break if event.match_string("ctrl+c", "q")
    end
  end
ensure
  term.stop
end
