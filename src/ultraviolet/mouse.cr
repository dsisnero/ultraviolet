module Ultraviolet
  enum MouseMode
    None
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
