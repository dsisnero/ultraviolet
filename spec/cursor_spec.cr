require "./spec_helper"

describe Ultraviolet::CursorShape do
  it "encodes cursor shapes with blink state" do
    cases = [
      {shape: Ultraviolet::CursorShape::Block, blink: true, want: 1},
      {shape: Ultraviolet::CursorShape::Block, blink: false, want: 2},
      {shape: Ultraviolet::CursorShape::Underline, blink: true, want: 3},
      {shape: Ultraviolet::CursorShape::Underline, blink: false, want: 4},
      {shape: Ultraviolet::CursorShape::Bar, blink: true, want: 5},
      {shape: Ultraviolet::CursorShape::Bar, blink: false, want: 6},
    ]

    cases.each do |test_case|
      test_case[:shape].encode(test_case[:blink]).should eq(test_case[:want])
    end
  end
end
