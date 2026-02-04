require "./buffer"

module Ultraviolet
  class Window
    include Screen
    include Drawable

    getter buffer : Buffer
    getter parent : Window?
    getter bounds : Rectangle
    getter method : WidthMethod

    def initialize(
      @buffer : Buffer,
      @bounds : Rectangle,
      @method : WidthMethod,
      @parent : Window? = nil,
    )
    end

    def has_parent? : Bool
      !@parent.nil?
    end

    def move_to(x : Int32, y : Int32) : Nil
      @bounds = Ultraviolet.rect(x, y, @bounds.dx, @bounds.dy)
    end

    def move_by(dx : Int32, dy : Int32) : Nil
      @bounds = Ultraviolet.rect(@bounds.min.x + dx, @bounds.min.y + dy, @bounds.dx, @bounds.dy)
    end

    def clone : Window
      clone_area(@buffer.bounds)
    end

    def clone_area(area : Rectangle) : Window
      clone_buffer = @buffer.clone_area(area) || Buffer.new(0, 0)
      Window.new(clone_buffer, area, @method, @parent)
    end

    def resize(width : Int32, height : Int32) : Nil
      raise ErrInvalidDimensions if width < 0 || height < 0

      parent = @parent
      if parent.nil? || @buffer != parent.buffer
        @buffer.resize(width, height)
      end

      @bounds = Ultraviolet.rect(@bounds.min.x, @bounds.min.y, width, height)
    end

    def width_method : WidthMethod
      @method
    end

    def width : Int32
      @bounds.dx
    end

    def height : Int32
      @bounds.dy
    end

    def cell_at(x : Int32, y : Int32) : Cell?
      return if x < 0 || y < 0
      return if x >= width || y >= height
      @buffer.cell_at(x + @bounds.min.x, y + @bounds.min.y)
    end

    def set_cell(x : Int32, y : Int32, cell : Cell?) : Nil
      return if x < 0 || y < 0
      return if x >= width || y >= height
      @buffer.set_cell(x + @bounds.min.x, y + @bounds.min.y, cell)
    end

    def draw(screen : Screen, area : Rectangle) : Nil
      @buffer.draw(screen, area)
    end

    def new_window(x : Int32, y : Int32, width : Int32, height : Int32) : Window
      Window.new_window(self, x, y, width, height, @method, false)
    end

    def new_view(x : Int32, y : Int32, width : Int32, height : Int32) : Window
      Window.new_window(self, x, y, width, height, @method, true)
    end

    def width_method=(method : WidthMethod) : Nil
      @method = method
    end

    def self.new_screen(width : Int32, height : Int32) : Window
      Window.new_window(nil, 0, 0, width, height, DEFAULT_WIDTH_METHOD, false)
    end

    private def self.new_window(
      parent : Window?,
      x : Int32,
      y : Int32,
      width : Int32,
      height : Int32,
      method : WidthMethod,
      view : Bool,
    ) : Window
      raise ErrInvalidDimensions if width < 0 || height < 0

      buffer = if view && parent
                 parent.buffer
               else
                 Buffer.new(width, height)
               end
      Window.new(buffer, Ultraviolet.rect(x, y, width, height), method, parent)
    end
  end

  def self.new_screen(width : Int32, height : Int32) : Window
    Window.new_screen(width, height)
  end
end
