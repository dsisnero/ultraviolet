module Ultraviolet
  module AnsiColor
    BASIC = [
      Color.new(0_u8, 0_u8, 0_u8),
      Color.new(205_u8, 0_u8, 0_u8),
      Color.new(0_u8, 205_u8, 0_u8),
      Color.new(205_u8, 205_u8, 0_u8),
      Color.new(0_u8, 0_u8, 238_u8),
      Color.new(205_u8, 0_u8, 205_u8),
      Color.new(0_u8, 205_u8, 205_u8),
      Color.new(229_u8, 229_u8, 229_u8),
    ]

    BRIGHT = [
      Color.new(127_u8, 127_u8, 127_u8),
      Color.new(255_u8, 0_u8, 0_u8),
      Color.new(0_u8, 255_u8, 0_u8),
      Color.new(255_u8, 255_u8, 0_u8),
      Color.new(92_u8, 92_u8, 255_u8),
      Color.new(255_u8, 0_u8, 255_u8),
      Color.new(0_u8, 255_u8, 255_u8),
      Color.new(255_u8, 255_u8, 255_u8),
    ]

    def self.basic(index : Int32) : Color
      BASIC[index]
    end

    def self.bright(index : Int32) : Color
      BRIGHT[index]
    end

    def self.indexed(index : Int32) : Color
      if index < 8
        return basic(index)
      end
      if index < 16
        return bright(index - 8)
      end
      if index < 232
        offset = index - 16
        r = offset // 36
        g = (offset % 36) // 6
        b = offset % 6
        steps = [0, 95, 135, 175, 215, 255]
        return Color.new(steps[r].to_u8, steps[g].to_u8, steps[b].to_u8)
      end

      gray = 8 + (index - 232) * 10
      Color.new(gray.to_u8, gray.to_u8, gray.to_u8)
    end
  end
end
