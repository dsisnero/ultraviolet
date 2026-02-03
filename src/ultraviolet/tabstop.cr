module Ultraviolet
  DEFAULT_TAB_INTERVAL = 8

  class TabStops
    getter stops : Array(Int32)
    getter interval : Int32
    getter width : Int32

    def initialize(@width : Int32, @interval : Int32)
      @stops = Array(Int32).new((@width + (@interval - 1)) // @interval, 0)
      init(0, @width)
    end

    def self.default(cols : Int32) : TabStops
      TabStops.new(cols, DEFAULT_TAB_INTERVAL)
    end

    def resize(width : Int32) : Nil
      return if width == @width

      if width < @width
        size = (width + (@interval - 1)) // @interval
        @stops = @stops[0, size]
      else
        size = (width - @width + (@interval - 1)) // @interval
        @stops.concat(Array(Int32).new(size, 0))
      end

      init(@width, width)
      @width = width
    end

    def stop?(col : Int32) : Bool
      idx = col >> 3
      return false if idx < 0 || idx >= @stops.size
      (@stops[idx] & mask(col)) != 0
    end

    def next(col : Int32) : Int32
      find(col, 1)
    end

    def prev(col : Int32) : Int32
      find(col, -1)
    end

    def find(col : Int32, delta : Int32) : Int32
      return col if delta == 0

      count = delta
      prev = false
      if count < 0
        count = -count
        prev = true
      end

      while count > 0
        if !prev
          return col if col >= @width - 1
          col += 1
        else
          return col if col < 1
          col -= 1
        end

        count -= 1 if stop?(col)
      end

      col
    end

    def set(col : Int32) : Nil
      @stops[col >> 3] |= mask(col)
    end

    def reset(col : Int32) : Nil
      @stops[col >> 3] &= ~mask(col)
    end

    def clear : Nil
      @stops = Array(Int32).new(@stops.size, 0)
    end

    private def mask(col : Int32) : Int32
      1 << (col & (@interval - 1))
    end

    private def init(col : Int32, width : Int32) : Nil
      x = col
      while x < width
        if x % @interval == 0
          set(x)
        else
          reset(x)
        end
        x += 1
      end
    end
  end
end
