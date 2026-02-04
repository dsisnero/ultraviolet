module Ultraviolet
  alias EventSingle = UnknownEvent |
                      UnknownCsiEvent |
                      UnknownSs3Event |
                      UnknownOscEvent |
                      UnknownDcsEvent |
                      UnknownSosEvent |
                      UnknownPmEvent |
                      UnknownApcEvent |
                      Size |
                      Key |
                      Mouse |
                      MouseClickEvent |
                      MouseReleaseEvent |
                      MouseWheelEvent |
                      MouseMotionEvent |
                      CursorPositionEvent |
                      FocusEvent |
                      BlurEvent |
                      DarkColorSchemeEvent |
                      LightColorSchemeEvent |
                      PasteEvent |
                      PasteStartEvent |
                      PasteEndEvent |
                      TerminalVersionEvent |
                      ModifyOtherKeysEvent |
                      KittyGraphicsEvent |
                      KeyboardEnhancementsEvent |
                      ModeReportEvent |
                      ForegroundColorEvent |
                      BackgroundColorEvent |
                      CursorColorEvent |
                      WindowOpEvent |
                      CapabilityEvent |
                      ClipboardEvent |
                      String |
                      Array(Int32)

  alias Event = EventSingle | Array(EventSingle)

  module EventStreamer
    abstract def stream_events(ctx, ch)
  end

  struct UnknownEvent
    getter value : String

    def initialize(@value : String)
    end

    def string : String
      @value.inspect
    end
  end

  struct UnknownCsiEvent
    getter value : String

    def initialize(@value : String)
    end

    def string : String
      @value.inspect
    end
  end

  struct UnknownSs3Event
    getter value : String

    def initialize(@value : String)
    end

    def string : String
      @value.inspect
    end
  end

  struct UnknownOscEvent
    getter value : String

    def initialize(@value : String)
    end

    def string : String
      @value.inspect
    end
  end

  struct UnknownDcsEvent
    getter value : String

    def initialize(@value : String)
    end

    def string : String
      @value.inspect
    end
  end

  struct UnknownSosEvent
    getter value : String

    def initialize(@value : String)
    end

    def string : String
      @value.inspect
    end
  end

  struct UnknownPmEvent
    getter value : String

    def initialize(@value : String)
    end

    def string : String
      @value.inspect
    end
  end

  struct UnknownApcEvent
    getter value : String

    def initialize(@value : String)
    end

    def string : String
      @value.inspect
    end
  end

  alias MultiEvent = Array(EventSingle)

  def self.multi_event_string(events : MultiEvent) : String
    String.build do |builder|
      events.each do |event|
        case event
        when Key
          builder << event.string
        when Mouse
          builder << event.string
        when MouseClickEvent
          builder << event.string
        when MouseReleaseEvent
          builder << event.string
        when MouseWheelEvent
          builder << event.string
        when MouseMotionEvent
          builder << event.string
        else
          builder << event.to_s
        end
        builder << '\n'
      end
    end
  end

  struct Size
    property width : Int32
    property height : Int32

    def initialize(@width : Int32, @height : Int32)
    end

    def bounds : Rectangle
      Rectangle.new(Position.new(0, 0), Position.new(@width, @height))
    end
  end

  alias WindowSizeEvent = Size
  alias PixelSizeEvent = Size
  alias CellSizeEvent = Size

  alias KeyPressEvent = Key
  alias KeyReleaseEvent = Key

  struct MouseClickEvent
    property mouse : Mouse

    def initialize(@mouse : Mouse)
    end

    def string : String
      @mouse.string
    end
  end

  struct MouseReleaseEvent
    property mouse : Mouse

    def initialize(@mouse : Mouse)
    end

    def string : String
      @mouse.string
    end
  end

  struct MouseWheelEvent
    property mouse : Mouse

    def initialize(@mouse : Mouse)
    end

    def string : String
      @mouse.string
    end
  end

  struct MouseMotionEvent
    property mouse : Mouse

    def initialize(@mouse : Mouse)
    end

    def string : String
      base = @mouse.string
      if @mouse.button != MouseButton::None
        "#{base}+motion"
      else
        "#{base}motion"
      end
    end
  end

  struct CursorPositionEvent
    property y : Int32
    property x : Int32

    def initialize(@y : Int32, @x : Int32)
    end
  end

  struct FocusEvent
  end

  struct BlurEvent
  end

  struct DarkColorSchemeEvent
  end

  struct LightColorSchemeEvent
  end

  struct PasteEvent
    property content : String

    def initialize(@content : String = "")
    end

    def string : String
      @content
    end
  end

  struct PasteStartEvent
  end

  struct PasteEndEvent
  end

  struct TerminalVersionEvent
    property name : String

    def initialize(@name : String = "")
    end

    def string : String
      @name
    end
  end

  struct ModifyOtherKeysEvent
    property mode : Int32

    def initialize(@mode : Int32 = 0)
    end
  end

  struct KittyGraphicsEvent
    property options : Hash(String, String)
    property payload : Bytes

    def initialize(@options : Hash(String, String) = {} of String => String, @payload : Bytes = Bytes.empty)
    end
  end

  struct KeyboardEnhancementsEvent
    property flags : Int32

    def initialize(@flags : Int32 = 0)
    end

    def contains?(enhancements : Int32) : Bool
      (@flags & enhancements) == enhancements
    end

    def supports_key_disambiguation? : Bool
      (@flags & Ansi::KittyDisambiguateEscapeCodes) != 0
    end

    def supports_key_releases? : Bool
      (@flags & Ansi::KittyReportEventTypes) != 0
    end

    def supports_uniform_key_layout? : Bool
      supports_key_disambiguation? &&
        (@flags & Ansi::KittyReportAlternateKeys) != 0 &&
        (@flags & Ansi::KittyReportAllKeysAsEscapeCodes) != 0
    end
  end

  alias PrimaryDeviceAttributesEvent = Array(Int32)
  alias SecondaryDeviceAttributesEvent = Array(Int32)
  alias TertiaryDeviceAttributesEvent = String

  struct ModeReportEvent
    property mode : Int32
    property value : Int32

    def initialize(@mode : Int32 = 0, @value : Int32 = 0)
    end
  end

  struct ForegroundColorEvent
    property color : Color

    def initialize(@color : Color)
    end

    def string : String
      Ultraviolet.color_to_hex(@color)
    end

    def dark? : Bool
      Ultraviolet.dark_color?(@color)
    end
  end

  struct BackgroundColorEvent
    property color : Color

    def initialize(@color : Color)
    end

    def string : String
      Ultraviolet.color_to_hex(@color)
    end

    def dark? : Bool
      Ultraviolet.dark_color?(@color)
    end
  end

  struct CursorColorEvent
    property color : Color

    def initialize(@color : Color)
    end

    def string : String
      Ultraviolet.color_to_hex(@color)
    end

    def dark? : Bool
      Ultraviolet.dark_color?(@color)
    end
  end

  struct WindowOpEvent
    property op : Int32
    property args : Array(Int32)

    def initialize(@op : Int32 = 0, @args : Array(Int32) = [] of Int32)
    end
  end

  struct CapabilityEvent
    property content : String

    def initialize(@content : String = "")
    end

    def string : String
      @content
    end
  end

  alias ClipboardSelection = Char
  SystemClipboard  = 'c'
  PrimaryClipboard = 'p'

  struct ClipboardEvent
    property content : String
    property selection : ClipboardSelection

    def initialize(@content : String = "", @selection : ClipboardSelection = '\0')
    end

    def string : String
      @content
    end

    def clipboard : ClipboardSelection
      @selection
    end
  end

  alias IgnoredEvent = String

  def self.color_to_hex(color : Color) : String
    "#%02x%02x%02x" % [color.r, color.g, color.b]
  end

  def self.dark_color?(color : Color) : Bool
    _, _, lightness = rgb_to_hsl(color.r, color.g, color.b)
    lightness < 0.5
  end

  def self.rgb_to_hsl(r : UInt8, g : UInt8, b : UInt8) : {Float64, Float64, Float64}
    rf = r.to_f64 / 255.0
    gf = g.to_f64 / 255.0
    bf = b.to_f64 / 255.0
    max, min = max_min(rf, gf, bf)
    lightness = (max + min) / 2.0

    if max == min
      return {0.0, 0.0, lightness}
    end

    delta = max - min
    saturation = delta / (1.0 - (2.0 * lightness - 1.0).abs)
    hue = if max == rf
            (gf - bf) / delta
          elsif max == gf
            (bf - rf) / delta + 2.0
          else
            (rf - gf) / delta + 4.0
          end
    hue *= 60.0
    hue += 360.0 if hue < 0.0

    {round2(hue), round2(saturation), round2(lightness)}
  end

  private def self.max_min(r : Float64, g : Float64, b : Float64) : {Float64, Float64}
    max = r
    max = g if g > max
    max = b if b > max
    min = r
    min = g if g < min
    min = b if b < min
    {max, min}
  end

  private def self.round2(value : Float64) : Float64
    (value * 100.0).round / 100.0
  end
end
