require "../src/ultraviolet"

# Port of vendor/ultraviolet/examples/advanced/tv.
#
# Draws SMPTE-style colour bars over the whole screen: three bands (top, a
# one-row middle band, and a bottom grid of six bars), plus a special case that
# splits the sixth top bar into three sub-bars. Any window size event
# re-renders; q or ctrl+c quits.

GRAY        = Ultraviolet::Color.new(104_u8, 104_u8, 104_u8)
WHITE       = Ultraviolet::Color.new(180_u8, 180_u8, 180_u8)
YELLOW      = Ultraviolet::Color.new(180_u8, 180_u8, 16_u8)
CYAN        = Ultraviolet::Color.new(16_u8, 180_u8, 180_u8)
GREEN       = Ultraviolet::Color.new(16_u8, 180_u8, 16_u8)
MAGENTA     = Ultraviolet::Color.new(180_u8, 16_u8, 180_u8)
RED         = Ultraviolet::Color.new(180_u8, 16_u8, 16_u8)
BLUE        = Ultraviolet::Color.new(16_u8, 16_u8, 180_u8)
BLACK       = Ultraviolet::Color.new(16_u8, 16_u8, 16_u8)
FULL_WHITE  = Ultraviolet::Color.new(235_u8, 235_u8, 235_u8)
FULL_BLACK  = Ultraviolet::Color.new(0_u8, 0_u8, 0_u8)
LIGHT_BLACK = Ultraviolet::Color.new(26_u8, 26_u8, 26_u8)
PURPLE      = Ultraviolet::Color.new(72_u8, 16_u8, 116_u8)
BROWN       = Ultraviolet::Color.new(106_u8, 52_u8, 16_u8)
NAVY        = Ultraviolet::Color.new(16_u8, 70_u8, 106_u8)

term = Ultraviolet::Terminal.default_terminal
screen = term

begin
  term.start
rescue ex
  STDERR.puts "Error starting terminal: #{ex.message}"
  exit 1
end

screen.enter_alt_screen

bar_count = 7
bot_bar_count = 6
row_colors = {
  [WHITE, YELLOW, CYAN, GREEN, MAGENTA, RED, BLUE],
  [BLUE, BLACK, MAGENTA, BLACK, CYAN, BLACK, WHITE],
  [NAVY, FULL_WHITE, PURPLE, BLACK, BLACK, BLACK],
}

display = -> do
  Ultraviolet::Screen.clear(screen)

  area = screen.bounds
  top_row = Ultraviolet.rect(0, 0, area.max.x, (area.max.y * 66) // 100)
  mid_row = Ultraviolet.rect(0, top_row.max.y, area.max.x, (area.max.y * 8) // 100)
  bot_row = Ultraviolet.rect(0, mid_row.max.y, area.max.x, (area.max.y * 26) // 100)

  bar_width = top_row.max.x // bar_count
  {top_row, mid_row}.each_with_index do |row, row_index|
    bar_count.times do |j|
      bar = Ultraviolet.rect(j * bar_width, row.min.y, (j + 1) * bar_width, row.max.y)
      cell = Ultraviolet::EMPTY_CELL
      cell.style.bg = row_colors[row_index][j % row_colors[row_index].size]
      screen.fill_area(cell, bar)
    end
  end

  bot_bar_width = bot_row.max.x // bot_bar_count
  bot_bar_count.times do |i|
    bar = Ultraviolet.rect(i * bot_bar_width, bot_row.min.y, (i + 1) * bot_bar_width, bot_row.max.y)
    cell = Ultraviolet::EMPTY_CELL
    cell.style.bg = row_colors[2][i % row_colors[2].size]
    screen.fill_area(cell, bar)
  end

  # Special case for the before last bar.
  special_row = 5
  sub_bar_width = bar_width // 3
  3.times do |i|
    bar = Ultraviolet.rect(special_row * bar_width + i * sub_bar_width, bot_row.min.y, sub_bar_width, bot_row.max.y)
    cell = Ultraviolet::EMPTY_CELL
    case i
    when 0
      cell.style.bg = FULL_BLACK
    when 1
      next
    when 2
      cell.style.bg = LIGHT_BLACK
    end
    screen.fill_area(cell, bar)
  end

  screen.display
end

# Initial render.
display.call

begin
  loop do
    case event = term.events.receive
    when Ultraviolet::WindowSizeEvent
      screen.resize(event.width, event.height)
      display.call
    when Ultraviolet::KeyPressEvent
      break if event.match_string("q", "ctrl+c")
    end
  end
ensure
  term.stop
end
