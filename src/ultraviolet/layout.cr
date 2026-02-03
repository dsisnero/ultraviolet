module Ultraviolet
  module Constraint
    abstract def apply(size : Int32) : Int32
  end

  struct Percent
    include Constraint

    getter value : Int32

    def initialize(@value : Int32)
    end

    def apply(size : Int32) : Int32
      return 0 if @value < 0
      return size if @value > 100
      size * @value // 100
    end
  end

  def self.ratio(numerator : Int32, denominator : Int32) : Percent
    return Percent.new(0) if denominator == 0
    Percent.new(numerator * 100 // denominator)
  end

  struct Fixed
    include Constraint

    getter value : Int32

    def initialize(@value : Int32)
    end

    def apply(size : Int32) : Int32
      return 0 if @value < 0
      return size if @value > size
      @value
    end
  end

  def self.split_vertical(area : Rectangle, constraint : Constraint) : {Rectangle, Rectangle}
    height = {constraint.apply(area.dy), area.dy}.min
    top = Rectangle.new(area.min, Position.new(area.max.x, area.min.y + height))
    bottom = Rectangle.new(Position.new(area.min.x, area.min.y + height), area.max)
    {top, bottom}
  end

  def self.split_horizontal(area : Rectangle, constraint : Constraint) : {Rectangle, Rectangle}
    width = {constraint.apply(area.dx), area.dx}.min
    left = Rectangle.new(area.min, Position.new(area.min.x + width, area.max.y))
    right = Rectangle.new(Position.new(area.min.x + width, area.min.y), area.max)
    {left, right}
  end

  def self.center_rect(area : Rectangle, width : Int32, height : Int32) : Rectangle
    center_x = area.min.x + area.dx // 2
    center_y = area.min.y + area.dy // 2
    min_x = center_x - width // 2
    min_y = center_y - height // 2
    Rectangle.new(Position.new(min_x, min_y), Position.new(min_x + width, min_y + height))
  end

  def self.top_left_rect(area : Rectangle, width : Int32, height : Int32) : Rectangle
    rect = Rectangle.new(
      Position.new(area.min.x, area.min.y),
      Position.new(area.min.x + width, area.min.y + height)
    )
    rect.intersect(area)
  end

  def self.top_center_rect(area : Rectangle, width : Int32, height : Int32) : Rectangle
    center_x = area.min.x + area.dx // 2
    min_x = center_x - width // 2
    rect = Rectangle.new(
      Position.new(min_x, area.min.y),
      Position.new(min_x + width, area.min.y + height)
    )
    rect.intersect(area)
  end

  def self.top_right_rect(area : Rectangle, width : Int32, height : Int32) : Rectangle
    rect = Rectangle.new(
      Position.new(area.max.x - width, area.min.y),
      Position.new(area.max.x, area.min.y + height)
    )
    rect.intersect(area)
  end

  def self.right_center_rect(area : Rectangle, width : Int32, height : Int32) : Rectangle
    center_y = area.min.y + area.dy // 2
    min_y = center_y - height // 2
    rect = Rectangle.new(
      Position.new(area.max.x - width, min_y),
      Position.new(area.max.x, min_y + height)
    )
    rect.intersect(area)
  end

  def self.left_center_rect(area : Rectangle, width : Int32, height : Int32) : Rectangle
    center_y = area.min.y + area.dy // 2
    min_y = center_y - height // 2
    rect = Rectangle.new(
      Position.new(area.min.x, min_y),
      Position.new(area.min.x + width, min_y + height)
    )
    rect.intersect(area)
  end

  def self.bottom_left_rect(area : Rectangle, width : Int32, height : Int32) : Rectangle
    rect = Rectangle.new(
      Position.new(area.min.x, area.max.y - height),
      Position.new(area.min.x + width, area.max.y)
    )
    rect.intersect(area)
  end

  def self.bottom_center_rect(area : Rectangle, width : Int32, height : Int32) : Rectangle
    center_x = area.min.x + area.dx // 2
    min_x = center_x - width // 2
    rect = Rectangle.new(
      Position.new(min_x, area.max.y - height),
      Position.new(min_x + width, area.max.y)
    )
    rect.intersect(area)
  end

  def self.bottom_right_rect(area : Rectangle, width : Int32, height : Int32) : Rectangle
    rect = Rectangle.new(
      Position.new(area.max.x - width, area.max.y - height),
      Position.new(area.max.x, area.max.y)
    )
    rect.intersect(area)
  end
end
