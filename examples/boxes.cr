require "../src/ultraviolet"

# Port of charmbracelet/ultraviolet examples/advanced/boxes.
#
# A root window holds randomly colored child windows:
#   - left click on empty root space creates a new window centered on the click
#   - left click on a window focuses it, raises it and starts dragging it
#   - right click destroys every window under the cursor
#   - typing prints into the active window
#   - ctrl+c or esc quits
#
# Differences from the Go example:
#   - The Go example writes debug output to uv.log; this port logs nothing.
#   - AppWindow has no z field. Go stores one but never sets it, so its stable
#     sort is a no-op and the z-order slice order is the paint order.
#   - Go's TerminalScreen has SetMouseMode; Crystal's Terminal does not, so the
#     drag mouse mode is emitted with the ANSI helpers (like examples/mouse.cr).
#   - Go's scr.Display(app) clears the screen and draws in one call; here the
#     loop calls term.clear, app.draw, then term.display.
#   - The root context draws into the root window. Go's root context draws into
#     the top-level screen it composites onto, so typed text at the root was
#     discarded every frame; both behave the same, visually.
module Boxes
  ROOT_ID = "root"

  BLACK = Ultraviolet::Color.new(0_u8, 0_u8, 0_u8)

  # A window owned by the app.
  class AppWindow
    getter id : String
    getter win : Ultraviolet::Window
    getter ctx : Ultraviolet::Screen::Context
    property style : Ultraviolet::Style

    def initialize(
      @id : String,
      @win : Ultraviolet::Window,
      @ctx : Ultraviolet::Screen::Context,
      @style : Ultraviolet::Style = Ultraviolet::Style.new,
    )
    end

    def bounds : Ultraviolet::Rectangle
      @win.bounds
    end

    def draw(screen : Ultraviolet::Screen, area : Ultraviolet::Rectangle) : Nil
      @win.draw(screen, area)
    end

    def resize(width : Int32, height : Int32) : Nil
      @win.resize(width, height)
    end

    def context : Ultraviolet::Screen::Context
      @ctx
    end
  end

  class App
    include Ultraviolet::Drawable

    getter root : AppWindow
    getter wins : Hash(String, AppWindow)
    getter zwins : Array(AppWindow)
    property active : String
    property? quit : Bool
    @last_clicked : String
    @mouse_down : Bool

    def initialize(width : Int32, height : Int32, method : Ultraviolet::WidthMethod)
      # Go uses uv.NewWindow(width, height, method) for the top-level screen.
      root_win = Ultraviolet::Window.new_window(width, height, method)
      root = AppWindow.new(
        ROOT_ID,
        root_win,
        Ultraviolet::Screen::Context.new(root_win),
      )

      @root = root
      @wins = {ROOT_ID => root}
      @zwins = [root]
      @active = ROOT_ID
      @quit = false
      @last_clicked = ""
      @mouse_down = false
    end

    # Brings the window with the given id to the front.
    def bring_to_front(id : String) : Nil
      awin = @wins[id]?
      return unless awin

      if index = @zwins.index { |zw| zw.id == id }
        @zwins.delete_at(index)
      end

      @zwins << awin
    end

    # Creates a new window at the given position and size.
    def create_window(id : String, x : Int32, y : Int32, width : Int32, height : Int32) : AppWindow
      style = Ultraviolet::Style.new(bg: Ultraviolet::AnsiColor.indexed(rand(256)))

      win = @root.win.new_window(x, y, width, height)
      # Go's Window embeds *Buffer, so Window.Fill is Buffer.Fill; Crystal's
      # Window does not promote those, so fill the owned buffer directly.
      win.buffer.fill(Ultraviolet::Cell.new(" ", 1, style))

      awin = AppWindow.new(id, win, Ultraviolet::Screen::Context.new(win), style)
      @wins[id] = awin
      @zwins << awin
      awin
    end

    # Destroys the window with the given id.
    def destroy_window(id : String) : Nil
      return unless @wins.has_key?(id)

      @wins.delete(id)
      if index = @zwins.index { |zw| zw.id == id }
        @zwins.delete_at(index)
      end
      @active = ROOT_ID if @active == id
    end

    # Returns the window with the given id, if any.
    def window(id : String) : Ultraviolet::Window?
      awin = @wins[id]?
      awin.try(&.win)
    end

    # Returns the parent window id of the given window id, or an empty string.
    def parent_id(id : String) : String
      awin = @wins[id]?
      return "" unless awin

      parent = awin.win.parent
      return "" unless parent

      @wins.each do |wid, other|
        return wid if other.win.same?(parent)
      end

      ""
    end

    # Draws the app's windows into the root window, then the root into screen.
    def draw(screen : Ultraviolet::Screen, area : Ultraviolet::Rectangle) : Nil
      # Go's screen.Clear(root.win) promotes to Buffer.Clear on the window.
      @root.win.buffer.clear

      @zwins.each do |zw|
        next if zw.id == ROOT_ID
        zw.draw(@root.win, zw.bounds)
      end

      @root.draw(screen, area)
    end

    # Resizes the root window, e.g. on a terminal resize.
    def resize(width : Int32, height : Int32) : Nil
      @root.resize(width, height)
    end

    # Handles an event for the given window. Returns true when handled.
    def handle_event(id : String, ev : Ultraviolet::Event) : Bool
      win = window(id)
      return false unless win

      case ev
      when Ultraviolet::Key
        if ev.match_string("ctrl+c", "esc")
          @quit = true
          return true
        end

        active_win = @wins[@active]?
        return false unless active_win

        ctx = active_win.context
        ctx.set_style(active_win.style)
        ctx.set_foreground(BLACK)

        if ev.match_string("backspace")
          x, y = ctx.position
          x -= 1
          if x < 0
            x = active_win.bounds.dx - 1
            y -= 1
            y = 0 if y < 0
          end
          ctx.set_position(x, y)
          ctx.print(" ")
          ctx.set_position(x, y)
          true
        elsif ev.match_string("enter")
          ctx.print("\n")
          true
        elsif !ev.text.empty?
          ctx.print(ev.text)
          true
        else
          false
        end
      when Ultraviolet::MouseMotionEvent
        if @mouse_down && @last_clicked == id
          # Move the window so the cursor keeps its relative spot.
          bounds = win.bounds
          new_x = ev.x - bounds.dx // 2
          new_y = ev.y - bounds.dy // 2
          win.move_to(new_x, new_y)
          true
        else
          false
        end
      when Ultraviolet::MouseReleaseEvent
        @mouse_down = false
        @last_clicked = ""
        true
      when Ultraviolet::MouseClickEvent
        @mouse_down = true

        case ev.button
        when Ultraviolet::MouseButton::Left
          pos = Ultraviolet.pos(ev.x, ev.y)
          @zwins.reverse_each do |zw|
            next if zw.id == ROOT_ID
            next unless pos.in?(zw.bounds)

            @active = zw.id
            bring_to_front(zw.id)
            @last_clicked = zw.id
            return true
          end

          # Nothing hit: the root creates a new window, which only happens once
          # the event bubbles up to the root window.
          return false unless id == ROOT_ID

          width = 0
          height = 0
          while width == 0 || height == 0
            width = rand(20)
            height = rand(10)
          end

          x = ev.x - width // 2
          y = ev.y - height // 2
          x = 0 if x < 0
          y = 0 if y < 0

          root_bounds = @root.bounds
          x = root_bounds.dx - width if x + width > root_bounds.dx
          y = root_bounds.dy - height if y + height > root_bounds.dy

          win_id = "win-#{@wins.size}"
          create_window(win_id, x, y, width, height)
          @active = win_id
          true
        when Ultraviolet::MouseButton::Right
          # Go destroys while iterating its z-order slice, which can skip
          # windows; collect the hits first and destroy them afterwards.
          pos = Ultraviolet.pos(ev.x, ev.y)
          doomed = @zwins.select { |zw| zw.id != ROOT_ID && pos.in?(zw.bounds) }
          doomed.each { |zw| destroy_window(zw.id) }
          true
        else
          false
        end
      else
        false
      end
    end
  end

  def self.run
    term = Ultraviolet::Terminal.default_terminal
    term.start
    term.enter_alt_screen
    term.hide_cursor

    # Go uses scr.SetMouseMode(uv.MouseModeDrag). Crystal's Terminal has no
    # set_mouse_mode (only TerminalScreen does), so emit it with ANSI helpers.
    mouse_mode = ->(mode : Ultraviolet::MouseMode) do
      String.build { |io| Ultraviolet.encode_mouse_mode(io, mode) }
    end
    term.write_string(mouse_mode.call(Ultraviolet::MouseMode::Drag))

    width, height = term.fetch_size
    app = App.new(width, height, term.width_method)

    begin
      until app.quit?
        ev = term.events.receive

        # A resize changes both the terminal screen and the root window.
        case ev
        when Ultraviolet::WindowSizeEvent
          term.resize(ev.width, ev.height)
          app.resize(ev.width, ev.height)
        end

        focused_id = app.active
        next if focused_id.empty?

        # Bubble unhandled events up to the parent window, ending at the root.
        until app.handle_event(focused_id, ev)
          parent = app.parent_id(focused_id)
          break if parent.empty?
          focused_id = parent
        end

        term.clear
        app.draw(term, term.bounds)
        term.display
      end
    ensure
      term.write_string(mouse_mode.call(Ultraviolet::MouseMode::None))
      term.shutdown(1.second)
    end
  end
end

Boxes.run if __FILE__ == $0
