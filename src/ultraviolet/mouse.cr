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

    # ameba:disable Metrics/CyclomaticComplexity
    def string : String
      case self
      when None
        "none"
      when Left
        "left"
      when Middle
        "middle"
      when Right
        "right"
      when WheelUp
        "wheelup"
      when WheelDown
        "wheeldown"
      when WheelLeft
        "wheelleft"
      when WheelRight
        "wheelright"
      when Backward
        "backward"
      when Forward
        "forward"
      when Button10
        "button10"
      when Button11
        "button11"
      else
        ""
      end
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
    # ameba:enable Metrics/CyclomaticComplexity
  end
end
