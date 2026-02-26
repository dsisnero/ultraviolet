require "uniwidth"
require "./spec_helper"

module StyledSpecHelper
  def self.new_wc_cell(value : String, style : Ultraviolet::Style?, link : Ultraviolet::Link?) : Ultraviolet::Cell
    cell = Ultraviolet::Cell.new(value, UnicodeCharWidth.width(value))
    cell.style = style if style
    cell.link = link if link
    cell
  end

  def self.build_buffer(lines : Array(Array(Ultraviolet::Cell))) : Ultraviolet::Buffer
    height = lines.size
    width = lines.max_of?(&.size) || 0
    buffer = Ultraviolet::Buffer.new(width, height)
    lines.each_with_index do |line_cells, y|
      line = buffer.lines[y]
      line_cells.each_with_index do |cell, x|
        line.cells[x] = cell
      end
    end
    buffer
  end
end

describe "StyledString" do
  it "renders styled strings into buffers" do
    red = Ultraviolet::AnsiColor.basic(1)
    green = Ultraviolet::AnsiColor.basic(2)
    yellow = Ultraviolet::AnsiColor.basic(3)
    blue = Ultraviolet::AnsiColor.basic(4)
    magenta = Ultraviolet::AnsiColor.basic(5)

    cases = [
      {
        name:            "single line",
        input:           "Hello, World!",
        expected_width:  13,
        expected_height: 1,
        expected:        StyledSpecHelper.build_buffer([
          [
            StyledSpecHelper.new_wc_cell("H", nil, nil),
            StyledSpecHelper.new_wc_cell("e", nil, nil),
            StyledSpecHelper.new_wc_cell("l", nil, nil),
            StyledSpecHelper.new_wc_cell("l", nil, nil),
            StyledSpecHelper.new_wc_cell("o", nil, nil),
            StyledSpecHelper.new_wc_cell(",", nil, nil),
            StyledSpecHelper.new_wc_cell(" ", nil, nil),
            StyledSpecHelper.new_wc_cell("W", nil, nil),
            StyledSpecHelper.new_wc_cell("o", nil, nil),
            StyledSpecHelper.new_wc_cell("r", nil, nil),
            StyledSpecHelper.new_wc_cell("l", nil, nil),
            StyledSpecHelper.new_wc_cell("d", nil, nil),
            StyledSpecHelper.new_wc_cell("!", nil, nil),
          ],
        ]),
      },
      {
        name:            "multiple lines",
        input:           "Hello,\nWorld!",
        expected_width:  6,
        expected_height: 2,
        expected:        StyledSpecHelper.build_buffer([
          [
            StyledSpecHelper.new_wc_cell("H", nil, nil),
            StyledSpecHelper.new_wc_cell("e", nil, nil),
            StyledSpecHelper.new_wc_cell("l", nil, nil),
            StyledSpecHelper.new_wc_cell("l", nil, nil),
            StyledSpecHelper.new_wc_cell("o", nil, nil),
            StyledSpecHelper.new_wc_cell(",", nil, nil),
          ],
          [
            StyledSpecHelper.new_wc_cell("W", nil, nil),
            StyledSpecHelper.new_wc_cell("o", nil, nil),
            StyledSpecHelper.new_wc_cell("r", nil, nil),
            StyledSpecHelper.new_wc_cell("l", nil, nil),
            StyledSpecHelper.new_wc_cell("d", nil, nil),
            StyledSpecHelper.new_wc_cell("!", nil, nil),
          ],
        ]),
      },
      {
        name:            "empty string",
        input:           "",
        expected_width:  0,
        expected_height: 1,
        expected:        StyledSpecHelper.build_buffer([[] of Ultraviolet::Cell]),
      },
      {
        name:            "multiple lines different width",
        input:           "Hello,\nWorld!\nThis is a test.",
        expected_width:  15,
        expected_height: 3,
        expected:        StyledSpecHelper.build_buffer([
          [
            StyledSpecHelper.new_wc_cell("H", nil, nil),
            StyledSpecHelper.new_wc_cell("e", nil, nil),
            StyledSpecHelper.new_wc_cell("l", nil, nil),
            StyledSpecHelper.new_wc_cell("l", nil, nil),
            StyledSpecHelper.new_wc_cell("o", nil, nil),
            StyledSpecHelper.new_wc_cell(",", nil, nil),
            StyledSpecHelper.new_wc_cell(" ", nil, nil),
            StyledSpecHelper.new_wc_cell(" ", nil, nil),
            StyledSpecHelper.new_wc_cell(" ", nil, nil),
            StyledSpecHelper.new_wc_cell(" ", nil, nil),
            StyledSpecHelper.new_wc_cell(" ", nil, nil),
            StyledSpecHelper.new_wc_cell(" ", nil, nil),
            StyledSpecHelper.new_wc_cell(" ", nil, nil),
            StyledSpecHelper.new_wc_cell(" ", nil, nil),
            StyledSpecHelper.new_wc_cell(" ", nil, nil),
          ],
          [
            StyledSpecHelper.new_wc_cell("W", nil, nil),
            StyledSpecHelper.new_wc_cell("o", nil, nil),
            StyledSpecHelper.new_wc_cell("r", nil, nil),
            StyledSpecHelper.new_wc_cell("l", nil, nil),
            StyledSpecHelper.new_wc_cell("d", nil, nil),
            StyledSpecHelper.new_wc_cell("!", nil, nil),
            StyledSpecHelper.new_wc_cell(" ", nil, nil),
            StyledSpecHelper.new_wc_cell(" ", nil, nil),
            StyledSpecHelper.new_wc_cell(" ", nil, nil),
            StyledSpecHelper.new_wc_cell(" ", nil, nil),
            StyledSpecHelper.new_wc_cell(" ", nil, nil),
            StyledSpecHelper.new_wc_cell(" ", nil, nil),
            StyledSpecHelper.new_wc_cell(" ", nil, nil),
            StyledSpecHelper.new_wc_cell(" ", nil, nil),
            StyledSpecHelper.new_wc_cell(" ", nil, nil),
          ],
          [
            StyledSpecHelper.new_wc_cell("T", nil, nil),
            StyledSpecHelper.new_wc_cell("h", nil, nil),
            StyledSpecHelper.new_wc_cell("i", nil, nil),
            StyledSpecHelper.new_wc_cell("s", nil, nil),
            StyledSpecHelper.new_wc_cell(" ", nil, nil),
            StyledSpecHelper.new_wc_cell("i", nil, nil),
            StyledSpecHelper.new_wc_cell("s", nil, nil),
            StyledSpecHelper.new_wc_cell(" ", nil, nil),
            StyledSpecHelper.new_wc_cell("a", nil, nil),
            StyledSpecHelper.new_wc_cell(" ", nil, nil),
            StyledSpecHelper.new_wc_cell("t", nil, nil),
            StyledSpecHelper.new_wc_cell("e", nil, nil),
            StyledSpecHelper.new_wc_cell("s", nil, nil),
            StyledSpecHelper.new_wc_cell("t", nil, nil),
            StyledSpecHelper.new_wc_cell(".", nil, nil),
          ],
        ]),
      },
      {
        name:            "unicode characters",
        input:           "Hello, 世界!",
        expected_width:  12,
        expected_height: 1,
        expected:        StyledSpecHelper.build_buffer([
          [
            StyledSpecHelper.new_wc_cell("H", nil, nil),
            StyledSpecHelper.new_wc_cell("e", nil, nil),
            StyledSpecHelper.new_wc_cell("l", nil, nil),
            StyledSpecHelper.new_wc_cell("l", nil, nil),
            StyledSpecHelper.new_wc_cell("o", nil, nil),
            StyledSpecHelper.new_wc_cell(",", nil, nil),
            StyledSpecHelper.new_wc_cell(" ", nil, nil),
            StyledSpecHelper.new_wc_cell("世", nil, nil),
            Ultraviolet::Cell.new,
            StyledSpecHelper.new_wc_cell("界", nil, nil),
            Ultraviolet::Cell.new,
            StyledSpecHelper.new_wc_cell("!", nil, nil),
          ],
        ]),
      },
      {
        name:            "styled hello world string",
        input:           "\e[31;1;4mHello, \e[32;22;4mWorld!\e[0m",
        expected_width:  13,
        expected_height: 1,
        expected:        StyledSpecHelper.build_buffer([
          [
            StyledSpecHelper.new_wc_cell("H", Ultraviolet::Style.new(fg: red, underline: Ultraviolet::Underline::Single, attrs: Ultraviolet::Attr::BOLD), nil),
            StyledSpecHelper.new_wc_cell("e", Ultraviolet::Style.new(fg: red, underline: Ultraviolet::Underline::Single, attrs: Ultraviolet::Attr::BOLD), nil),
            StyledSpecHelper.new_wc_cell("l", Ultraviolet::Style.new(fg: red, underline: Ultraviolet::Underline::Single, attrs: Ultraviolet::Attr::BOLD), nil),
            StyledSpecHelper.new_wc_cell("l", Ultraviolet::Style.new(fg: red, underline: Ultraviolet::Underline::Single, attrs: Ultraviolet::Attr::BOLD), nil),
            StyledSpecHelper.new_wc_cell("o", Ultraviolet::Style.new(fg: red, underline: Ultraviolet::Underline::Single, attrs: Ultraviolet::Attr::BOLD), nil),
            StyledSpecHelper.new_wc_cell(",", Ultraviolet::Style.new(fg: red, underline: Ultraviolet::Underline::Single, attrs: Ultraviolet::Attr::BOLD), nil),
            StyledSpecHelper.new_wc_cell(" ", Ultraviolet::Style.new(fg: red, underline: Ultraviolet::Underline::Single, attrs: Ultraviolet::Attr::BOLD), nil),
            StyledSpecHelper.new_wc_cell("W", Ultraviolet::Style.new(fg: green, underline: Ultraviolet::Underline::Single), nil),
            StyledSpecHelper.new_wc_cell("o", Ultraviolet::Style.new(fg: green, underline: Ultraviolet::Underline::Single), nil),
            StyledSpecHelper.new_wc_cell("r", Ultraviolet::Style.new(fg: green, underline: Ultraviolet::Underline::Single), nil),
            StyledSpecHelper.new_wc_cell("l", Ultraviolet::Style.new(fg: green, underline: Ultraviolet::Underline::Single), nil),
            StyledSpecHelper.new_wc_cell("d", Ultraviolet::Style.new(fg: green, underline: Ultraviolet::Underline::Single), nil),
            StyledSpecHelper.new_wc_cell("!", Ultraviolet::Style.new(fg: green, underline: Ultraviolet::Underline::Single), nil),
          ],
        ]),
      },
      {
        name:            "complex styling with multiple SGR sequences",
        input:           "\e[31;1;2;4mR\e[22;1med\e[0m \e[32;3mGreen\e[0m \e[34;9mBlue\e[0m \e[33;7mYellow\e[0m \e[35;5mPurple\e[0m",
        expected_width:  28,
        expected_height: 1,
        expected:        StyledSpecHelper.build_buffer([
          [
            StyledSpecHelper.new_wc_cell("R", Ultraviolet::Style.new(fg: red, underline: Ultraviolet::Underline::Single, attrs: Ultraviolet::Attr::BOLD | Ultraviolet::Attr::FAINT), nil),
            StyledSpecHelper.new_wc_cell("e", Ultraviolet::Style.new(fg: red, underline: Ultraviolet::Underline::Single, attrs: Ultraviolet::Attr::BOLD), nil),
            StyledSpecHelper.new_wc_cell("d", Ultraviolet::Style.new(fg: red, underline: Ultraviolet::Underline::Single, attrs: Ultraviolet::Attr::BOLD), nil),
            StyledSpecHelper.new_wc_cell(" ", nil, nil),
            StyledSpecHelper.new_wc_cell("G", Ultraviolet::Style.new(fg: green, attrs: Ultraviolet::Attr::ITALIC), nil),
            StyledSpecHelper.new_wc_cell("r", Ultraviolet::Style.new(fg: green, attrs: Ultraviolet::Attr::ITALIC), nil),
            StyledSpecHelper.new_wc_cell("e", Ultraviolet::Style.new(fg: green, attrs: Ultraviolet::Attr::ITALIC), nil),
            StyledSpecHelper.new_wc_cell("e", Ultraviolet::Style.new(fg: green, attrs: Ultraviolet::Attr::ITALIC), nil),
            StyledSpecHelper.new_wc_cell("n", Ultraviolet::Style.new(fg: green, attrs: Ultraviolet::Attr::ITALIC), nil),
            StyledSpecHelper.new_wc_cell(" ", nil, nil),
            StyledSpecHelper.new_wc_cell("B", Ultraviolet::Style.new(fg: blue, attrs: Ultraviolet::Attr::STRIKETHROUGH), nil),
            StyledSpecHelper.new_wc_cell("l", Ultraviolet::Style.new(fg: blue, attrs: Ultraviolet::Attr::STRIKETHROUGH), nil),
            StyledSpecHelper.new_wc_cell("u", Ultraviolet::Style.new(fg: blue, attrs: Ultraviolet::Attr::STRIKETHROUGH), nil),
            StyledSpecHelper.new_wc_cell("e", Ultraviolet::Style.new(fg: blue, attrs: Ultraviolet::Attr::STRIKETHROUGH), nil),
            StyledSpecHelper.new_wc_cell(" ", nil, nil),
            StyledSpecHelper.new_wc_cell("Y", Ultraviolet::Style.new(fg: yellow, attrs: Ultraviolet::Attr::REVERSE), nil),
            StyledSpecHelper.new_wc_cell("e", Ultraviolet::Style.new(fg: yellow, attrs: Ultraviolet::Attr::REVERSE), nil),
            StyledSpecHelper.new_wc_cell("l", Ultraviolet::Style.new(fg: yellow, attrs: Ultraviolet::Attr::REVERSE), nil),
            StyledSpecHelper.new_wc_cell("l", Ultraviolet::Style.new(fg: yellow, attrs: Ultraviolet::Attr::REVERSE), nil),
            StyledSpecHelper.new_wc_cell("o", Ultraviolet::Style.new(fg: yellow, attrs: Ultraviolet::Attr::REVERSE), nil),
            StyledSpecHelper.new_wc_cell("w", Ultraviolet::Style.new(fg: yellow, attrs: Ultraviolet::Attr::REVERSE), nil),
            StyledSpecHelper.new_wc_cell(" ", nil, nil),
            StyledSpecHelper.new_wc_cell("P", Ultraviolet::Style.new(fg: magenta, attrs: Ultraviolet::Attr::BLINK), nil),
            StyledSpecHelper.new_wc_cell("u", Ultraviolet::Style.new(fg: magenta, attrs: Ultraviolet::Attr::BLINK), nil),
            StyledSpecHelper.new_wc_cell("r", Ultraviolet::Style.new(fg: magenta, attrs: Ultraviolet::Attr::BLINK), nil),
            StyledSpecHelper.new_wc_cell("p", Ultraviolet::Style.new(fg: magenta, attrs: Ultraviolet::Attr::BLINK), nil),
            StyledSpecHelper.new_wc_cell("l", Ultraviolet::Style.new(fg: magenta, attrs: Ultraviolet::Attr::BLINK), nil),
            StyledSpecHelper.new_wc_cell("e", Ultraviolet::Style.new(fg: magenta, attrs: Ultraviolet::Attr::BLINK), nil),
          ],
        ]),
      },
      {
        name:            "different underline styles",
        input:           "\e[4:1mSingle\e[0m \e[4:2mDouble\e[0m \e[4:3mCurly\e[0m \e[4:4mDotted\e[0m \e[4:5mDashed\e[0m",
        expected_width:  33,
        expected_height: 1,
        expected:        StyledSpecHelper.build_buffer([
          [
            StyledSpecHelper.new_wc_cell("S", Ultraviolet::Style.new(underline: Ultraviolet::Underline::Single), nil),
            StyledSpecHelper.new_wc_cell("i", Ultraviolet::Style.new(underline: Ultraviolet::Underline::Single), nil),
            StyledSpecHelper.new_wc_cell("n", Ultraviolet::Style.new(underline: Ultraviolet::Underline::Single), nil),
            StyledSpecHelper.new_wc_cell("g", Ultraviolet::Style.new(underline: Ultraviolet::Underline::Single), nil),
            StyledSpecHelper.new_wc_cell("l", Ultraviolet::Style.new(underline: Ultraviolet::Underline::Single), nil),
            StyledSpecHelper.new_wc_cell("e", Ultraviolet::Style.new(underline: Ultraviolet::Underline::Single), nil),
            StyledSpecHelper.new_wc_cell(" ", nil, nil),
            StyledSpecHelper.new_wc_cell("D", Ultraviolet::Style.new(underline: Ultraviolet::Underline::Double), nil),
            StyledSpecHelper.new_wc_cell("o", Ultraviolet::Style.new(underline: Ultraviolet::Underline::Double), nil),
            StyledSpecHelper.new_wc_cell("u", Ultraviolet::Style.new(underline: Ultraviolet::Underline::Double), nil),
            StyledSpecHelper.new_wc_cell("b", Ultraviolet::Style.new(underline: Ultraviolet::Underline::Double), nil),
            StyledSpecHelper.new_wc_cell("l", Ultraviolet::Style.new(underline: Ultraviolet::Underline::Double), nil),
            StyledSpecHelper.new_wc_cell("e", Ultraviolet::Style.new(underline: Ultraviolet::Underline::Double), nil),
            StyledSpecHelper.new_wc_cell(" ", nil, nil),
            StyledSpecHelper.new_wc_cell("C", Ultraviolet::Style.new(underline: Ultraviolet::Underline::Curly), nil),
            StyledSpecHelper.new_wc_cell("u", Ultraviolet::Style.new(underline: Ultraviolet::Underline::Curly), nil),
            StyledSpecHelper.new_wc_cell("r", Ultraviolet::Style.new(underline: Ultraviolet::Underline::Curly), nil),
            StyledSpecHelper.new_wc_cell("l", Ultraviolet::Style.new(underline: Ultraviolet::Underline::Curly), nil),
            StyledSpecHelper.new_wc_cell("y", Ultraviolet::Style.new(underline: Ultraviolet::Underline::Curly), nil),
            StyledSpecHelper.new_wc_cell(" ", nil, nil),
            StyledSpecHelper.new_wc_cell("D", Ultraviolet::Style.new(underline: Ultraviolet::Underline::Dotted), nil),
            StyledSpecHelper.new_wc_cell("o", Ultraviolet::Style.new(underline: Ultraviolet::Underline::Dotted), nil),
            StyledSpecHelper.new_wc_cell("t", Ultraviolet::Style.new(underline: Ultraviolet::Underline::Dotted), nil),
            StyledSpecHelper.new_wc_cell("t", Ultraviolet::Style.new(underline: Ultraviolet::Underline::Dotted), nil),
            StyledSpecHelper.new_wc_cell("e", Ultraviolet::Style.new(underline: Ultraviolet::Underline::Dotted), nil),
            StyledSpecHelper.new_wc_cell("d", Ultraviolet::Style.new(underline: Ultraviolet::Underline::Dotted), nil),
            StyledSpecHelper.new_wc_cell(" ", nil, nil),
            StyledSpecHelper.new_wc_cell("D", Ultraviolet::Style.new(underline: Ultraviolet::Underline::Dashed), nil),
            StyledSpecHelper.new_wc_cell("a", Ultraviolet::Style.new(underline: Ultraviolet::Underline::Dashed), nil),
            StyledSpecHelper.new_wc_cell("s", Ultraviolet::Style.new(underline: Ultraviolet::Underline::Dashed), nil),
            StyledSpecHelper.new_wc_cell("h", Ultraviolet::Style.new(underline: Ultraviolet::Underline::Dashed), nil),
            StyledSpecHelper.new_wc_cell("e", Ultraviolet::Style.new(underline: Ultraviolet::Underline::Dashed), nil),
            StyledSpecHelper.new_wc_cell("d", Ultraviolet::Style.new(underline: Ultraviolet::Underline::Dashed), nil),
          ],
        ]),
      },
      {
        name:            "truecolor and 256 color support",
        input:           "\e[38;2;255;0;0mRGB Red\e[0m \e[48;2;0;255;0mRGB Green BG\e[0m \e[38;5;33m256 Blue\e[0m",
        expected_width:  29,
        expected_height: 1,
        expected:        StyledSpecHelper.build_buffer([
          [
            StyledSpecHelper.new_wc_cell("R", Ultraviolet::Style.new(fg: Ultraviolet::Color.new(255_u8, 0_u8, 0_u8)), nil),
            StyledSpecHelper.new_wc_cell("G", Ultraviolet::Style.new(fg: Ultraviolet::Color.new(255_u8, 0_u8, 0_u8)), nil),
            StyledSpecHelper.new_wc_cell("B", Ultraviolet::Style.new(fg: Ultraviolet::Color.new(255_u8, 0_u8, 0_u8)), nil),
            StyledSpecHelper.new_wc_cell(" ", Ultraviolet::Style.new(fg: Ultraviolet::Color.new(255_u8, 0_u8, 0_u8)), nil),
            StyledSpecHelper.new_wc_cell("R", Ultraviolet::Style.new(fg: Ultraviolet::Color.new(255_u8, 0_u8, 0_u8)), nil),
            StyledSpecHelper.new_wc_cell("e", Ultraviolet::Style.new(fg: Ultraviolet::Color.new(255_u8, 0_u8, 0_u8)), nil),
            StyledSpecHelper.new_wc_cell("d", Ultraviolet::Style.new(fg: Ultraviolet::Color.new(255_u8, 0_u8, 0_u8)), nil),
            StyledSpecHelper.new_wc_cell(" ", nil, nil),
            StyledSpecHelper.new_wc_cell("R", Ultraviolet::Style.new(bg: Ultraviolet::Color.new(0_u8, 255_u8, 0_u8)), nil),
            StyledSpecHelper.new_wc_cell("G", Ultraviolet::Style.new(bg: Ultraviolet::Color.new(0_u8, 255_u8, 0_u8)), nil),
            StyledSpecHelper.new_wc_cell("B", Ultraviolet::Style.new(bg: Ultraviolet::Color.new(0_u8, 255_u8, 0_u8)), nil),
            StyledSpecHelper.new_wc_cell(" ", Ultraviolet::Style.new(bg: Ultraviolet::Color.new(0_u8, 255_u8, 0_u8)), nil),
            StyledSpecHelper.new_wc_cell("G", Ultraviolet::Style.new(bg: Ultraviolet::Color.new(0_u8, 255_u8, 0_u8)), nil),
            StyledSpecHelper.new_wc_cell("r", Ultraviolet::Style.new(bg: Ultraviolet::Color.new(0_u8, 255_u8, 0_u8)), nil),
            StyledSpecHelper.new_wc_cell("e", Ultraviolet::Style.new(bg: Ultraviolet::Color.new(0_u8, 255_u8, 0_u8)), nil),
            StyledSpecHelper.new_wc_cell("e", Ultraviolet::Style.new(bg: Ultraviolet::Color.new(0_u8, 255_u8, 0_u8)), nil),
            StyledSpecHelper.new_wc_cell("n", Ultraviolet::Style.new(bg: Ultraviolet::Color.new(0_u8, 255_u8, 0_u8)), nil),
            StyledSpecHelper.new_wc_cell(" ", Ultraviolet::Style.new(bg: Ultraviolet::Color.new(0_u8, 255_u8, 0_u8)), nil),
            StyledSpecHelper.new_wc_cell("B", Ultraviolet::Style.new(bg: Ultraviolet::Color.new(0_u8, 255_u8, 0_u8)), nil),
            StyledSpecHelper.new_wc_cell("G", Ultraviolet::Style.new(bg: Ultraviolet::Color.new(0_u8, 255_u8, 0_u8)), nil),
            StyledSpecHelper.new_wc_cell(" ", nil, nil),
            StyledSpecHelper.new_wc_cell("2", Ultraviolet::Style.new(fg: Ultraviolet::AnsiColor.indexed(33)), nil),
            StyledSpecHelper.new_wc_cell("5", Ultraviolet::Style.new(fg: Ultraviolet::AnsiColor.indexed(33)), nil),
            StyledSpecHelper.new_wc_cell("6", Ultraviolet::Style.new(fg: Ultraviolet::AnsiColor.indexed(33)), nil),
            StyledSpecHelper.new_wc_cell(" ", Ultraviolet::Style.new(fg: Ultraviolet::AnsiColor.indexed(33)), nil),
            StyledSpecHelper.new_wc_cell("B", Ultraviolet::Style.new(fg: Ultraviolet::AnsiColor.indexed(33)), nil),
            StyledSpecHelper.new_wc_cell("l", Ultraviolet::Style.new(fg: Ultraviolet::AnsiColor.indexed(33)), nil),
            StyledSpecHelper.new_wc_cell("u", Ultraviolet::Style.new(fg: Ultraviolet::AnsiColor.indexed(33)), nil),
            StyledSpecHelper.new_wc_cell("e", Ultraviolet::Style.new(fg: Ultraviolet::AnsiColor.indexed(33)), nil),
          ],
        ]),
      },
      {
        name:            "hyperlink support",
        input:           "Normal \e]8;;https://charm.sh\e\\Charm\e]8;;\e\\ Text \e]8;;https://github.com/charmbracelet\e\\GitHub\e]8;;\e\\",
        expected_width:  24,
        expected_height: 1,
        expected:        StyledSpecHelper.build_buffer([
          [
            StyledSpecHelper.new_wc_cell("N", nil, nil),
            StyledSpecHelper.new_wc_cell("o", nil, nil),
            StyledSpecHelper.new_wc_cell("r", nil, nil),
            StyledSpecHelper.new_wc_cell("m", nil, nil),
            StyledSpecHelper.new_wc_cell("a", nil, nil),
            StyledSpecHelper.new_wc_cell("l", nil, nil),
            StyledSpecHelper.new_wc_cell(" ", nil, nil),
            StyledSpecHelper.new_wc_cell("C", nil, Ultraviolet::Link.new("https://charm.sh")),
            StyledSpecHelper.new_wc_cell("h", nil, Ultraviolet::Link.new("https://charm.sh")),
            StyledSpecHelper.new_wc_cell("a", nil, Ultraviolet::Link.new("https://charm.sh")),
            StyledSpecHelper.new_wc_cell("r", nil, Ultraviolet::Link.new("https://charm.sh")),
            StyledSpecHelper.new_wc_cell("m", nil, Ultraviolet::Link.new("https://charm.sh")),
            StyledSpecHelper.new_wc_cell(" ", nil, nil),
            StyledSpecHelper.new_wc_cell("T", nil, nil),
            StyledSpecHelper.new_wc_cell("e", nil, nil),
            StyledSpecHelper.new_wc_cell("x", nil, nil),
            StyledSpecHelper.new_wc_cell("t", nil, nil),
            StyledSpecHelper.new_wc_cell(" ", nil, nil),
            StyledSpecHelper.new_wc_cell("G", nil, Ultraviolet::Link.new("https://github.com/charmbracelet")),
            StyledSpecHelper.new_wc_cell("i", nil, Ultraviolet::Link.new("https://github.com/charmbracelet")),
            StyledSpecHelper.new_wc_cell("t", nil, Ultraviolet::Link.new("https://github.com/charmbracelet")),
            StyledSpecHelper.new_wc_cell("H", nil, Ultraviolet::Link.new("https://github.com/charmbracelet")),
            StyledSpecHelper.new_wc_cell("u", nil, Ultraviolet::Link.new("https://github.com/charmbracelet")),
            StyledSpecHelper.new_wc_cell("b", nil, Ultraviolet::Link.new("https://github.com/charmbracelet")),
          ],
        ]),
      },
      {
        name:            "complex mixed styling with hyperlinks",
        input:           "\e[31;1;2;3mR\e[22;23;1med \e]8;;https://charm.sh\e\\\e[4mCharm\e]8;;\e\\\e[0m \e[38;5;33;48;2;0;100;0m\e]8;;https://github.com\e\\GitHub\e]8;;\e\\\e[0m",
        expected_width:  16,
        expected_height: 1,
        expected:        StyledSpecHelper.build_buffer([
          [
            StyledSpecHelper.new_wc_cell("R", Ultraviolet::Style.new(fg: red, attrs: Ultraviolet::Attr::BOLD | Ultraviolet::Attr::FAINT | Ultraviolet::Attr::ITALIC), nil),
            StyledSpecHelper.new_wc_cell("e", Ultraviolet::Style.new(fg: red, attrs: Ultraviolet::Attr::BOLD), nil),
            StyledSpecHelper.new_wc_cell("d", Ultraviolet::Style.new(fg: red, attrs: Ultraviolet::Attr::BOLD), nil),
            StyledSpecHelper.new_wc_cell(" ", Ultraviolet::Style.new(fg: red, attrs: Ultraviolet::Attr::BOLD), nil),
            StyledSpecHelper.new_wc_cell("C", Ultraviolet::Style.new(fg: red, underline: Ultraviolet::Underline::Single, attrs: Ultraviolet::Attr::BOLD), Ultraviolet::Link.new("https://charm.sh")),
            StyledSpecHelper.new_wc_cell("h", Ultraviolet::Style.new(fg: red, underline: Ultraviolet::Underline::Single, attrs: Ultraviolet::Attr::BOLD), Ultraviolet::Link.new("https://charm.sh")),
            StyledSpecHelper.new_wc_cell("a", Ultraviolet::Style.new(fg: red, underline: Ultraviolet::Underline::Single, attrs: Ultraviolet::Attr::BOLD), Ultraviolet::Link.new("https://charm.sh")),
            StyledSpecHelper.new_wc_cell("r", Ultraviolet::Style.new(fg: red, underline: Ultraviolet::Underline::Single, attrs: Ultraviolet::Attr::BOLD), Ultraviolet::Link.new("https://charm.sh")),
            StyledSpecHelper.new_wc_cell("m", Ultraviolet::Style.new(fg: red, underline: Ultraviolet::Underline::Single, attrs: Ultraviolet::Attr::BOLD), Ultraviolet::Link.new("https://charm.sh")),
            StyledSpecHelper.new_wc_cell(" ", nil, nil),
            StyledSpecHelper.new_wc_cell("G", Ultraviolet::Style.new(fg: Ultraviolet::AnsiColor.indexed(33), bg: Ultraviolet::Color.new(0_u8, 100_u8, 0_u8)), Ultraviolet::Link.new("https://github.com")),
            StyledSpecHelper.new_wc_cell("i", Ultraviolet::Style.new(fg: Ultraviolet::AnsiColor.indexed(33), bg: Ultraviolet::Color.new(0_u8, 100_u8, 0_u8)), Ultraviolet::Link.new("https://github.com")),
            StyledSpecHelper.new_wc_cell("t", Ultraviolet::Style.new(fg: Ultraviolet::AnsiColor.indexed(33), bg: Ultraviolet::Color.new(0_u8, 100_u8, 0_u8)), Ultraviolet::Link.new("https://github.com")),
            StyledSpecHelper.new_wc_cell("H", Ultraviolet::Style.new(fg: Ultraviolet::AnsiColor.indexed(33), bg: Ultraviolet::Color.new(0_u8, 100_u8, 0_u8)), Ultraviolet::Link.new("https://github.com")),
            StyledSpecHelper.new_wc_cell("u", Ultraviolet::Style.new(fg: Ultraviolet::AnsiColor.indexed(33), bg: Ultraviolet::Color.new(0_u8, 100_u8, 0_u8)), Ultraviolet::Link.new("https://github.com")),
            StyledSpecHelper.new_wc_cell("b", Ultraviolet::Style.new(fg: Ultraviolet::AnsiColor.indexed(33), bg: Ultraviolet::Color.new(0_u8, 100_u8, 0_u8)), Ultraviolet::Link.new("https://github.com")),
          ],
        ]),
      },
    ]

    cases.each_with_index do |test_case, index|
      ss = Ultraviolet::StyledString.new(test_case[:input])
      area = ss.bounds
      buffer = Ultraviolet::ScreenBuffer.new(area.dx, area.dy)
      ss.draw(buffer, area)

      buffer.width.should eq(test_case[:expected_width]), test_case[:name]
      buffer.height.should eq(test_case[:expected_height]), test_case[:name]

      (0...buffer.height).each do |y|
        (0...buffer.width).each do |x|
          expected_cell = test_case[:expected].cell_at(x, y)
          actual_cell = buffer.cell_at(x, y)
          Ultraviolet.cell_equal?(expected_cell, actual_cell).should be_true,
            "case #{index + 1} #{test_case[:name]} expected cell #{x},#{y}"
        end
      end
    end
  end

  it "renders empty lines when truncating" do
    input = "\e[31;1;4mHello, \e[32;22;4mWorld!\e[0m"
    ss = Ultraviolet::StyledString.new(input)
    screen = Ultraviolet::ScreenBuffer.new(5, 3)
    ss.draw(screen, screen.bounds)

    red = Ultraviolet::AnsiColor.basic(1)
    expected = StyledSpecHelper.build_buffer([
      [
        StyledSpecHelper.new_wc_cell("H", Ultraviolet::Style.new(fg: red, underline: Ultraviolet::Underline::Single, attrs: Ultraviolet::Attr::BOLD), nil),
        StyledSpecHelper.new_wc_cell("e", Ultraviolet::Style.new(fg: red, underline: Ultraviolet::Underline::Single, attrs: Ultraviolet::Attr::BOLD), nil),
        StyledSpecHelper.new_wc_cell("l", Ultraviolet::Style.new(fg: red, underline: Ultraviolet::Underline::Single, attrs: Ultraviolet::Attr::BOLD), nil),
        StyledSpecHelper.new_wc_cell("l", Ultraviolet::Style.new(fg: red, underline: Ultraviolet::Underline::Single, attrs: Ultraviolet::Attr::BOLD), nil),
        StyledSpecHelper.new_wc_cell("o", Ultraviolet::Style.new(fg: red, underline: Ultraviolet::Underline::Single, attrs: Ultraviolet::Attr::BOLD), nil),
      ],
      Array(Ultraviolet::Cell).new(5, Ultraviolet::EMPTY_CELL),
      Array(Ultraviolet::Cell).new(5, Ultraviolet::EMPTY_CELL),
    ])

    (0...screen.height).each do |y|
      (0...screen.width).each do |x|
        expected_cell = expected.cell_at(x, y)
        actual_cell = screen.cell_at(x, y)
        Ultraviolet.cell_equal?(expected_cell, actual_cell).should be_true,
          "expected cell #{x},#{y}"
      end
    end
  end

  it "builds lines with the provided width method" do
    method = ->(value : String) do
      if value == "a" || value == "b" || value == "c"
        2
      else
        UnicodeCharWidth.width(value)
      end
    end

    lines = Ultraviolet::StyledString.new("ab\nc").lines(method)
    lines.size.should eq(2)
    lines[0].cells[0].string.should eq("a")
    lines[0].cells[0].width.should eq(2)
    lines[0].cells[2].string.should eq("b")
    lines[0].cells[2].width.should eq(2)
    lines[1].cells[0].string.should eq("c")
    lines[1].cells[0].width.should eq(2)
  end

  it "uses screen width method while drawing wrapped text" do
    method = ->(value : String) do
      if value == "a" || value == "b"
        2
      else
        UnicodeCharWidth.width(value)
      end
    end

    screen = Ultraviolet::ScreenBuffer.new(2, 2, method)
    Ultraviolet::StyledString.new("ab", wrap: true).draw(screen, screen.bounds)

    screen.cell_at(0, 0).try(&.string).should eq("a")
    screen.cell_at(0, 1).try(&.string).should eq("b")
  end

  describe "public parsing helpers" do
    it "parses SGR params via read_style_from_params" do
      parsed = Ultraviolet.read_style_from_params("31;1;4:3", Ultraviolet::Style.new)

      parsed.fg.should eq(Ultraviolet::AnsiColor.basic(1))
      parsed.underline.should eq(Ultraviolet::Underline::Curly)
      parsed.attrs.should eq(Ultraviolet::Attr::BOLD)
    end

    it "resets style with empty SGR params" do
      pen = Ultraviolet::Style.new(
        fg: Ultraviolet::AnsiColor.basic(2),
        underline: Ultraviolet::Underline::Double,
        attrs: Ultraviolet::Attr::ITALIC
      )
      parsed = Ultraviolet.read_style_from_params("", pen)
      parsed.should eq(Ultraviolet::Style.new)
    end

    it "parses OSC hyperlink payload via read_link_from_data" do
      parsed = Ultraviolet.read_link_from_data("8;id=repo;https://example.com".to_slice, Ultraviolet::Link.new)
      parsed.should eq(Ultraviolet::Link.new("https://example.com", "id=repo"))
    end
  end
end
