require "./spec_helper"

describe "Go-compatible constructor aliases" do
  it "exposes constructor names used by the Go API" do
    Ultraviolet.new_styled_string("hello").text.should eq("hello")
    Ultraviolet.new_line(4).width.should eq(4)
    Ultraviolet.new_buffer(4, 2).width.should eq(4)
    Ultraviolet.new_tab_stops(80, 8).width.should eq(80)
    Ultraviolet.default_tab_stops(80).width.should eq(80)
    Ultraviolet.new_terminal_reader(IO::Memory.new, "xterm-256color").should be_a(Ultraviolet::TerminalReader)
    Ultraviolet.new_terminal_renderer(IO::Memory.new).should be_a(Ultraviolet::TerminalRenderer)
    Ultraviolet.new_terminal_screen(IO::Memory.new).should be_a(Ultraviolet::TerminalScreen)
    Ultraviolet.new_console(IO::Memory.new, IO::Memory.new, [] of String).should be_a(Ultraviolet::Console)
  end

  it "exposes style_diff" do
    red = Ultraviolet::Style.new(fg: Ultraviolet::AnsiColor.basic(1))
    Ultraviolet.style_diff(Ultraviolet::Style.new, red).should eq(
      Ultraviolet::Style.diff(Ultraviolet::Style.new, red)
    )
  end
end
