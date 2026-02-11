require "../src/ultraviolet"

def clamp(value : Float64, min : Float64, max : Float64) : Float64
  return min if value < min
  return max if value > max
  value
end

def setup_colors(width : Int32, height : Int32) : Array(Array(Ultraviolet::Color))
  doubled = height * 2
  Array.new(doubled) do |y|
    randomness = (doubled - y).to_f / doubled.to_f
    Array.new(width) do
      base = randomness * ((doubled - y).to_f / doubled.to_f)
      offset = (rand * 0.2) - 0.1
      value = clamp(base + offset, 0.0, 1.0)
      gray = (value * 255).to_i.clamp(0, 255).to_u8
      Ultraviolet::Color.new(gray, gray, gray)
    end
  end
end

term = Ultraviolet::Terminal.default_terminal
term.start

area = term.bounds
colors = setup_colors(area.dx, area.dy)
frame = 0
fps = 60.0
frames_in_window = 0
window_start = Time.monotonic
running = true

begin
  while running
    select
    when ev = term.events.receive
      case ev
      when Ultraviolet::KeyPressEvent
        running = false if ev.match_string("q", "ctrl+c")
      when Ultraviolet::WindowSizeEvent
        area = ev.bounds
        term.resize(area.dx, area.dy)
        term.erase
        colors = setup_colors(area.dx, area.dy)
      end
    when timeout(1.millisecond)
    end

    next if colors.empty?

    frame += 1
    frames_in_window += 1
    term.clear

    title = Ultraviolet::StyledString.new("Space / FPS: #{fps.round(1)}")
    title.draw(term, Ultraviolet.rect(0, 0, area.dx, 1))

    width = area.dx
    height = area.dy
    (1...height).each do |y|
      (0...width).each do |x|
        xi = (x + frame) % width
        fg = colors[(y * 2).clamp(0, colors.size - 1)][xi]
        bg = colors[(y * 2 + 1).clamp(0, colors.size - 1)][xi]
        style = Ultraviolet::Style.new(fg: fg, bg: bg)
        term.set_cell(x, y, Ultraviolet::Cell.new("▀", 1, style))
      end
    end
    term.display

    elapsed = Time.monotonic - window_start
    if elapsed >= 1.second && frames_in_window > 2
      fps = frames_in_window / elapsed.total_seconds
      window_start = Time.monotonic
      frames_in_window = 0
    end

    sleep 16.milliseconds
  end
ensure
  term.shutdown(1.second)
end
