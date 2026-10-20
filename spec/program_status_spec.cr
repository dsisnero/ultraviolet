require "./spec_helper"

describe "Program Status Protocol (OSC 7501)" do
  it "encodes program statuses" do
    tests = [
      {"minimal", Ansi::ProgramStatus.new(state: Ansi::ProgramStateWorking), "\e]7501;state=working\a"},
      {
        "spec example",
        Ansi::ProgramStatus.new(
          state: Ansi::ProgramStateBlocked,
          kind: Ansi::ProgramStatusKindPermission,
          app: "terraform",
          message: "Apply 3 to add, 1 to change, 0 to destroy?",
        ),
        "\e]7501;state=blocked:kind=permission:app=terraform:msg=QXBwbHkgMyB0byBhZGQsIDEgdG8gY2hhbmdlLCAwIHRvIGRlc3Ryb3k/\a",
      },
      {
        "all keys",
        Ansi::ProgramStatus.new(
          state: Ansi::ProgramStateWorking,
          id: "us-east",
          title: "US East",
          progress: 40,
          has_progress: true,
          message: "Pushing image",
        ),
        "\e]7501;state=working:id=us-east:progress=40:title=VVMgRWFzdA==:msg=UHVzaGluZyBpbWFnZQ==\a",
      },
      {"progress clamped", Ansi::ProgramStatus.new(state: Ansi::ProgramStateBlocked, progress: 300, has_progress: true), "\e]7501;state=blocked:progress=100\a"},
      {"zero progress", Ansi::ProgramStatus.new(state: Ansi::ProgramStateWorking, has_progress: true), "\e]7501;state=working:progress=0\a"},
      {"progress ignored for done", Ansi::ProgramStatus.new(state: Ansi::ProgramStateDone, progress: 50, has_progress: true), "\e]7501;state=done\a"},
      {"kind ignored for working", Ansi::ProgramStatus.new(state: Ansi::ProgramStateWorking, kind: Ansi::ProgramStatusKindAuth), "\e]7501;state=working\a"},
      {"unknown kind omitted", Ansi::ProgramStatus.new(state: Ansi::ProgramStateBlocked, kind: "nope"), "\e]7501;state=blocked\a"},
      {"invalid app omitted", Ansi::ProgramStatus.new(state: Ansi::ProgramStateIdle, app: "my app"), "\e]7501;state=idle\a"},
      {"control chars stripped", Ansi::ProgramStatus.new(state: Ansi::ProgramStateError, message: "  a\n\tb\e]2;x\a \u009bc  "), "\e]7501;state=error:msg=#{Base64.strict_encode("a b ]2;x   c")}\a"},
      {"only control chars", Ansi::ProgramStatus.new(state: Ansi::ProgramStateError, message: "\n\n"), "\e]7501;state=error\a"},
      {"clear ignores fields", Ansi::ProgramStatus.new(state: Ansi::ProgramStateClear, app: "x", message: "y"), Ansi::ClearProgramStatus},
      {"unknown state", Ansi::ProgramStatus.new(state: "busy"), ""},
      {"invalid id char", Ansi::ProgramStatus.new(state: Ansi::ProgramStateIdle, id: "a b"), ""},
      {"invalid id empty segment", Ansi::ProgramStatus.new(state: Ansi::ProgramStateIdle, id: "a//b"), ""},
      {"invalid id depth", Ansi::ProgramStatus.new(state: Ansi::ProgramStateIdle, id: "a/b/c/d/e/f/g/h/i"), ""},
      {"invalid id segment length", Ansi::ProgramStatus.new(state: Ansi::ProgramStateIdle, id: "a" * 33), ""},
      {"nested id", Ansi::ProgramStatus.new(state: Ansi::ProgramStateIdle, id: "build/test"), "\e]7501;state=idle:id=build/test\a"},
    ]

    tests.each do |name, status, expected|
      Ansi.set_program_status(status).should eq(expected), name
    end
  end

  it "truncates program status text without splitting a rune" do
    message = "x" + ("é" * 1100)
    seq = Ansi.set_program_status(Ansi::ProgramStatus.new(state: Ansi::ProgramStateDone, message: message))
    encoded = seq.lchop("\e]7501;state=done:msg=").rchop("\a")
    Base64.decode(encoded).size.should eq(2047)
    seq.bytesize.should be <= 4096
  end

  it "supports clearing by id" do
    Ansi.clear_program_status_id("").should eq(Ansi::ClearProgramStatus)
    Ansi.clear_program_status_id("eu-west").should eq("\e]7501;state=clear:id=eu-west\a")
    Ansi.clear_program_status_id("bad id").should eq("")
    Ansi::RequestProgramStatusSupport.should eq("\e]7501;?\a")
  end

  it "exposes the ultraviolet aliases" do
    Ultraviolet::ProgramStatus.should eq(Ansi::ProgramStatus)
    Ultraviolet::ProgramState.should eq(Ansi::ProgramState)
    Ultraviolet::ProgramStatusKind.should eq(Ansi::ProgramStatusKind)
    Ultraviolet::ProgramStateIdle.should eq("idle")
    Ultraviolet::ProgramStateWorking.should eq("working")
    Ultraviolet::ProgramStateDone.should eq("done")
    Ultraviolet::ProgramStateBlocked.should eq("blocked")
    Ultraviolet::ProgramStateError.should eq("error")
    Ultraviolet::ProgramStateClear.should eq("clear")
    Ultraviolet::ProgramStatusKindPermission.should eq("permission")
    Ultraviolet::ProgramStatusKindQuestion.should eq("question")
    Ultraviolet::ProgramStatusKindAuth.should eq("auth")
  end

  it "encodes ultraviolet program statuses, including clearing" do
    io = IO::Memory.new
    Ultraviolet.encode_program_status(io, Ultraviolet::ProgramStatus.new(state: Ultraviolet::ProgramStateWorking))
    io.to_s.should eq("\e]7501;state=working\a")

    io = IO::Memory.new
    Ultraviolet.encode_program_status(io, nil)
    io.to_s.should eq(Ansi::ClearProgramStatus)
  end

  it "decodes support replies" do
    decoder = Ultraviolet::EventDecoder.new
    consumed, event = decoder.decode("\e]7501;?\a".to_slice)
    consumed.should eq(9)
    event.should be_a(Ultraviolet::ProgramStatusSupportEvent)
  end

  it "leaves other OSC 7501 reports as unknown OSC events" do
    decoder = Ultraviolet::EventDecoder.new
    sequence = "\e]7501;state=working\a"
    consumed, event = decoder.decode(sequence.to_slice)
    consumed.should eq(sequence.bytesize)
    event.should be_a(Ultraviolet::UnknownOscEvent)
    event.as(Ultraviolet::UnknownOscEvent).value.should eq(sequence)
  end

  it "tracks and emits the program status on the terminal screen" do
    output = IO::Memory.new
    screen = Ultraviolet::TerminalScreen.new(output, ["TERM=xterm-256color"])
    screen.program_status.should be_nil

    status = Ultraviolet::ProgramStatus.new(state: Ultraviolet::ProgramStateWorking, message: "Pushing image")
    screen.set_program_status(status)
    screen.program_status.should eq(status)

    screen.flush
    output.to_s.should contain(Ansi.set_program_status(status))

    output.clear
    screen.set_program_status(nil)
    screen.program_status.should be_nil
    screen.flush
    output.to_s.should contain(Ansi::ClearProgramStatus)
  end
end
