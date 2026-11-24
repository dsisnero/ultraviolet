module Ultraviolet
  # AnsiColor exposes the palette entries SGR names, as `charmbracelet/x/ansi`
  # does. Each constructor keeps its kind: a basic entry and an index encode
  # differently (`3x`/`9x` versus `38;5;N`), which is the difference this port
  # used to lose by resolving everything to RGB.
  module AnsiColor
    BASIC  = (0..7).map { |i| Color.basic(i) }
    BRIGHT = (8..15).map { |i| Color.basic(i) }

    def self.basic(index : Int32) : Color
      Color.basic(index)
    end

    def self.bright(index : Int32) : Color
      Color.basic(index + 8)
    end

    # indexed returns an xterm 256-colour entry, including the first 16: Go's
    # `ansi.IndexedColor(1)` encodes as `38;5;1`, not as basic red.
    def self.indexed(index : Int32) : Color
      Color.indexed(index)
    end

    # palette resolves an index to its channels without changing kind, for
    # callers that need RGB (image encoders, hex helpers).
    def self.palette(index : Int32) : Color
      Color.indexed(index)
    end
  end
end
