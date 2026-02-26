module Ultraviolet
  struct KeyboardEnhancements
    property? disambiguate_escape_codes : Bool
    property? report_event_types : Bool

    def initialize(
      @disambiguate_escape_codes : Bool = false,
      @report_event_types : Bool = false,
    )
    end

    def flags : Int32
      flags = 0
      flags |= Ansi::KittyDisambiguateEscapeCodes if @disambiguate_escape_codes
      flags |= Ansi::KittyReportEventTypes if @report_event_types
      flags
    end
  end

  def self.new_keyboard_enhancements(flags : Int32) : KeyboardEnhancements
    return KeyboardEnhancements.new if flags <= 0
    KeyboardEnhancements.new(
      disambiguate_escape_codes: (flags & Ansi::KittyDisambiguateEscapeCodes) != 0,
      report_event_types: (flags & Ansi::KittyReportEventTypes) != 0,
    )
  end

  def self.encode_background_color(io : IO, color : Color?) : Nil
    seq = color ? Ansi.set_background_color(color_to_hex(color)) : Ansi::ResetBackgroundColor
    io << seq
  end

  def self.encode_foreground_color(io : IO, color : Color?) : Nil
    seq = color ? Ansi.set_foreground_color(color_to_hex(color)) : Ansi::ResetForegroundColor
    io << seq
  end

  def self.encode_cursor_color(io : IO, color : Color?) : Nil
    seq = color ? Ansi.set_cursor_color(color_to_hex(color)) : Ansi::ResetCursorColor
    io << seq
  end

  def self.encode_cursor_style(io : IO, shape : CursorShape, blink : Bool) : Nil
    io << Ansi.set_cursor_style(shape.encode(blink))
  end

  def self.encode_bracketed_paste(io : IO, enable : Bool) : Nil
    io << (enable ? Ansi::SetModeBracketedPaste : Ansi::ResetModeBracketedPaste)
  end

  def self.encode_mouse_mode(io : IO, mode : MouseMode) : Nil
    case mode
    when MouseMode::None
      io << Ansi::ResetModeMouseNormal
      io << Ansi::ResetModeMouseButtonEvent
      io << Ansi::ResetModeMouseAnyEvent
      io << Ansi::ResetModeMouseExtSgr
    when MouseMode::Click
      io << Ansi::SetModeMouseNormal
      io << Ansi::SetModeMouseExtSgr
    when MouseMode::Drag
      io << Ansi::SetModeMouseButtonEvent
      io << Ansi::SetModeMouseExtSgr
    when MouseMode::Motion
      io << Ansi::SetModeMouseAnyEvent
      io << Ansi::SetModeMouseExtSgr
    else
      raise ArgumentError.new("invalid mouse mode: #{mode}")
    end
  end

  def self.encode_progress_bar(io : IO, pb : ProgressBar?) : Nil
    if pb.nil?
      io << Ansi::ResetProgressBar
      return
    end

    value = pb.value.clamp(0, 100)
    case pb.state
    when ProgressBarState::None
      io << Ansi::ResetProgressBar
    when ProgressBarState::Default
      io << Ansi.set_progress_bar(value)
    when ProgressBarState::Error
      io << Ansi.set_error_progress_bar(value)
    when ProgressBarState::Indeterminate
      io << Ansi::SetIndeterminateProgressBar
    when ProgressBarState::Warning
      io << Ansi.set_warning_progress_bar(value)
    end
  end

  def self.encode_keyboard_enhancements(io : IO, enhancements : KeyboardEnhancements?) : Nil
    flags = enhancements ? enhancements.flags : 0
    io << Ansi.kitty_keyboard(flags, 1)
  end

  def self.encode_window_title(io : IO, title : String) : Nil
    io << Ansi.set_window_title(title)
  end
end
