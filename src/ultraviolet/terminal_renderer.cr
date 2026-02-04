require "uniwidth"

module Ultraviolet
  ErrInvalidDimensions = Exception.new("invalid dimensions")

  @[Flags]
  enum Capabilities
    None = 0
    VPA
    HPA
    CHA
    CHT
    CBT
    REP
    ECH
    ICH
    SD
    SU
    HT
    BS
  end

  @[Flags]
  enum TerminalFlags
    RelativeCursor
    Fullscreen
    MapNewline
    ScrollOptim
  end

  struct CursorState
    property cell : Cell
    property position : Position

    def initialize(@cell : Cell = EMPTY_CELL, @position : Position = Position.new(-1, -1))
    end
  end

  struct LineData
    property first_cell : Int32
    property last_cell : Int32
    property old_index : Int32

    def initialize(@first_cell : Int32 = -1, @last_cell : Int32 = -1, @old_index : Int32 = 0)
    end
  end

  class TerminalRenderer
    @writer : IO
    @buf : IO::Memory
    @curbuf : RenderBuffer?
    @tabs : TabStops?
    @flags : TerminalFlags
    @term : String
    @scroll_height : Int32
    @clear : Bool
    @caps : Capabilities
    @at_phantom : Bool
    @logger : Logger?
    @profile : ColorProfile
    @cur : CursorState
    @saved : CursorState

    def initialize(@writer : IO, env : Array(String) = [] of String)
      @profile = ColorProfile::TrueColor
      @buf = IO::Memory.new
      @term = Environ.new(env).getenv("TERM")
      @caps = xterm_caps(@term)
      @flags = TerminalFlags::RelativeCursor
      @cur = CursorState.new
      @saved = @cur
      @scroll_height = 0
      @clear = false
      @at_phantom = false
    end

    def logger=(logger : Logger?) : Nil
      @logger = logger
    end

    def color_profile=(profile : ColorProfile) : Nil
      @profile = profile
    end

    def scroll_optim=(enabled : Bool) : Nil
      if enabled
        @flags |= TerminalFlags::ScrollOptim
      else
        @flags &= ~TerminalFlags::ScrollOptim
      end
    end

    def map_newline=(enabled : Bool) : Nil
      if enabled
        @flags |= TerminalFlags::MapNewline
      else
        @flags &= ~TerminalFlags::MapNewline
      end
    end

    def backspace=(enabled : Bool) : Nil
      if enabled
        @caps |= Capabilities::BS
      else
        @caps &= ~Capabilities::BS
      end
    end

    def tab_stops=(width : Int32) : Nil
      if width < 0 || @term.starts_with?("linux")
        @caps &= ~Capabilities::HT
      else
        @caps |= Capabilities::HT
        @tabs = TabStops.default(width)
      end
    end

    def fullscreen=(enabled : Bool) : Nil
      if enabled
        @flags |= TerminalFlags::Fullscreen
      else
        @flags &= ~TerminalFlags::Fullscreen
      end
    end

    def fullscreen? : Bool
      (@flags & TerminalFlags::Fullscreen) == TerminalFlags::Fullscreen
    end

    def relative_cursor=(enabled : Bool) : Nil
      if enabled
        @flags |= TerminalFlags::RelativeCursor
      else
        @flags &= ~TerminalFlags::RelativeCursor
      end
    end

    def save_cursor : Nil
      @saved = @cur
    end

    def restore_cursor : Nil
      @cur = @saved
    end

    def enter_alt_screen : Nil
      save_cursor
      @buf << "\e[?1049h"
      self.fullscreen = true
      self.relative_cursor = false
      erase
    end

    def exit_alt_screen : Nil
      erase
      self.relative_cursor = true
      self.fullscreen = false
      @buf << "\e[?1049l"
      restore_cursor
    end

    def erase : Nil
      @clear = true
    end

    def resize(width : Int32, _height : Int32) : Nil
      @tabs.try &.resize(width)
      @scroll_height = 0
    end

    def position : {Int32, Int32}
      {@cur.position.x, @cur.position.y}
    end

    def set_position(x : Int32, y : Int32) : Nil
      @cur.position = Position.new(x, y)
    end

    def write_string(value : String) : Int32
      @buf << value
      value.bytesize
    end

    def write(bytes : Bytes) : Int32
      @buf.write(bytes)
    end

    def render(buffer : RenderBuffer) : Nil
      if @clear
        @buf << "\e[2J"
        @clear = false
      end
      @buf << buffer.render
    end

    def prepend_string(buffer : RenderBuffer, value : String) : Nil
      return if value.empty?

      width = buffer.width
      height = buffer.height
      move_to(0, height - 1)

      lines = value.split("\n")
      offset = 0
      lines.each do |line|
        line_width = UnicodeCharWidth.width(line)
        if width > 0 && line_width > width
          offset += line_width // width
        end
        if line_width == 0 || width == 0 || (line_width % width) != 0
          offset += 1
        end
      end

      @buf << ("\n" * offset) if offset > 0
      move_to(0, 0)
      @buf << "\e[#{offset}L" if offset > 0
      lines.each do |line|
        @buf << line
        @buf << "\r\n"
      end
    end

    def move_to(x : Int32, y : Int32) : Nil
      @buf << "\e[#{y + 1};#{x + 1}H"
      @cur.position = Position.new(x, y)
    end

    def buffered : Int32
      @buf.size
    end

    def touched(buffer : RenderBuffer) : Int32
      buffer.touched_lines
    end

    def flush : Nil
      @writer.write(@buf.to_slice)
      @buf.clear
    end

    private def xterm_caps(termtype : String) : Capabilities
      parts = termtype.split('-')
      return Capabilities::None if parts.empty?

      caps = Capabilities::None
      base = parts[0]?
      case base
      when "contour", "foot", "ghostty", "kitty", "rio", "st", "tmux", "wezterm"
        caps = all_caps
      when "xterm"
        if parts.size > 1 && {"ghostty", "kitty", "rio"}.includes?(parts[1])
          caps = all_caps
        else
          caps = all_caps
          caps &= ~Capabilities::HPA
          caps &= ~Capabilities::CHT
          caps &= ~Capabilities::REP
        end
      when "alacritty"
        caps = all_caps
        caps &= ~Capabilities::CHT
      when "screen"
        caps = all_caps
        caps &= ~Capabilities::REP
      when "linux"
        caps = Capabilities::VPA | Capabilities::CHA | Capabilities::HPA | Capabilities::ECH | Capabilities::ICH
      end

      caps
    end

    private def all_caps : Capabilities
      Capabilities::VPA | Capabilities::HPA | Capabilities::CHA | Capabilities::CHT | Capabilities::CBT |
        Capabilities::REP | Capabilities::ECH | Capabilities::ICH | Capabilities::SD | Capabilities::SU
    end
  end
end
