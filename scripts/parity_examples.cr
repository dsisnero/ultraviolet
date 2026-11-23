# Parity harness for examples/: runs the vendored Go example and this port's
# example side by side on identical pseudo terminals and diffs their first frame.
#
# Run through `make parity-examples`. Local only, like the other parity targets:
# it needs Go and the module downloads `vendor/ultraviolet/examples/go.mod`
# (the container image and CI do not carry a Go toolchain).
#
# The comparison is on rendered bytes, so it catches what the decode and renderer
# specs cannot: an example wired to the wrong API, a missing terminal query, or a
# frame that paints differently.
require "./support/pty_capture"

module ParityExamples
  extend self

  ROOT          = File.expand_path("..", __DIR__)
  EXAMPLES_DIR  = File.join(ROOT, "examples")
  GO_EXAMPLES   = File.join(ROOT, "vendor/ultraviolet/examples")
  BUILD_DIR     = File.join(ROOT, "temp/go-examples")

  # Crystal example => Go package under vendor/ultraviolet/examples.
  PAIRS = {
    "altscreen"   => "./altscreen",
    "boxes"       => "./advanced/boxes",
    "draw"        => "./draw",
    "helloworld"  => "./helloworld",
    "image"       => "./advanced/image",
    "mouse"       => "./mouse",
    "panic"       => "./panic",
    "prependline" => "./prependline",
    "rgbimage"    => "./advanced/rgbimage",
    "splits"      => "./advanced/splits",
    "tv"          => "./advanced/tv",
    "widths"      => "./widths",
  }

  # Examples this harness cannot compare, with the reason. Kept explicit so a new
  # example cannot quietly drop out of the comparison.
  SKIP = {
    "layout"      => "the Go example is built on lipgloss, which this port does not depend on",
    "space"       => "animates from the wall clock on both sides",
    "prependline" => "random colour per frame and scheduling-dependent frame count; matched in some runs",
  }

  # Examples whose colours are random per frame on both sides. Their SGR colour
  # sequences are masked so the text and layout are still compared.
  MASK_COLORS = ["prependline"]

  # SGR colours differ by construction: Go passes palette entries through as
  # indexed colours (`31`, `41`, `38;5;N`) while this port resolves them to RGB
  # and emits `38;2;r;g;b`. Both describe the same colour, so rewrite every form
  # to RGB before comparing.
  BASIC = {
    0 => {0, 0, 0}, 1 => {205, 0, 0}, 2 => {0, 205, 0}, 3 => {205, 205, 0},
    4 => {0, 0, 238}, 5 => {205, 0, 205}, 6 => {0, 205, 205}, 7 => {229, 229, 229},
  }
  BRIGHT = {
    0 => {127, 127, 127}, 1 => {255, 0, 0}, 2 => {0, 255, 0}, 3 => {255, 255, 0},
    4 => {92, 92, 255}, 5 => {255, 0, 255}, 6 => {0, 255, 255}, 7 => {255, 255, 255},
  }
  CUBE = [0, 95, 135, 175, 215, 255]

  def palette(index : Int32) : {Int32, Int32, Int32}
    if index < 8
      return BASIC[index]
    end
    if index < 16
      return BRIGHT[index - 8]
    end
    if index < 232
      offset = index - 16
      return {CUBE[offset // 36], CUBE[(offset % 36) // 6], CUBE[offset % 6]}
    end
    gray = 8 + (index - 232) * 10
    {gray, gray, gray}
  end

  SGR = /\e\[([0-9;]*)m/

  # normalize compares frames, not terminal handshakes: everything before the
  # last full-screen clear is dropped (startup writes differ in ordering and in
  # what each side resets), then indexed/basic colours are rewritten to RGB
  # because Go passes palette entries through while this port resolves them, and
  # inline image payloads are masked (random colour per frame on both sides).
  def normalize(output : String, mask_colors : Bool = false) : String
    frame = output
    if index = output.rindex("\e[H\e[2J")
      frame = output[index..]
    elsif index = output.rindex("\e[2J")
      frame = output[index..]
    end

    if mask_colors
      # Colour values are random on both sides; everything else (text, cursor
      # moves, clears) is still compared.
      frame = frame.gsub(SGR, "<sgr>")
    else
      frame = frame.gsub(SGR) { |match| normalize_sgr($1, match) }
    end
    frame.gsub(/[A-Za-z0-9+\/]{80,}={0,2}/, "<base64>")
  end


  # Both sides must negotiate grapheme width, whatever the frame looks like.
  def negotiates_grapheme_width?(output : String) : Bool
    output.includes?("\e[?2027$p")
  end

  private def normalize_sgr(body : String, original : String) : String
    parts = body.split(';')
    rebuilt = [] of String
    index = 0
    changed = false

    while index < parts.size
      part = parts[index]
      value = part.empty? ? 0 : part.to_i

      # Truecolor, possibly with the 38;2 / 48;2 introducer.
      if (value == 38 || value == 48) && parts[index + 1]? == "2" &&
         parts[index + 4]?
        rebuilt << "#{value};2;#{parts[index + 2]};#{parts[index + 3]};#{parts[index + 4]}"
        index += 5
        next
      end

      # Palette form: 38;5;N / 48;5;N.
      if (value == 38 || value == 48) && parts[index + 1]? == "5" && (palette_index = parts[index + 2]?)
        r, g, b = palette(palette_index.to_i)
        rebuilt << "#{value};2;#{r};#{g};#{b}"
        changed = true
        index += 3
        next
      end

      # Basic foreground 30-37 / 90-97 and background 40-47 / 100-107.
      if value >= 30 && value <= 37
        r, g, b = palette(value - 30)
        rebuilt << "38;2;#{r};#{g};#{b}"
        changed = true
        index += 1
        next
      end
      if value >= 90 && value <= 97
        r, g, b = palette(value - 90 + 8)
        rebuilt << "38;2;#{r};#{g};#{b}"
        changed = true
        index += 1
        next
      end
      if value >= 40 && value <= 47
        r, g, b = palette(value - 40)
        rebuilt << "48;2;#{r};#{g};#{b}"
        changed = true
        index += 1
        next
      end
      if value >= 100 && value <= 107
        r, g, b = palette(value - 100 + 8)
        rebuilt << "48;2;#{r};#{g};#{b}"
        changed = true
        index += 1
        next
      end

      rebuilt << part
      index += 1
    end

    changed ? "\e[#{rebuilt.join(';')}m" : original
  end

  def build_go(pkg : String, name : String) : String?
    Dir.mkdir_p(BUILD_DIR)
    binary = File.join(BUILD_DIR, name)
    return binary if File.exists?(binary)

    status = Process.run("go", ["build", "-o", binary, pkg],
      chdir: GO_EXAMPLES, output: Process::Redirect::Inherit, error: Process::Redirect::Inherit)
    status.success? ? binary : nil
  end

  # Optional argument narrows the comparison to one example:
  # `crystal run scripts/parity_examples.cr -- widths`.
  def run(only : String? = nil) : Int32
    failures = 0
    checked = 0

    pairs = PAIRS
    if only
      raise "unknown example #{only}; known: #{PAIRS.keys.join(", ")}" unless PAIRS.has_key?(only)
      pairs = {only => PAIRS[only]}
    end

    pairs.each do |name, pkg|
      if reason = SKIP[name]?
        puts "skip    #{name} (#{reason})"
        next
      end

      crystal_binary = File.join(EXAMPLES_DIR, name)
      unless File::Info.executable?(crystal_binary)
        puts "missing #{name}: run `make build-examples` first"
        failures += 1
        next
      end

      go_binary = build_go(pkg, name)
      unless go_binary
        puts "failed  #{name}: could not build #{pkg}"
        failures += 1
        next
      end

      # Run each side from its own directory: examples that read data files
      # (image loads charm.jpg) resolve them relative to their source.
      go_dir = File.expand_path(pkg, GO_EXAMPLES)
      go_raw = PtyCapture.capture(go_binary, chdir: go_dir)
      crystal_raw = PtyCapture.capture(crystal_binary, chdir: EXAMPLES_DIR)
      mask_colors = MASK_COLORS.includes?(name)
      expected = normalize(go_raw, mask_colors)
      actual = normalize(crystal_raw, mask_colors)
      checked += 1

      unless negotiates_grapheme_width?(go_raw) && negotiates_grapheme_width?(crystal_raw)
        failures += 1
        puts "DIFFERS #{name} (grapheme width negotiation)"
        puts "        go queries mode 2027:      #{negotiates_grapheme_width?(go_raw)}"
        puts "        crystal queries mode 2027: #{negotiates_grapheme_width?(crystal_raw)}"
        next
      end

      if expected == actual
        puts "ok      #{name}"
      else
        failures += 1
        puts "DIFFERS #{name}"
        report(name, expected, actual)
      end
    end

    SKIP.each do |name, reason|
      puts "skip    #{name} (#{reason})"
    end

    puts "#{checked} compared, #{failures} differing"
    failures
  end

  private def report(name : String, expected : String, actual : String) : Nil
    limit = Math.min(expected.bytesize, actual.bytesize)
    index = 0
    while index < limit && expected.to_slice[index] == actual.to_slice[index]
      index += 1
    end
    from = Math.max(0, index - 30)
    puts "        first difference at byte #{index}"
    puts "        go:      #{expected[from, Math.min(120, expected.bytesize - from)].inspect}"
    puts "        crystal: #{actual[from, Math.min(120, actual.bytesize - from)].inspect}"

    Dir.mkdir_p(File.join(ROOT, "temp/parity"))
    File.write(File.join(ROOT, "temp/parity/#{name}.go.txt"), expected)
    File.write(File.join(ROOT, "temp/parity/#{name}.crystal.txt"), actual)
    puts "        full captures in temp/parity/#{name}.{go,crystal}.txt"
  end
end

exit(ParityExamples.run(ARGV.first?) == 0 ? 0 : 1)
