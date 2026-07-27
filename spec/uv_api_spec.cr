require "./spec_helper"

describe "UvApi helpers" do
  it "builds keyboard enhancements from flags" do
    ke = Ultraviolet.new_keyboard_enhancements(
      Ansi::KittyDisambiguateEscapeCodes | Ansi::KittyReportEventTypes
    )
    ke.disambiguate_escape_codes?.should be_true
    ke.report_event_types?.should be_true
    ke.flags.should eq(Ansi::KittyDisambiguateEscapeCodes | Ansi::KittyReportEventTypes)
  end

  it "encodes mouse mode sequences" do
    io = IO::Memory.new
    Ultraviolet.encode_mouse_mode(io, Ultraviolet::MouseMode::None)
    io.to_s.should eq(Ansi::ResetModeMouseX10 + Ansi::ResetModeMouseNormal + Ansi::ResetModeMouseButtonEvent + Ansi::ResetModeMouseAnyEvent)

    io = IO::Memory.new
    Ultraviolet.encode_mouse_mode(io, Ultraviolet::MouseMode::Press)
    io.to_s.should eq(Ansi::SetModeMouseX10)

    io = IO::Memory.new
    Ultraviolet.encode_mouse_mode(io, Ultraviolet::MouseMode::Click)
    io.to_s.should eq(Ansi::SetModeMouseNormal)

    io = IO::Memory.new
    Ultraviolet.encode_mouse_mode(io, Ultraviolet::MouseMode::Drag)
    io.to_s.should eq(Ansi::SetModeMouseButtonEvent)

    io = IO::Memory.new
    Ultraviolet.encode_mouse_mode(io, Ultraviolet::MouseMode::Motion)
    io.to_s.should eq(Ansi::SetModeMouseAnyEvent)
  end

  it "encodes progress bar reset for nil value" do
    io = IO::Memory.new
    Ultraviolet.encode_progress_bar(io, nil)
    io.to_s.should eq(Ansi::ResetProgressBar)
  end

  it "encodes mouse encoding" do
    io = IO::Memory.new
    Ultraviolet.encode_mouse_encoding(io, Ultraviolet::MouseEncoding::SGR)
    io.to_s.should eq(Ansi::SetModeMouseExtSgr)

    io = IO::Memory.new
    Ultraviolet.encode_mouse_encoding(io, Ultraviolet::MouseEncoding::SGRPixel)
    io.to_s.should eq(Ansi::SetModeMouseExtSgrPixel)

    io = IO::Memory.new
    Ultraviolet.encode_mouse_encoding(io, Ultraviolet::MouseEncoding::Legacy)
    out = io.to_s
    out.includes?(Ansi::ResetModeMouseExtSgr).should be_true
    out.includes?(Ansi::ResetModeMouseExtUrxvt).should be_true
    out.includes?(Ansi::ResetModeMouseExtSgrPixel).should be_true
  end

  it "encodes window title" do
    io = IO::Memory.new
    Ultraviolet.encode_window_title(io, "hello")
    io.to_s.should eq(Ansi.set_window_title("hello"))
  end
end
