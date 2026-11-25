require "./spec_helper"

# Expected pens captured from Go ultraviolet (`uv.ReadStyle` at
# charmbracelet/ultraviolet 1948445e, the version vendor/lipgloss pins on
# 2025-12-05) for SGR sequences that mix `;` and `:` separators. Go feeds the
# parser's `ansi.Params` (value + HasMore flag per parameter) straight into
# ReadStyle, and `ansi.ReadStyleColor` then rejects the ambiguous forms, which
# leaves the loop to interpret the remaining parameters as plain attributes.
#
# A string-based reader cannot reproduce this: it loses the HasMore flags and
# the empty parameters, so "38;2::10:20:30" turns into faint instead of black.
describe "Ultraviolet parity: mixed-separator SGR pens" do
  it "matches go's pen for mixed separators" do
    cases = [
      {"\e[38;2::10:20:30m", Ultraviolet::Style.new(fg: Ultraviolet::AnsiColor.basic(0))},
      {"\e[38;2;10:20:30m", Ultraviolet::Style.new(fg: Ultraviolet::AnsiColor.basic(0), attrs: Ultraviolet::Attr::FAINT)},
      {"\e[38:2:10:20:30m", Ultraviolet::Style.new(fg: Ultraviolet::Color.new(10_u8, 20_u8, 30_u8))},
      {"\e[38:2:10:20:30;1m", Ultraviolet::Style.new(fg: Ultraviolet::Color.new(10_u8, 20_u8, 30_u8), attrs: Ultraviolet::Attr::BOLD)},
      {"\e[1;31:4m", Ultraviolet::Style.new(fg: Ultraviolet::AnsiColor.basic(1), attrs: Ultraviolet::Attr::BOLD, underline: Ultraviolet::Underline::Single)},
      {"\e[38;5::196m", Ultraviolet::Style.new},
      {"\e[7m", Ultraviolet::Style.new(attrs: Ultraviolet::Attr::REVERSE)},
      {"\e[m", Ultraviolet::Style.new},
    ]

    cases.each do |(sequence, want)|
      got = parse_pen(sequence)
      got.should eq(want), "#{sequence.inspect}: got #{got.inspect}"
    end
  end

  it "keeps reading the same pen from parser params" do
    params = parse_params("\e[1;31:4m")
    pen = Ultraviolet.read_style(params, Ultraviolet::Style.new)

    pen.fg.should eq(Ultraviolet::AnsiColor.basic(1))
    pen.attrs.should eq(Ultraviolet::Attr::BOLD)
    pen.underline.should eq(Ultraviolet::Underline::Single)
  end
end
