require "../src/ultraviolet"

# Renders scripts and emoji whose column width the two width models disagree
# about, so drift between what ultraviolet thinks it drew and what the terminal
# painted is visible on screen.
#
# Press w to force wcwidth, g to force grapheme width, q to quit.

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

BOX_WIDTH = 24

term = Ultraviolet::Terminal.default_terminal
screen = term

begin
  term.start
rescue ex
  STDERR.puts "failed to start: #{ex.message}"
  exit 1
end

term.enter_alt_screen

forced = ""

display = -> do
  builder = String::Builder.new

  # The method itself is a Proc, so label the model by how a known-drifting
  # family measures rather than by introspecting the Proc.
  model = term.width_method.call("👨‍👩‍👧‍👦") > 4 ? "wcwidth" : "grapheme (DEC mode 2027)"
  builder << "width method: #{model}"
  builder << "  [forced with #{forced.inspect}]" unless forced.empty?
  builder << "\n"
  builder << "the right edges below should form one straight column\n\n"

  ruler = "....|....+" * ((BOX_WIDTH + 12) // 10 + 1)
  builder << ruler[0, BOX_WIDTH + 2] << "\n"

  SAMPLES.each do |name, text|
    width = term.width_method.call(text)
    pad = Math.max(0, BOX_WIDTH - width)
    builder << "│#{text}#{" " * pad}│ uv=#{width} ansi=#{Ansi.string_width(text)}  #{name}\n"
  end

  builder << "\nw: force wcwidth   g: force grapheme width   q: quit"

  Ultraviolet::StyledString.new(builder.to_s).draw(screen, screen.bounds)
  term.display
end

display.call

loop do
  event = term.events.receive
  case event
  when Ultraviolet::WindowSizeEvent
    term.resize(event.width, event.height)
    display.call
  when Ultraviolet::Key
    if event.match_string("w")
      term.width_method = ->(value : String) { Ansi.string_width_wc(value) }
      forced = "w"
      display.call
    elsif event.match_string("g")
      term.width_method = ->(value : String) { Ansi.string_width(value) }
      forced = "g"
      display.call
    elsif event.match_string("q", "ctrl+c", "esc")
      break
    end
  end
end

term.stop
