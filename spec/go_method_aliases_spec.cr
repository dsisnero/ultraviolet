require "./spec_helper"

describe "Go-compatible method aliases" do
  it "exposes event and tab-stop predicates" do
    red = Ultraviolet::Color.new(255_u8, 0_u8, 0_u8)
    event = Ultraviolet::ForegroundColorEvent.new(red)
    event.is_dark.should eq(event.dark?)

    stops = Ultraviolet::TabStops.default(80)
    stops.is_stop(0).should be_true
    stops.is_stop(1).should be_false
  end

  it "exposes renderer and reader setters" do
    renderer = Ultraviolet::TerminalRenderer.new(IO::Memory.new, ["TERM=xterm-256color"])
    renderer.set_logger(nil)
    renderer.set_scroll_optim(true)
    renderer.flags.includes?(Ultraviolet::TerminalFlags::ScrollOptim).should be_true
    renderer.set_map_newline(true)
    renderer.flags.includes?(Ultraviolet::TerminalFlags::MapNewline).should be_true
    renderer.set_backspace(true)
    renderer.caps.includes?(Ultraviolet::Capabilities::BS).should be_true
    renderer.set_fullscreen(true)
    renderer.fullscreen?.should be_true
    renderer.set_relative_cursor(true)
    renderer.flags.includes?(Ultraviolet::TerminalFlags::RelativeCursor).should be_true
    renderer.set_tab_stops(8)

    reader = Ultraviolet::TerminalReader.new(IO::Memory.new, "xterm-256color")
    reader.set_logger(nil)
  end
end
