module Ultraviolet
  enum ColorProfile
    TrueColor
    ANSI256
    ANSI
    Ascii
    NoTTY
  end

  module ColorProfileUtil
    @@ansi16_palette : Array(Color)?
    @@ansi256_palette : Array(Color)?

    def self.convert(profile : ColorProfile, color : Color) : Color
      case profile
      when ColorProfile::ANSI256
        closest_color(color, ansi256_palette)
      when ColorProfile::ANSI
        closest_color(color, ansi16_palette)
      else
        color
      end
    end

    private def self.closest_color(color : Color, palette : Array(Color)) : Color
      best = palette.first
      best_dist = Int32::MAX

      palette.each do |candidate|
        dr = color.r.to_i - candidate.r.to_i
        dg = color.g.to_i - candidate.g.to_i
        db = color.b.to_i - candidate.b.to_i
        dist = dr * dr + dg * dg + db * db
        if dist < best_dist
          best_dist = dist
          best = candidate
        end
      end

      best
    end

    def self.closest_ansi16_index(color : Color) : Int32
      closest_index(color, ansi16_palette)
    end

    def self.closest_ansi256_index(color : Color) : Int32
      closest_index(color, ansi256_palette)
    end

    private def self.closest_index(color : Color, palette : Array(Color)) : Int32
      best_idx = 0
      best_dist = Int32::MAX
      palette.each_with_index do |candidate, idx|
        dr = color.r.to_i - candidate.r.to_i
        dg = color.g.to_i - candidate.g.to_i
        db = color.b.to_i - candidate.b.to_i
        dist = dr * dr + dg * dg + db * db
        if dist < best_dist
          best_dist = dist
          best_idx = idx
        end
      end
      best_idx
    end

    private def self.ansi16_palette : Array(Color)
      @@ansi16_palette ||= [
        Color.new(0_u8, 0_u8, 0_u8),       # black
        Color.new(205_u8, 0_u8, 0_u8),     # red
        Color.new(0_u8, 205_u8, 0_u8),     # green
        Color.new(205_u8, 205_u8, 0_u8),   # yellow
        Color.new(0_u8, 0_u8, 238_u8),     # blue
        Color.new(205_u8, 0_u8, 205_u8),   # magenta
        Color.new(0_u8, 205_u8, 205_u8),   # cyan
        Color.new(229_u8, 229_u8, 229_u8), # white (light gray)
        Color.new(127_u8, 127_u8, 127_u8), # bright black (dark gray)
        Color.new(255_u8, 0_u8, 0_u8),     # bright red
        Color.new(0_u8, 255_u8, 0_u8),     # bright green
        Color.new(255_u8, 255_u8, 0_u8),   # bright yellow
        Color.new(92_u8, 92_u8, 255_u8),   # bright blue
        Color.new(255_u8, 0_u8, 255_u8),   # bright magenta
        Color.new(0_u8, 255_u8, 255_u8),   # bright cyan
        Color.new(255_u8, 255_u8, 255_u8), # bright white
      ]
    end

    private def self.ansi256_palette : Array(Color)
      @@ansi256_palette ||= begin
        palette = ansi16_palette.dup
        steps = [0, 95, 135, 175, 215, 255]
        steps.each do |red_step|
          steps.each do |green_step|
            steps.each do |blue_step|
              palette << Color.new(red_step.to_u8, green_step.to_u8, blue_step.to_u8)
            end
          end
        end
        24.times do |i|
          v = (8 + i * 10).to_u8
          palette << Color.new(v, v, v)
        end
        palette
      end
    end
  end
end
