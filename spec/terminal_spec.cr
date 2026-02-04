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
end
