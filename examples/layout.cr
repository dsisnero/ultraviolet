require "../src/ultraviolet"
require "lipgloss"
require "colorful"
require "textseg"

module LayoutExample
  extend self

  WIDTH        = 96
  COLUMN_WIDTH = 30

  # Detect background color
  has_dark_bg = Lipgloss.has_dark_background?

  # Helper function for choosing either a light or dark color based on the
  # detected background color.
  light_dark = Lipgloss.light_dark(has_dark_bg)

  # Style definitions.
  subtle = light_dark.call(Lipgloss.color("#D9DCCF"), Lipgloss.color("#383838"))
  highlight = light_dark.call(Lipgloss.color("#874BFD"), Lipgloss.color("#7D56F4"))
  special = light_dark.call(Lipgloss.color("#43BF6D"), Lipgloss.color("#73F59F"))

  divider = Lipgloss.new_style
    .set_string("•")
    .padding(0, 1)
    .foreground(subtle)
    .render

  url = ->(text : String) { Lipgloss.new_style.foreground(special).render(text) }

  # Tabs.
  active_tab_border = Lipgloss::Border.new(
    top: "─",
    bottom: " ",
    left: "│",
    right: "│",
    top_left: "╭",
    top_right: "╮",
    bottom_left: "┘",
    bottom_right: "└"
  )

  tab_border = Lipgloss::Border.new(
    top: "─",
    bottom: "─",
    left: "│",
    right: "│",
    top_left: "╭",
    top_right: "╮",
    bottom_left: "┴",
    bottom_right: "┴"
  )

  tab = Lipgloss.new_style
    .border(tab_border, true)
    .border_foreground(highlight)
    .padding(0, 1)

  active_tab = tab.border(active_tab_border, true)

  tab_gap = tab
    .border_top(false)
    .border_left(false)
    .border_right(false)

  # Title.
  title_style = Lipgloss.new_style
    .margin_left(1)
    .margin_right(5)
    .padding(0, 1)
    .italic(true)
    .foreground(Lipgloss.color("#FFF7DB"))
    .set_string("Lip Gloss")

  desc_style = Lipgloss.new_style.margin_top(1)

  info_style = Lipgloss.new_style
    .border_style(Lipgloss::Border.normal)
    .border_top(true)
    .border_foreground(subtle)

  # Dialog.
  dialog_box_style = Lipgloss.new_style
    .border(Lipgloss::Border.rounded)
    .border_foreground(Lipgloss.color("#874BFD"))
    .padding(1, 0)
    .border_top(true)
    .border_left(true)
    .border_right(true)
    .border_bottom(true)

  button_style = Lipgloss.new_style
    .foreground(Lipgloss.color("#FFF7DB"))
    .background(Lipgloss.color("#888B7E"))
    .padding(0, 3)
    .margin_top(1)

  active_button_style = button_style
    .foreground(Lipgloss.color("#FFF7DB"))
    .background(Lipgloss.color("#F25D94"))
    .margin_right(2)
    .underline(true)

  # List.
  list = Lipgloss.new_style
    .border(Lipgloss::Border.normal, false, true, false, false)
    .border_foreground(subtle)
    .margin_right(2)
    .height(8)
    .width(COLUMN_WIDTH + 1)

  list_header = ->(text : String) do
    Lipgloss.new_style
      .border_style(Lipgloss::Border.normal)
      .border_bottom(true)
      .border_foreground(subtle)
      .margin_right(2)
      .render(text)
  end

  list_item = ->(text : String) do
    Lipgloss.new_style.padding_left(2).render(text)
  end

  check_mark = Lipgloss.new_style
    .set_string("✓")
    .foreground(special)
    .padding_right(1)
    .render

  list_done = ->(s : String) do
    check_mark + Lipgloss.new_style
      .strikethrough(true)
      .foreground(light_dark.call(Lipgloss.color("#969B86"), Lipgloss.color("#696969")))
      .render(s)
  end

  # Paragraphs/History.
  history_style = Lipgloss.new_style
    .align(Lipgloss::Position::Left)
    .foreground(Lipgloss.color("#FAFAFA"))
    .background(highlight)
    .margin(1, 3, 0, 0)
    .padding(1, 2)
    .height(19)
    .width(COLUMN_WIDTH)

  # Status Bar.
  status_nugget = Lipgloss.new_style
    .foreground(Lipgloss.color("#FFFDF5"))
    .padding(0, 1)

  status_bar_style = Lipgloss.new_style
    .foreground(light_dark.call(Lipgloss.color("#343433"), Lipgloss.color("#C1C6B2")))
    .background(light_dark.call(Lipgloss.color("#D9DCCF"), Lipgloss.color("#353533")))

  status_style = Lipgloss.new_style
    .inherit(status_bar_style)
    .foreground(Lipgloss.color("#FFFDF5"))
    .background(Lipgloss.color("#FF5F87"))
    .padding(0, 1)
    .margin_right(1)

  encoding_style = status_nugget
    .background(Lipgloss.color("#A550DF"))
    .align(Lipgloss::Position::Right)

  status_text = Lipgloss.new_style.inherit(status_bar_style)

  fish_cake_style = status_nugget.background(Lipgloss.color("#6124DF"))

  # Page.
  doc_style = Lipgloss.new_style.padding(1, 2, 1, 2)

  # Build document.
  doc = String::Builder.new

  # Tabs.
  row = Lipgloss::Style.join_horizontal(
    Lipgloss::Position::Top,
    active_tab.render("Lip Gloss"),
    tab.render("Blush"),
    tab.render("Eye Shadow"),
    tab.render("Mascara"),
    tab.render("Foundation")
  )
  gap = tab_gap.render(" " * Math.max(0, WIDTH - Lipgloss.width(row) - 2))
  row = Lipgloss::Style.join_horizontal(Lipgloss::Position::Bottom, row, gap)
  doc << row
  doc << "\n\n"

  # Title.
  colors = color_grid(1, 5)
  title = String::Builder.new
  colors.each_with_index do |v, i|
    offset = 2
    c = Lipgloss.color(v[0])
    title << title_style.margin_left(i * offset).background(c).render
    title << '\n' if i < colors.size - 1
  end

  desc = Lipgloss::Style.join_vertical(
    Lipgloss::Position::Left,
    desc_style.render("Style Definitions for Nice Terminal Layouts"),
    info_style.render("From Charm" + divider + url.call("https://github.com/charmbracelet/lipgloss"))
  )

  row = Lipgloss::Style.join_horizontal(Lipgloss::Position::Top, title.to_s, desc)
  doc << row
  doc << "\n\n"

  # Dialog.
  ok_button = active_button_style.render("Yes")
  cancel_button = button_style.render("Maybe")

  grad = apply_gradient(
    Lipgloss.new_style,
    "Are you sure you want to eat marmalade?",
    Lipgloss.color("#EDFF82"),
    Lipgloss.color("#F25D94")
  )

  question = Lipgloss.new_style
    .width(50)
    .align(Lipgloss::Position::Center)
    .render(grad)

  buttons = Lipgloss::Style.join_horizontal(Lipgloss::Position::Top, ok_button, cancel_button)
  dialog_ui = Lipgloss::Style.join_vertical(Lipgloss::Position::Center, question, buttons)

  dialog = "" # Lipgloss.place not working yet
  # TODO: dialog_box_style.render(dialog_ui),

  doc << dialog
  doc << "\n\n"

  # Color grid.
  colors_str = -> do
    colors = color_grid(14, 8)
    b = String::Builder.new
    colors.each do |x|
      x.each do |y|
        s = Lipgloss.new_style.set_string("  ").background(Lipgloss.color(y))
        b << s.render
      end
      b << '\n'
    end
    b.to_s
  end.call

  lists = Lipgloss::Style.join_horizontal(
    Lipgloss::Position::Top,
    list.render(
      Lipgloss::Style.join_vertical(
        Lipgloss::Position::Left,
        list_header.call("Citrus Fruits to Try"),
        list_done.call("Grapefruit"),
        list_done.call("Yuzu"),
        list_item.call("Citron"),
        list_item.call("Kumquat"),
        list_item.call("Pomelo")
      )
    ),
    list.width(COLUMN_WIDTH).render(
      Lipgloss::Style.join_vertical(
        Lipgloss::Position::Left,
        list_header.call("Actual Lip Gloss Vendors"),
        list_item.call("Glossier"),
        list_item.call("Claire's Boutique"),
        list_done.call("Nyx"),
        list_item.call("Mac"),
        list_done.call("Milk")
      )
    )
  )

  doc << Lipgloss::Style.join_horizontal(Lipgloss::Position::Top, lists, colors_str)

  # Marmalade history.
  history_a = "The Romans learned from the Greeks that quinces slowly cooked with honey would 'set' when cool. The Apicius gives a recipe for preserving whole quinces, stems and leaves attached, in a bath of honey diluted with defrutum: Roman marmalade. Preserves of quince and lemon appear (along with rose, apple, plum and pear) in the Book of ceremonies of the Byzantine Emperor Constantine VII Porphyrogennetos."
  history_b = "Medieval quince preserves, which went by the French name cotignac, produced in a clear version and a fruit pulp version, began to lose their medieval seasoning of spices in the 16th century. In the 17th century, La Varenne provided recipes for both thick and clear cotignac."
  history_c = "In 1524, Henry VIII, King of England, received a 'box of marmalade' from Mr. Hull of Exeter. This was probably marmelada, a solid quince paste from Portugal, still made and sold in southern Europe today. It became a favourite treat of Anne Boleyn and her ladies in waiting."

  doc << Lipgloss::Style.join_horizontal(
    Lipgloss::Position::Top,
    history_style.align(Lipgloss::Position::Right).render(history_a),
    history_style.align(Lipgloss::Position::Center).render(history_b),
    history_style.margin_right(0).render(history_c)
  )

  doc << "\n\n"

  # Status bar.
  w = ->(text : String) { Lipgloss.width(text) }

  light_dark_state = has_dark_bg ? "Dark" : "Light"

  status_key = status_style.render("STATUS")
  encoding = encoding_style.render("UTF-8")
  fish_cake = fish_cake_style.render("🍥 Fish Cake")
  status_val = status_text
    .width(WIDTH - w.call(status_key) - w.call(encoding) - w.call(fish_cake))
    .render("Ravishingly " + light_dark_state + "!")

  bar = Lipgloss::Style.join_horizontal(
    Lipgloss::Position::Top,
    status_key,
    status_val,
    encoding,
    fish_cake
  )

  doc << status_bar_style.width(WIDTH).render(bar)

  # Terminal rendering (placeholder)
  puts doc.to_s

  # Helper functions
  def color_grid(x_steps, y_steps)
    x0y0 = Colorful.hex("#F25D94")
    x1y0 = Colorful.hex("#EDFF82")
    x0y1 = Colorful.hex("#643AFF")
    x1y1 = Colorful.hex("#14F9D5")

    x0 = Array.new(y_steps) { |i| x0y0.blend_luv(x0y1, i.to_f / y_steps) }
    x1 = Array.new(y_steps) { |i| x1y0.blend_luv(x1y1, i.to_f / y_steps) }

    grid = Array.new(y_steps) { [] of String }
    y_steps.times do |x|
      y0 = x0[x]
      grid[x] = Array.new(x_steps) { |y| y0.blend_luv(x1[x], y.to_f / x_steps).hex }
    end
    grid
  end

  private def lipgloss_to_colorful(color : Lipgloss::Color) : Colorful::Color
    r, g, b = color.to_rgb
    Colorful::Color.new(r / 255.0, g / 255.0, b / 255.0)
  end

  def apply_gradient(base_style, input, from, to)
    # Get graphemes
    chars = [] of String
    TextSegment.each_grapheme(input) do |cluster|
      chars << cluster.to_s
    end

    # Generate blend
    a = lipgloss_to_colorful(to)
    b = lipgloss_to_colorful(from)
    output = String::Builder.new
    chars.each_with_index do |ch, i|
      hex = a.blend_luv(b, i.to_f / (chars.size - 1)).hex
      output << base_style.foreground(Lipgloss.color(hex)).render(ch)
    end
    output.to_s
  end
end

# LayoutExample.run if __FILE__ == $0
