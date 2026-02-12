{% if flag?(:win32) %}
  require "c/consoleapi"
  require "../cancelreader"

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
    STD_INPUT_HANDLE              =    -10_i32
    ENABLE_VIRTUAL_TERMINAL_INPUT = 0x0200_u32
    ENABLE_WINDOW_INPUT           = 0x0008_u32
    ENABLE_EXTENDED_FLAGS         = 0x0080_u32

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

    fun GetStdHandle(nStdHandle : DWORD) : HANDLE
    fun GetConsoleMode(hConsoleHandle : HANDLE, lpMode : DWORD*) : BOOL
    fun SetConsoleMode(hConsoleHandle : HANDLE, dwMode : DWORD) : BOOL
    fun ReadFile(hFile : HANDLE, lpBuffer : Void*, nNumberOfBytesToRead : DWORD, lpNumberOfBytesRead : DWORD*, lpOverlapped : Void*) : BOOL
    fun CancelIo(hFile : HANDLE) : BOOL
    fun CancelIoEx(hFile : HANDLE, lpOverlapped : Void*) : BOOL
    fun CloseHandle(hObject : HANDLE) : BOOL
    fun FlushConsoleInputBuffer(hConsoleInput : HANDLE) : BOOL
    fun PeekConsoleInputW(hConsoleInput : HANDLE, lpBuffer : InputRecord*, nLength : DWORD, lpNumberOfEventsRead : DWORD*) : BOOL
    fun ReadConsoleInputW(hConsoleInput : HANDLE, lpBuffer : InputRecord*, nLength : DWORD, lpNumberOfEventsRead : DWORD*) : BOOL
  end

  module Ultraviolet
    class TerminalReader
      # Windows-specific send_bytes implementation
      private def send_bytes(readc : Channel(Bytes), stop : Channel(Nil)?) : Nil
        # Check if reader is a Windows console handle
        if @reader.is_a?(IO::FileDescriptor) && console_handle?(@reader)
          # Use Windows Console API
          send_bytes_windows(readc, stop)
        else
          # Fall back to default implementation
          super
        end
      end

      private def send_bytes_windows(readc : Channel(Bytes), stop : Channel(Nil)?) : Nil
        # Check if reader is a ConInputReader
        conin = if @reader.is_a?(ConInputReader)
                  @reader.as(ConInputReader)
                else
                  # Fall back to generic console handle
                  nil
                end

        handle = conin ? conin.@conin : console_handle(@reader.as(IO::FileDescriptor))

        # Store VT Input Mode state
        mode = uninitialized LibC::DWORD
        if LibC.GetConsoleMode(handle, pointerof(mode)) != 0
          @vt_input = (mode & LibC::ENABLE_VIRTUAL_TERMINAL_INPUT) != 0
        end

        loop do
          break if stop && stop.closed?

          # Check for cancellation if using ConInputReader
          if conin && conin.canceled?
            break
          end

          # Peek at available console inputs
          records = peek_n_console_inputs(handle, 4096)
          if records.empty?
            # Sleep a bit to avoid busy waiting
            sleep 10.milliseconds
            next
          end

          # Check for cancellation again
          if conin && conin.canceled?
            break
          end

          # Read the console inputs
          records = read_n_console_inputs(handle, records.size)

          # Check for cancellation after reading
          if conin && conin.canceled?
            break
          end

          # Serialize Windows input records to VT sequences
          serialized = serialize_win32_input_records(records)

          # Send the buffer
          if serialized.size > 0
            readc.send(serialized)
          end
        end
      end

      private def peek_n_console_inputs(handle : LibC::HANDLE, max_events : Int32) : Array(LibC::InputRecord)
        return [] of LibC::InputRecord if max_events == 0

        records = Array(LibC::InputRecord).new(max_events)
        max_events.times { records << uninitialized LibC::InputRecord }

        events_read = uninitialized LibC::DWORD
        if LibC.PeekConsoleInputW(handle, records.to_unsafe, max_events.to_u32, pointerof(events_read)) == 0
          # Peek failed, return empty
          return [] of LibC::InputRecord
        end

        records[0, events_read]
      end

      private def read_n_console_inputs(handle : LibC::HANDLE, num_events : Int32) : Array(LibC::InputRecord)
        return [] of LibC::InputRecord if num_events == 0

        records = Array(LibC::InputRecord).new(num_events)
        num_events.times { records << uninitialized LibC::InputRecord }

        events_read = uninitialized LibC::DWORD
        if LibC.ReadConsoleInputW(handle, records.to_unsafe, num_events.to_u32, pointerof(events_read)) == 0
          # Read failed, return empty
          return [] of LibC::InputRecord
        end

        records[0, events_read]
      end

      private def mouse_event_button(prev_state : UInt32, current_state : UInt32) : {Ansi::MouseButton, Bool}
        is_release = false
        button = Ansi::MouseNone
        btn = prev_state ^ current_state

        if btn & current_state == 0
          is_release = true
        end

        if btn == 0
          case
          when current_state & LibC::FROM_LEFT_1ST_BUTTON_PRESSED > 0
            button = Ansi::MouseLeft
          when current_state & LibC::FROM_LEFT_2ND_BUTTON_PRESSED > 0
            button = Ansi::MouseMiddle
          when current_state & LibC::RIGHTMOST_BUTTON_PRESSED > 0
            button = Ansi::MouseRight
          when current_state & LibC::FROM_LEFT_3RD_BUTTON_PRESSED > 0
            button = Ansi::MouseBackward
          when current_state & LibC::FROM_LEFT_4TH_BUTTON_PRESSED > 0
            button = Ansi::MouseForward
          end
          return {button, is_release}
        end

        case btn
        when LibC::FROM_LEFT_1ST_BUTTON_PRESSED
          button = Ansi::MouseLeft
        when LibC::RIGHTMOST_BUTTON_PRESSED
          button = Ansi::MouseRight
        when LibC::FROM_LEFT_2ND_BUTTON_PRESSED
          button = Ansi::MouseMiddle
        when LibC::FROM_LEFT_3RD_BUTTON_PRESSED
          button = Ansi::MouseBackward
        when LibC::FROM_LEFT_4TH_BUTTON_PRESSED
          button = Ansi::MouseForward
        end

        {button, is_release}
      end

      private def high_word(data : UInt32) : UInt16
        ((data & 0xFFFF0000) >> 16).to_u16
      end

      private def serialize_win32_input_records(records : Array(LibC::InputRecord)) : Bytes
        io = IO::Memory.new

        records.each do |record|
          case record.event_type
          when LibC::KEY_EVENT
            key_event = record.event.key_event
            kd = key_event.b_key_down != 0 ? 1 : 0

            if @vt_input
              # In VT Input Mode, we only capture the Unicode characters
              # decoding them along the way.
              if @utf16_half[kd]
                # We have a half pair that needs to be decoded.
                @utf16_half[kd] = false
                @utf16_buf[kd][1] = key_event.u_char.unicode_char.ord
                # Decode UTF-16 surrogate pair
                high = @utf16_buf[kd][0]
                low = @utf16_buf[kd][1]
                # Simple UTF-16 decoding: (high - 0xD800) * 0x400 + (low - 0xDC00) + 0x10000
                if high >= 0xD800 && high <= 0xDBFF && low >= 0xDC00 && low <= 0xDFFF
                  codepoint = ((high - 0xD800) << 10) + (low - 0xDC00) + 0x10000
                  io.write_utf8(codepoint.chr)
                end
              elsif key_event.u_char.unicode_char.ord >= 0xD800 && key_event.u_char.unicode_char.ord <= 0xDBFF
                # This is the first half of a UTF-16 surrogate pair.
                @utf16_half[kd] = true
                @utf16_buf[kd][0] = key_event.u_char.unicode_char.ord
              elsif key_event.b_key_down != 0
                # Just a regular key press character encoded in VT.
                io << key_event.u_char.unicode_char
              end
            else
              # We encode the key to Win32 Input Mode if it is a known key.
              if key_event.w_virtual_key_code == 0
                store_grapheme_rune(kd, key_event.u_char.unicode_char.ord)
              else
                io.write(encode_grapheme_bufs)
                io << "\e["
                io << key_event.w_virtual_key_code
                io << ';'
                io << key_event.w_virtual_scan_code
                io << ';'
                io << key_event.u_char.unicode_char.ord
                io << ';'
                io << kd
                io << ';'
                io << key_event.dw_control_key_state
                io << ';'
                io << key_event.w_repeat_count
                io << '_'
              end
            end
          when LibC::MOUSE_EVENT
            mouse_mode = @mouse_mode
            next unless mouse_mode && mouse_mode.value != 0

            mouse_event = record.event.mouse_event
            button_state = mouse_event.dw_button_state
            control_key_state = mouse_event.dw_control_key_state
            event_flags = mouse_event.dw_event_flags

            is_release = false
            is_motion = false
            button = Ansi::MouseNone

            alt = (control_key_state & (LibC::LEFT_ALT_PRESSED | LibC::RIGHT_ALT_PRESSED)) != 0
            ctrl = (control_key_state & (LibC::LEFT_CTRL_PRESSED | LibC::RIGHT_CTRL_PRESSED)) != 0
            shift = (control_key_state & LibC::SHIFT_PRESSED) != 0

            wheel_direction = high_word(button_state).to_i16

            case event_flags
            when 0, LibC::DOUBLE_CLICK
              button, is_release = mouse_event_button(@last_mouse_btns, button_state)
            when LibC::MOUSE_WHEELED
              if wheel_direction > 0
                button = Ansi::MouseWheelUp
              else
                button = Ansi::MouseWheelDown
              end
            when LibC::MOUSE_HWHEELED
              if wheel_direction > 0
                button = Ansi::MouseWheelRight
              else
                button = Ansi::MouseWheelLeft
              end
            when LibC::MOUSE_MOVED
              button, _ = mouse_event_button(@last_mouse_btns, button_state)
              is_motion = true
            end

            # We emulate mouse mode levels on Windows.
            if button == Ansi::MouseNone && !mouse_mode.try(&.motion?) ||
               (button != Ansi::MouseNone && !mouse_mode.try(&.drag?))
              next
            end

            # Encode mouse events as SGR mouse sequences
            encoded_button = Ansi.encode_mouse_button(button, is_motion, shift, alt, ctrl)
            x = mouse_event.dw_mouse_position.x.to_i32
            y = mouse_event.dw_mouse_position.y.to_i32
            io << Ansi.mouse_sgr(encoded_button, x, y, is_release)

            @last_mouse_btns = button_state
          when LibC::WINDOW_BUFFER_SIZE_EVENT
            window_event = record.event.window_buffer_size_event
            if window_event.dw_size.x != @last_winsize_x || window_event.dw_size.y != @last_winsize_y
              @last_winsize_x = window_event.dw_size.x
              @last_winsize_y = window_event.dw_size.y
              # Encode window resize events as CSI 4 ; height ; width t
              io << "\e[4;"
              io << window_event.dw_size.y
              io << ';'
              io << window_event.dw_size.x
              io << 't'
            end
          when LibC::FOCUS_EVENT
            focus_event = record.event.focus_event
            if focus_event.b_set_focus != 0
              io << "\e[I" # Focus in
            else
              io << "\e[O" # Focus out
            end
          when LibC::MENU_EVENT
            # ignore
          end
        end

        # Flush any remaining grapheme buffers.
        io.write(encode_grapheme_bufs)

        io.to_slice
      end

      private def console_handle?(tty : IO::FileDescriptor) : Bool
        handle = LibC::HANDLE.new(tty.fd)
        mode = uninitialized LibC::DWORD
        LibC.GetConsoleMode(handle, pointerof(mode)) != 0
      end

      private def console_handle(tty : IO::FileDescriptor) : LibC::HANDLE
        LibC::HANDLE.new(tty.fd)
      end
    end
  end
{% end %}
