require "./spec_helper"

describe Ultraviolet::TerminalScreen do
  it "clears the screen before display draws a drawable" do
    output = IO::Memory.new
    screen = Ultraviolet::TerminalScreen.new(output, ["TERM=xterm-256color"])
    screen.resize(4, 2)
    screen.set_cell(1, 0, Ultraviolet::Cell.new("X", 1))

    drawable = Ultraviolet::DrawableFunc.new do |scr, _area|
      scr.set_cell(0, 0, Ultraviolet::Cell.new("A", 1))
    end

    screen.display(drawable)
    screen.cell_at(0, 0).try(&.string).should eq("A")
    screen.cell_at(1, 0).try(&.string).should eq(" ")
  end

  it "supports inserting content above the current screen" do
    output = IO::Memory.new
    screen = Ultraviolet::TerminalScreen.new(output, ["TERM=xterm-256color"])
    screen.resize(4, 2)
    screen.set_cell(0, 0, Ultraviolet::Cell.new("B", 1))
    screen.render
    screen.flush

    screen.insert_above("Z")
    output.to_s.includes?("Z").should be_true
  end

  it "tracks cursor state and style settings" do
    output = IO::Memory.new
    screen = Ultraviolet::TerminalScreen.new(output, ["TERM=xterm-256color"])

    screen.show_cursor
    screen.cursor_visible?.should be_true

    screen.set_cursor_position(3, 1)
    screen.cursor_position.should eq({3, 1})

    screen.set_cursor_style(Ultraviolet::CursorShape::Underline, false)
    screen.cursor_style.should eq({Ultraviolet::CursorShape::Underline, false})

    color = Ultraviolet::Color.new(1_u8, 2_u8, 3_u8)
    screen.set_cursor_color(color)
    screen.cursor_color.should eq(color)
  end

  it "tracks bracketed paste, mouse mode, title and progress bar" do
    output = IO::Memory.new
    screen = Ultraviolet::TerminalScreen.new(output, ["TERM=xterm-256color"])

    screen.enable_bracketed_paste
    screen.bracketed_paste?.should be_true
    screen.disable_bracketed_paste
    screen.bracketed_paste?.should be_false

    screen.set_mouse_mode(Ultraviolet::MouseMode::Drag)
    screen.mouse_mode.should eq(Ultraviolet::MouseMode::Drag)

    screen.set_window_title("title")
    screen.window_title.should eq("title")

    pb = Ultraviolet::ProgressBar.new(Ultraviolet::ProgressBarState::Warning, 77)
    screen.set_progress_bar(pb)
    screen.progress_bar.should eq(pb)
  end

  it "emits KittyKeyboard(0,1) before alt screen exit in reset" do
    output = IO::Memory.new
    screen = Ultraviolet::TerminalScreen.new(output, ["TERM=xterm-256color"])
    screen.resize(4, 2)

    enh = Ultraviolet::KeyboardEnhancements.new(
      disambiguate_escape_codes: true,
      report_event_types: true,
    )
    screen.set_keyboard_enhancements(enh)
    screen.enter_alt_screen

    output.clear
    screen.reset
    screen.flush
    result = output.to_s
    # KittyKeyboard(0,1) should appear before ResetModeAltScreenSaveCursor
    kitty_idx = result.index("\e[=0;1u")
    alt_exit_idx = result.index("\e[?1049l")
    kitty_idx.not_nil!.should be < alt_exit_idx.not_nil!
  end

  it "restores keyboard enhancements after reset" do
    output = IO::Memory.new
    screen = Ultraviolet::TerminalScreen.new(output, ["TERM=xterm-256color"])
    screen.resize(4, 2)

    enh = Ultraviolet::KeyboardEnhancements.new(
      disambiguate_escape_codes: true,
    )
    screen.set_keyboard_enhancements(enh)
    screen.enter_alt_screen

    screen.reset
    screen.flush
    output.clear

    screen.restore
    screen.flush
    result = output.to_s

    # Restore should re-enter alt screen and re-set keyboard enhancements
    result.should contain("\e[?1049h")
    result.should contain("\e[=1;1u")
  end

  it "restores cursor state after reset" do
    output = IO::Memory.new
    screen = Ultraviolet::TerminalScreen.new(output, ["TERM=xterm-256color"])
    screen.resize(4, 2)

    screen.show_cursor
    screen.set_cursor_position(2, 1)
    screen.set_cursor_style(Ultraviolet::CursorShape::Underline, false)
    color = Ultraviolet::Color.new(80_u8, 80_u8, 80_u8)
    screen.set_cursor_color(color)

    screen.reset
    screen.flush
    output.clear

    screen.restore
    screen.flush
    result = output.to_s

    # Restore should re-show cursor, restore cursor style, and cursor color
    result.should contain("\e[?25h")
    result.should contain("\e[") # cursor style sequence \e[...q
    result.should contain("\e]12")
  end
end
