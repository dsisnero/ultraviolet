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
    Ultraviolet.encode_mouse_mode(io, Ultraviolet::MouseMode::Click)
    out = io.to_s
    out.includes?(Ansi::SetModeMouseNormal).should be_true
    out.includes?(Ansi::SetModeMouseExtSgr).should be_true
  end

  it "encodes progress bar reset for nil value" do
    io = IO::Memory.new
    Ultraviolet.encode_progress_bar(io, nil)
    io.to_s.should eq(Ansi::ResetProgressBar)
  end

  it "encodes window title" do
    io = IO::Memory.new
    Ultraviolet.encode_window_title(io, "hello")
    io.to_s.should eq(Ansi.set_window_title("hello"))
  end
end
