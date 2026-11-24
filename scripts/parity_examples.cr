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

  ROOT         = File.expand_path("..", __DIR__)
  EXAMPLES_DIR = File.join(ROOT, "examples")
  GO_EXAMPLES  = File.join(ROOT, "vendor/ultraviolet/examples")
  BUILD_DIR    = File.join(ROOT, "temp/go-examples")

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

  SGR = /\e\[([0-9;]*)m/

  # normalize compares frames, not terminal handshakes: everything before the
  # last full-screen clear is dropped (startup writes differ in ordering and in
  # what each side resets), and inline image payloads are masked (random colour
  # per frame on both sides). SGR colours are compared as written: this port
  # keeps the palette kind of a colour, so Go's `4x`/`38;5;N` come out as `4x`/
  # `38;5;N` here too.
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
    end
    frame.gsub(/[A-Za-z0-9+\/]{80,}={0,2}/, "<base64>")
  end

  # Both sides must negotiate grapheme width, whatever the frame looks like.
  def negotiates_grapheme_width?(output : String) : Bool
    output.includes?("\e[?2027$p")
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
      go_raw = PtyCapture.capture_example(go_binary, name, chdir: go_dir)
      crystal_raw = PtyCapture.capture_example(crystal_binary, name, chdir: EXAMPLES_DIR)
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
