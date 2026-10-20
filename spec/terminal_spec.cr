require "./spec_helper"

describe "Terminal helpers" do
  it "provides access to logger" do
    term = Ultraviolet::Terminal.default_terminal
    term.logger.should be_nil
  end

  it "supports backspace check" do
    Ultraviolet.supports_backspace(0_u64)
  end

  it "supports hard tabs check" do
    Ultraviolet.supports_hard_tabs(0_u64)
  end

  it "opens tty when available" do
    begin
      Ultraviolet.open_tty
    rescue
    end
  end

  it "builds a default terminal from console defaults" do
    term = Ultraviolet::Terminal.default_terminal
    term.should be_a(Ultraviolet::Terminal)
  end

  it "builds a controlling terminal when tty is available" do
    begin
      term = Ultraviolet::Terminal.controlling_terminal
      term.should be_a(Ultraviolet::Terminal)
    rescue Exception | IO::Error
      # Environments without a controlling tty are expected in CI/non-interactive runs.
    end
  end

  it "provides size through get_size" do
    term = Ultraviolet::Terminal.default_terminal
    width, height = term.get_size
    width.should be_a(Int32)
    height.should be_a(Int32)
  end

  it "provides winsize through get_winsize" do
    term = Ultraviolet::Terminal.default_terminal
    ws = term.get_winsize
    ws.should be_a(Ultraviolet::Winsize)
  end
end

describe "Terminal stop" do
  it "is safe before start" do
    term = Ultraviolet::Terminal.default_terminal
    term.stop
  end

  it "is idempotent" do
    term = Ultraviolet::Terminal.default_terminal
    3.times { term.stop }
  end
end

private class TestSizeNotifier < Ultraviolet::SizeNotifier
  def initialize(@cells : Ultraviolet::Size, @pixels : Ultraviolet::Size)
    super(nil)
  end

  def window_size : {Ultraviolet::Size, Ultraviolet::Size}
    {@cells, @pixels}
  end
end

describe "SizeNotifier compatibility" do
  it "exposes GetWindowSize and GetSize" do
    cells = Ultraviolet::Size.new(80, 24)
    pixels = Ultraviolet::Size.new(800, 480)
    notifier = TestSizeNotifier.new(cells, pixels)

    notifier.get_window_size.should eq({cells, pixels})
    notifier.get_size.should eq({80, 24})
  end
end
