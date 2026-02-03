module Ultraviolet
  struct Position
    getter x : Int32
    getter y : Int32

    def initialize(@x : Int32, @y : Int32)
    end

    def in?(rect : Rectangle) : Bool
      @x >= rect.min.x && @x < rect.max.x &&
        @y >= rect.min.y && @y < rect.max.y
    end
  end

  struct Rectangle
    getter min : Position
    getter max : Position

    def initialize(@min : Position, @max : Position)
    end

    def dx : Int32
      @max.x - @min.x
    end

    def dy : Int32
      @max.y - @min.y
    end

    def empty? : Bool
      dx <= 0 || dy <= 0
    end

    def in?(other : Rectangle) : Bool
      @min.x >= other.min.x && @min.y >= other.min.y &&
        @max.x <= other.max.x && @max.y <= other.max.y
    end

    def overlaps?(other : Rectangle) : Bool
      return false if empty? || other.empty?
      @min.x < other.max.x && @max.x > other.min.x &&
        @min.y < other.max.y && @max.y > other.min.y
    end

    def intersect(other : Rectangle) : Rectangle
      min_x = {@min.x, other.min.x}.max
      min_y = {@min.y, other.min.y}.max
      max_x = {@max.x, other.max.x}.min
      max_y = {@max.y, other.max.y}.min
      if max_x < min_x || max_y < min_y
        return Rectangle.new(Position.new(0, 0), Position.new(0, 0))
      end
      Rectangle.new(Position.new(min_x, min_y), Position.new(max_x, max_y))
    end
  end

  def self.pos(x : Int32, y : Int32) : Position
    Position.new(x, y)
  end

  def self.rect(x : Int32, y : Int32, w : Int32, h : Int32) : Rectangle
    Rectangle.new(Position.new(x, y), Position.new(x + w, y + h))
  end
end
