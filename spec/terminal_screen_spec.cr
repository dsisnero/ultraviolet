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
end
