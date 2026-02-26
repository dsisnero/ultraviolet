module Ultraviolet
  class TerminalScreen
    include Screen

    @screen : ScreenBuffer
    @renderer : TerminalRenderer
    @alt_screen : Bool

    def initialize(writer : IO, env : Array(String) = [] of String)
      @screen = ScreenBuffer.new(0, 0)
      @renderer = TerminalRenderer.new(writer, env)
      @renderer.fullscreen = false
      @renderer.relative_cursor = true
      @renderer.color_profile = ColorProfile.detect(writer, env)
      @alt_screen = false
    end

    def cell_at(x : Int32, y : Int32) : Cell?
      @screen.cell_at(x, y)
    end

    def set_cell(x : Int32, y : Int32, cell : Cell?) : Nil
      @screen.set_cell(x, y, cell)
    end

    def bounds : Rectangle
      @screen.bounds
    end

    def width_method : WidthMethod
      @screen.width_method
    end

    def width : Int32
      @screen.width
    end

    def height : Int32
      @screen.height
    end

    def set_width_method(method : WidthMethod) : Nil
      @screen.method = method
    end

    def width_method=(method : WidthMethod) : Nil
      set_width_method(method)
    end

    def set_color_profile(profile : ColorProfile) : Nil
      @renderer.color_profile = profile
    end

    def color_profile=(profile : ColorProfile) : Nil
      set_color_profile(profile)
    end

    def resize(width : Int32, height : Int32) : Nil
      @screen.resize(width, height)
      @renderer.resize(width, height)
      @renderer.erase
      @screen.touched = Array(LineData?).new(height, nil)
    end

    def display(drawable : Drawable?) : Nil
      if drawable
        @screen.clear
        drawable.draw(self, @screen.bounds)
      end
      render
      flush
    end

    def render : Nil
      @renderer.render(@screen)
    end

    def flush : Nil
      @renderer.flush
    end

    def enter_alt_screen : Nil
      return if @alt_screen
      @renderer.enter_alt_screen
      @alt_screen = true
    end

    def exit_alt_screen : Nil
      return unless @alt_screen
      @renderer.exit_alt_screen
      @alt_screen = false
    end

    def alt_screen? : Bool
      @alt_screen
    end

    def insert_above(content : String) : Nil
      @renderer.prepend_string(@screen, content)
      @renderer.render(@screen)
      @renderer.flush
    end
  end
end
