module Ultraviolet
  struct Position
    getter x : Int32
    getter y : Int32

    def initialize(@x : Int32, @y : Int32)
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
  end

  def self.pos(x : Int32, y : Int32) : Position
    Position.new(x, y)
  end

  def self.rect(x : Int32, y : Int32, w : Int32, h : Int32) : Rectangle
    Rectangle.new(Position.new(x, y), Position.new(x + w, y + h))
  end
end
