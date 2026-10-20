require "./spec_helper"

module WidthSpecHelper
  def self.wc_width : Ultraviolet::WidthMethod
    ->(value : String) { Ansi.string_width_wc(value) }
  end

  def self.grapheme_width : Ultraviolet::WidthMethod
    ->(value : String) { Ansi.string_width(value) }
  end
end

describe "ultraviolet width handling" do
  it "draws cells that cover every column under wcwidth" do
    cases = [
      {"ascii", "abc", [1, 1, 1]},
      {"combining acute", "éx", [1, 1]},
      {"cjk", "世界", [2, 2]},
      {"vs16", "⚠️", [1]},
      {"zwj pair", "👨‍💻", [4]},
      {"zwj flag", "🏳️‍🌈", [3]},
      {"skin tone", "👍🏽", [4]},
      {"zwj family", "👨‍👩‍👧‍👦", [8]},
    ]

    cases.each do |name, value, widths|
      buffer = Ultraviolet::ScreenBuffer.new(20, 1, WidthSpecHelper.wc_width)
      Ultraviolet::StyledString.new(value).draw(buffer, buffer.bounds)

      x = 0
      widths.each_with_index do |want, index|
        cell = buffer.cell_at(x, 0)
        cell.should_not be_nil, "#{name} cell #{index}"
        cell.not_nil!.width.should eq(want), "#{name} cell #{index}"

        (1...cell.not_nil!.width).each do |offset|
          placeholder = buffer.cell_at(x + offset, 0)
          placeholder.should_not be_nil, "#{name} placeholder #{x + offset}"
          placeholder.not_nil!.zero?.should be_true, "#{name} placeholder #{x + offset}"
        end

        x += Math.max(cell.not_nil!.width, 1)
      end

      Ansi.string_width_wc(value).should eq(x), name
    end
  end

  it "draws cells under grapheme width" do
    cases = [
      {"devanagari", "नमस्ते", 1},
      {"vs16", "⚠️", 2},
      {"zwj family", "👨‍👩‍👧‍👦", 2},
      {"skin tone", "👍🏽", 2},
    ]

    cases.each do |name, value, want|
      buffer = Ultraviolet::ScreenBuffer.new(20, 1, WidthSpecHelper.grapheme_width)
      Ultraviolet::StyledString.new(value).draw(buffer, buffer.bounds)

      cell = buffer.cell_at(0, 0)
      cell.should_not be_nil, name
      cell.not_nil!.width.should eq(want), name
    end
  end

  it "builds cells that agree with the width model" do
    cases = [
      {"a", 1},
      {" ", 1},
      {"स्ते", 2},
      {"👨‍💻", 4},
      {"👨‍👩‍👧‍👦", 8},
    ]

    cases.each do |value, want|
      Ultraviolet::Cell.new_cell(WidthSpecHelper.wc_width, value).width.should eq(want), value
    end
  end
end
