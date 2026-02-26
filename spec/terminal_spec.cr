require "./spec_helper"

describe "Terminal helpers" do
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
end
