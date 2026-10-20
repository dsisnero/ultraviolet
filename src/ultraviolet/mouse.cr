module Ultraviolet
  enum MouseMode
    None
    Press
    Click
    Drag
    Motion
  end

  enum MouseButton
    None       =  0
    Left       =  1
    Middle     =  2
    Right      =  3
    WheelUp    =  4
    WheelDown  =  5
    WheelLeft  =  6
    WheelRight =  7
    Backward   =  8
    Forward    =  9
    Button10   = 10
    Button11   = 11

    def string : String
      BUTTON_NAMES[self]? || ""
    end
  end

  enum MouseEncoding
    Legacy
    SGR
    SGRPixel
  end

  struct Mouse
    property x : Int32
    property y : Int32
    property button : MouseButton
    property mod : KeyMod

    def initialize(@x : Int32 = 0, @y : Int32 = 0, @button : MouseButton = MouseButton::None, @mod : KeyMod = 0)
    end

    def string : String
      String.build do |builder|
        builder << "ctrl+" if Ultraviolet.mod_contains?(@mod, ModCtrl)
        builder << "alt+" if Ultraviolet.mod_contains?(@mod, ModAlt)
        builder << "shift+" if Ultraviolet.mod_contains?(@mod, ModShift)

        button_str = @button.string
        if button_str.empty?
          builder << "unknown"
        elsif button_str != "none"
          builder << button_str
        end
      end
    end
  end

  # Converts a mouse event with pixel coordinates to cell coordinates.
  #
  # This is only meaningful when using `MouseEncoding::SGRPixel`, which reports
  # mouse coordinates in pixels rather than cell units. The conversion uses the
  # terminal's reported pixel and cell dimensions. When a pixel dimension is
  # unavailable, that axis is reported as zero.
  def self.mouse_pixel_to_cell(mouse : Mouse, winsize : Winsize) : Mouse
    col = 0
    row = 0

    if winsize.xpixel > 0
      col = mouse.x * winsize.col.to_i32 // winsize.xpixel.to_i32
    end
    if winsize.ypixel > 0
      row = mouse.y * winsize.row.to_i32 // winsize.ypixel.to_i32
    end

    Mouse.new(col, row, mouse.button, mouse.mod)
  end

  BUTTON_NAMES = {
    MouseButton::None       => "none",
    MouseButton::Left       => "left",
    MouseButton::Middle     => "middle",
    MouseButton::Right      => "right",
    MouseButton::WheelUp    => "wheelup",
    MouseButton::WheelDown  => "wheeldown",
    MouseButton::WheelLeft  => "wheelleft",
    MouseButton::WheelRight => "wheelright",
    MouseButton::Backward   => "backward",
    MouseButton::Forward    => "forward",
    MouseButton::Button10   => "button10",
    MouseButton::Button11   => "button11",
  }
end
