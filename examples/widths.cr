require "../src/ultraviolet"

# Port of vendor/ultraviolet/examples/widths.
#
# Renders scripts and emoji whose column width the two width models disagree
# about, so drift between what ultraviolet thinks it drew and what the terminal
# actually painted is visible on screen.
#
# Every sample sits in a box of the same inner width, padded out using
# ultraviolet's own measurement. If the width model matches the terminal, the
# right edges form a straight column. Any edge that sits left or right of the
# rest is the renderer and the terminal disagreeing about that sample, which is
# the bug this example exists to show.
#
# Press w to force wcwidth, g to force grapheme width, q to quit. Terminals
# that implement DEC mode 2027 line up under grapheme width; everything else
# lines up under wcwidth.

SAMPLES = [
  {"ascii", "hello world"},
  {"hindi", "नमस्ते दुनिया"},
  {"hindi conjunct", "स्ते क्ष त्र ज्ञ"},
  {"combining", "café résumé"},
  {"cjk", "世界你好"},
  {"emoji", "🌈 🔥 🦄"},
  {"zwj family", "👨‍👩‍👧‍👦"},
  {"zwj work", "👨‍💻 👩‍🚀"},
  {"zwj flag", "🏳️‍🌈"},
  {"skin tone", "👍🏽 👋🏿"},
  {"vs16", "⚠️ ❤️ ✈️"},
  {"keycap", "1️⃣ 2️⃣ 3️⃣"},
  {"flags", "🇺🇸 🇯🇵"},
]

# BOX_WIDTH is the inner width every sample is padded to.
BOX_WIDTH = 24

term = Ultraviolet::Terminal.default_terminal
screen = term

begin
  term.start
rescue ex
  STDERR.puts "failed to start: #{ex.message}"
  exit 1
end

screen.enter_alt_screen

# forced reports whether the width method was pinned from the keyboard, which
# is what makes the two models comparable on the same terminal.
forced = ""

display = -> do
  builder = String::Builder.new

  method = "wcwidth"
  if screen.width_method == Ultraviolet::GRAPHEME_WIDTH_METHOD
    method = "grapheme (DEC mode 2027)"
  end
  builder << "width method: #{method}"
  builder << "  [forced with #{forced.inspect}]" unless forced.empty?
  builder << "\n"
  builder << "the right edges below should form one straight column\n\n"

  # A ruler, so a drifting edge can be read off in columns.
  ruler = "....|....+" * ((BOX_WIDTH + 12) // 10 + 1)
  builder << ruler[0, BOX_WIDTH + 2] << "\n"

  SAMPLES.each do |name, text|
    width = screen.width_method.call(text)
    pad = BOX_WIDTH - width
    pad = 0 if pad < 0
    builder << "│#{text}#{" " * pad}│ uv=#{width.to_s.ljust(2)} ansi=#{Ansi.string_width(text).to_s.ljust(2)}  #{name}\n"
  end

  builder << "\nw: force wcwidth   g: force grapheme width   q: quit"

  Ultraviolet::StyledString.new(builder.to_s).draw(screen, screen.bounds)
  screen.display
end

# The buffer is 0x0 until the first WindowSizeEvent arrives, as in Go.
display.call unless screen.bounds.empty?

begin
  loop do
    event = term.events.receive
    case event
    when Ultraviolet::WindowSizeEvent
      screen.resize(event.width, event.height)
      display.call
    when Ultraviolet::KeyPressEvent
      if event.match_string("w")
        screen.width_method = Ultraviolet::DEFAULT_WIDTH_METHOD
        forced = "w"
        display.call
      elsif event.match_string("g")
        screen.width_method = Ultraviolet::GRAPHEME_WIDTH_METHOD
        forced = "g"
        display.call
      else
        break
      end
    end
  end
ensure
  term.stop
end
