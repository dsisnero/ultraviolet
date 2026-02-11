require "../src/ultraviolet"

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
NAVY        = Ultraviolet::Color.new(16_u8, 70_u8, 106_u8)

term = Ultraviolet::Terminal.default_terminal
term.start
term.enter_alt_screen

area = term.bounds

row_colors = {
  [WHITE, YELLOW, CYAN, GREEN, MAGENTA, RED, BLUE],
  [BLUE, BLACK, MAGENTA, BLACK, CYAN, BLACK, WHITE],
  [NAVY, FULL_WHITE, PURPLE, BLACK, BLACK, BLACK],
}

render = -> do
  term.clear

  top_row = Ultraviolet.rect(0, 0, area.max.x, (area.max.y * 66) // 100)
  mid_row = Ultraviolet.rect(0, top_row.max.y, area.max.x, (area.max.y * 8) // 100)
  bot_row = Ultraviolet.rect(0, mid_row.max.y, area.max.x, (area.max.y * 26) // 100)

  bar_count = 7
  bar_width = Math.max(1, top_row.max.x // bar_count)

  [top_row, mid_row].each_with_index do |row, row_index|
    bar_count.times do |j|
      left = j * bar_width
      right = ((j + 1) * bar_width).clamp(0, area.max.x)
      bar = Ultraviolet.rect(left, row.min.y, right, row.max.y)
      cell = Ultraviolet::EMPTY_CELL
      cell.style.bg = row_colors[row_index][j % row_colors[row_index].size]
      term.fill_area(cell, bar)
    end
  end

  bot_bar_count = 6
  bot_bar_width = Math.max(1, bot_row.max.x // bot_bar_count)
  bot_bar_count.times do |i|
    left = i * bot_bar_width
    right = ((i + 1) * bot_bar_width).clamp(0, area.max.x)
    bar = Ultraviolet.rect(left, bot_row.min.y, right, bot_row.max.y)
    cell = Ultraviolet::EMPTY_CELL
    cell.style.bg = row_colors[2][i % row_colors[2].size]
    term.fill_area(cell, bar)
  end

  special_row = 5
  sub_bar_width = Math.max(1, bar_width // 3)
  3.times do |i|
    color = case i
            when 0 then FULL_BLACK
            when 2 then LIGHT_BLACK
            else        nil
            end
    next unless color
    left = special_row * bar_width + i * sub_bar_width
    right = (left + sub_bar_width).clamp(0, area.max.x)
    bar = Ultraviolet.rect(left, bot_row.min.y, right, bot_row.max.y)
    cell = Ultraviolet::EMPTY_CELL
    cell.style.bg = color
    term.fill_area(cell, bar)
  end

  term.display
end

begin
  render.call
  loop do
    case ev = term.events.receive
    when Ultraviolet::WindowSizeEvent
      area = ev.bounds
      term.resize(area.dx, area.dy)
      term.erase
      render.call
    when Ultraviolet::KeyPressEvent
      break if ev.match_string("q", "ctrl+c")
    end
  end
ensure
  term.shutdown(1.second)
end
