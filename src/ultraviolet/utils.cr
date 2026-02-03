module Ultraviolet
  def self.abs(value : Int32) : Int32
    value < 0 ? -value : value
  end

  def self.clamp(value : Int32, low : Int32, high : Int32) : Int32
    min = low
    max = high
    if max < min
      min, max = max, min
    end
    Math.min(max, Math.max(min, value))
  end
end
