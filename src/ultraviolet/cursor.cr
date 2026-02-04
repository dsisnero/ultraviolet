module Ultraviolet
  enum CursorShape
    Block
    Underline
    Bar

    def encode(blink : Bool) : Int32
      encoded = (self.to_i * 2) + 1
      encoded += 1 unless blink
      encoded
    end
  end

  struct Cursor
    property position : Position
    property color : Color?
    property shape : CursorShape
    property? blink : Bool

    def initialize(
      @position : Position,
      @color : Color? = nil,
      @shape : CursorShape = CursorShape::Block,
      @blink : Bool = true,
    )
    end
  end

  def self.new_cursor(x : Int32, y : Int32) : Cursor
    Cursor.new(Position.new(x, y))
  end
end
