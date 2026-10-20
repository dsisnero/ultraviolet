require "./spec_helper"

describe "Mouse pixel-to-cell conversion" do
  it "matches the upstream conversion cases" do
    cases = [
      {
        "standard 80x24 terminal",
        Ultraviolet::Mouse.new(480, 312, Ultraviolet::MouseButton::Left),
        Ultraviolet::Winsize.new(row: 24, col: 80, xpixel: 560, ypixel: 312),
        Ultraviolet::Mouse.new(68, 24, Ultraviolet::MouseButton::Left),
      },
      {
        "top-left pixel",
        Ultraviolet::Mouse.new(0, 0, Ultraviolet::MouseButton::Left),
        Ultraviolet::Winsize.new(row: 24, col: 80, xpixel: 560, ypixel: 312),
        Ultraviolet::Mouse.new(0, 0, Ultraviolet::MouseButton::Left),
      },
      {
        "bottom-right pixel",
        Ultraviolet::Mouse.new(559, 311, Ultraviolet::MouseButton::Right),
        Ultraviolet::Winsize.new(row: 24, col: 80, xpixel: 560, ypixel: 312),
        Ultraviolet::Mouse.new(79, 23, Ultraviolet::MouseButton::Right),
      },
      {
        "exact cell boundary pixel",
        Ultraviolet::Mouse.new(6, 12, Ultraviolet::MouseButton::Left),
        Ultraviolet::Winsize.new(row: 24, col: 80, xpixel: 480, ypixel: 288),
        Ultraviolet::Mouse.new(1, 1, Ultraviolet::MouseButton::Left),
      },
      {
        "preserves modifiers",
        Ultraviolet::Mouse.new(240, 156, Ultraviolet::MouseButton::Middle, Ultraviolet::ModAlt),
        Ultraviolet::Winsize.new(row: 24, col: 80, xpixel: 560, ypixel: 312),
        Ultraviolet::Mouse.new(34, 12, Ultraviolet::MouseButton::Middle, Ultraviolet::ModAlt),
      },
      {
        "zero pixel dimensions returns zero cell",
        Ultraviolet::Mouse.new(480, 312, Ultraviolet::MouseButton::Left),
        Ultraviolet::Winsize.new(row: 24, col: 80, xpixel: 0, ypixel: 0),
        Ultraviolet::Mouse.new(0, 0, Ultraviolet::MouseButton::Left),
      },
      {
        "pixel position larger than window",
        Ultraviolet::Mouse.new(1200, 800, Ultraviolet::MouseButton::Left),
        Ultraviolet::Winsize.new(row: 24, col: 80, xpixel: 560, ypixel: 312),
        Ultraviolet::Mouse.new(171, 61, Ultraviolet::MouseButton::Left),
      },
    ]

    cases.each do |name, mouse, winsize, expected|
      Ultraviolet.mouse_pixel_to_cell(mouse, winsize).should eq(expected), name
    end
  end
end
