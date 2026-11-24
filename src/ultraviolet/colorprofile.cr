module Ultraviolet
  enum ColorProfile
    TrueColor
    ANSI256
    ANSI
    Ascii
    NoTTY

    def self.detect(io : IO, env : Array(String)) : ColorProfile
      # Check if output is a TTY
      tty = io.is_a?(IO::FileDescriptor) && io.tty?
      # Allow forcing TTY via environment variable for testing
      unless tty
        env.each do |e|
          if e.starts_with?("TTY_FORCE=")
            tty = true
            break
          end
        end
      end
      if tty
        # Use environment detection
        env_detect(env)
      else
        NoTTY
      end
    end

    def self.env_detect(env : Array(String)) : ColorProfile
      environ = Environ.new(env)
      colorterm = environ.getenv("COLORTERM")
      term = environ.getenv("TERM")
      return TrueColor if colorterm == "truecolor"
      return ANSI256 if term.includes?("256color")
      return ANSI if !term.empty?
      # Default to TrueColor if we can't determine
      TrueColor
    end
  end

  module ColorProfileUtil
    @@ansi16_palette : Array(Color)?
    @@ansi256_palette : Array(Color)?

    # convert mirrors Go's `colorprofile.Profile.Convert` as `ConvertStyle` uses
    # it: ASCII and below drop the colour, truecolor is a passthrough (kinds
    # included), a basic entry is never touched, an index survives every profile
    # but ANSI, and an RGB value becomes the closest palette entry the profile can
    # show. The conversions themselves are the `ansi` shard's ports of
    # `ansi.Convert256`/`ansi.Convert16`.
    def self.convert(profile : ColorProfile, color : Color) : Color?
      case profile
      when ColorProfile::NoTTY, ColorProfile::Ascii
        nil
      when ColorProfile::TrueColor
        color
      else
        if color.basic?
          color
        elsif color.indexed?
          profile == ColorProfile::ANSI ? Color.basic(convert16(color).to_i) : color
        elsif profile == ColorProfile::ANSI256
          Color.indexed(convert256(color).to_i)
        else
          Color.basic(convert16(color).to_i)
        end
      end
    end

    private def self.convert256(color : Color) : UInt8
      index = Ansi.convert_256(Ansi::RGBColor.new(color.r, color.g, color.b))
      index.value
    end

    private def self.convert16(color : Color) : UInt8
      if color.indexed?
        index = Ansi.convert_16(Ansi::IndexedColor.new(color.value))
      else
        index = Ansi.convert_16(Ansi::RGBColor.new(color.r, color.g, color.b))
      end
      index.value
    end

    # closest_ansi16_index and closest_ansi256_index keep the old helpers
    # working: they now read the same conversions the encoder uses rather than a
    # hand-rolled Euclidean search, so they cannot drift from Go.
    def self.closest_ansi16_index(color : Color) : Int32
      converted = convert(ColorProfile::ANSI, color)
      converted.try(&.value.to_i32) || 0
    end

    def self.closest_ansi256_index(color : Color) : Int32
      return color.value.to_i32 if color.indexed?
      converted = convert(ColorProfile::ANSI256, color)
      converted.try(&.value.to_i32) || 0
    end
  end
end
