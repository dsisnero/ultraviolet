{% if flag?(:win32) %}
  # Shared Win32 declarations for the console-based readers.
  #
  # Kept in one file so the cancel reader, the terminal reader, and the console
  # poller cannot drift into duplicate or conflicting `LibC` constants (a
  # duplicate constant is a compile error, not a warning). Declarations that
  # Crystal's own `c/consoleapi`, `c/fileapi`, and `c/handleapi` already
  # provide are intentionally absent.
  require "c/consoleapi"
  require "c/fileapi"
  require "c/winbase"
  require "c/processenv"
  require "c/ioapiset"

  lib LibC
    struct Coord
      x : Int16
      y : Int16
    end

    struct SmallRect
      left : Int16
      top : Int16
      right : Int16
      bottom : Int16
    end

    struct ConsoleScreenBufferInfo
      dwSize : Coord
      dwCursorPosition : Coord
      wAttributes : UInt16
      srWindow : SmallRect
      dwMaximumWindowSize : Coord
    end

    # Windows Console API constants
    ENABLE_WINDOW_INPUT   = 0x0008_u32
    ENABLE_EXTENDED_FLAGS = 0x0080_u32

    # Wait constants
    WAIT_ABANDONED = 0x00000080_u32

    # Console mode constants
    ENABLE_MOUSE_INPUT     = 0x0010_u32
    ENABLE_INSERT_MODE     = 0x0020_u32
    ENABLE_QUICK_EDIT_MODE = 0x0040_u32

    # Input event types
    KEY_EVENT                = 0x0001_u16
    MOUSE_EVENT              = 0x0002_u16
    WINDOW_BUFFER_SIZE_EVENT = 0x0004_u16
    MENU_EVENT               = 0x0008_u16
    FOCUS_EVENT              = 0x0010_u16

    # Mouse button constants
    FROM_LEFT_1ST_BUTTON_PRESSED = 0x0001_u32
    FROM_LEFT_2ND_BUTTON_PRESSED = 0x0004_u32
    FROM_LEFT_3RD_BUTTON_PRESSED = 0x0008_u32
    FROM_LEFT_4TH_BUTTON_PRESSED = 0x0010_u32
    RIGHTMOST_BUTTON_PRESSED     = 0x0002_u32

    # Mouse event flags
    MOUSE_MOVED    = 0x0001_u32
    DOUBLE_CLICK   = 0x0002_u32
    MOUSE_WHEELED  = 0x0004_u32
    MOUSE_HWHEELED = 0x0008_u32

    # Control key states
    RIGHT_ALT_PRESSED  = 0x0001_u32
    LEFT_ALT_PRESSED   = 0x0002_u32
    RIGHT_CTRL_PRESSED = 0x0004_u32
    LEFT_CTRL_PRESSED  = 0x0008_u32
    SHIFT_PRESSED      = 0x0010_u32
    ENHANCED_KEY       = 0x0100_u32

    # Input record structures
    struct KeyEventRecord
      b_key_down : Int32
      w_repeat_count : UInt16
      w_virtual_key_code : UInt16
      w_virtual_scan_code : UInt16
      u_char : CharUnion
      dw_control_key_state : UInt32
    end

    union CharUnion
      unicode_char : Char
      ascii_char : Char
    end

    struct MouseEventRecord
      dw_mouse_position : Coord
      dw_button_state : UInt32
      dw_control_key_state : UInt32
      dw_event_flags : UInt32
    end

    struct WindowBufferSizeRecord
      dw_size : Coord
    end

    struct MenuEventRecord
      dw_command_id : UInt32
    end

    struct FocusEventRecord
      b_set_focus : Int32
    end

    union InputRecordEvent
      key_event : KeyEventRecord
      mouse_event : MouseEventRecord
      window_buffer_size_event : WindowBufferSizeRecord
      menu_event : MenuEventRecord
      focus_event : FocusEventRecord
    end

    struct InputRecord
      event_type : UInt16
      event : InputRecordEvent
    end

    fun GetConsoleScreenBufferInfo(hConsoleOutput : HANDLE, lpConsoleScreenBufferInfo : ConsoleScreenBufferInfo*) : BOOL
    fun FlushConsoleInputBuffer(hConsoleInput : HANDLE) : BOOL
    fun PeekConsoleInputW(hConsoleInput : HANDLE, lpBuffer : InputRecord*, nLength : DWORD, lpNumberOfEventsRead : DWORD*) : BOOL
    fun ReadConsoleInputW(hConsoleInput : HANDLE, lpBuffer : InputRecord*, nLength : DWORD, lpNumberOfEventsRead : DWORD*) : BOOL
    fun CreateEventW(lpEventAttributes : Void*, bManualReset : BOOL, bInitialState : BOOL, lpName : UInt16*) : HANDLE
    fun SetEvent(hEvent : HANDLE) : BOOL
    fun WaitForMultipleObjects(nCount : DWORD, lpHandles : HANDLE*, bWaitAll : BOOL, dwMilliseconds : DWORD) : DWORD
  end
{% end %}
