require "./spec_helper"

module Ultraviolet
  private class TestLogger
    include Logger

    getter buf : IO::Memory

    def initialize
      @buf = IO::Memory.new
    end

    def printf(format : String, *args)
      @buf << "LOG: "
      @buf << sprintf(format, *args)
      @buf << "\n"
    end
  end

  describe TerminalRenderer do
    it "renders simple output" do
      buf = IO::Memory.new
      renderer = TerminalRenderer.new(buf, ["TERM=xterm-256color", "COLORTERM=truecolor"])

      renderer.fullscreen = true
      renderer.relative_cursor = false
      renderer.save_cursor
      renderer.erase

      renderer.resize(5, 3)
      cellbuf = RenderBuffer.new(5, 3)

      cell = Cell.new("X", 1)
      cellbuf.set_cell(0, 0, cell)
      cellbuf.set_cell(1, 1, cell)
      cellbuf.set_cell(2, 2, cell)

      renderer.render(cellbuf)
      renderer.flush

      buf.to_s.should eq("\e[H\e[2JX\nX\nX")
    end

    it "renders inline output" do
      buf = IO::Memory.new
      renderer = TerminalRenderer.new(buf, ["TERM=xterm-256color", "COLORTERM=truecolor"])

      renderer.relative_cursor = true

      renderer.resize(80, 24)
      cellbuf = RenderBuffer.new(80, 3)

      "Hello, World!".each_char_with_index do |char, index|
        cellbuf.set_cell(index, 0, Cell.new(char.to_s, 1))
      end

      renderer.render(cellbuf)
      renderer.flush

      buf.to_s.should eq("\rHello, World!\r\n\n")
    end

    it "sets color profile" do
      tests = [
        {"truecolor", ColorProfile::TrueColor, ["COLORTERM=truecolor"], ColorProfile::TrueColor},
        {"256 color", ColorProfile::ANSI256, ["TERM=xterm-256color"], ColorProfile::ANSI256},
        {"16 color", ColorProfile::ANSI, ["TERM=xterm"], ColorProfile::ANSI},
      ]

      tests.each do |entry|
        _name, profile, env, _expected = entry
        buf = IO::Memory.new
        renderer = TerminalRenderer.new(buf, env)
        renderer.color_profile = profile

        cellbuf = RenderBuffer.new(1, 1)
        cellbuf.set_cell(0, 0, Cell.new("X", 1, Style.new(fg: Color.new(255_u8, 0_u8, 0_u8))))

        renderer.render(cellbuf)
        renderer.flush

        buf.to_s.includes?("X").should be_true
      end
    end

    it "tracks position" do
      buf = IO::Memory.new
      renderer = TerminalRenderer.new(buf, ["TERM=xterm-256color"])

      renderer.position.should eq({-1, -1})

      renderer.set_position(5, 10)
      renderer.position.should eq({5, 10})
    end

    it "moves cursor" do
      buf = IO::Memory.new
      renderer = TerminalRenderer.new(buf, ["TERM=xterm-256color"])

      renderer.move_to(5, 3)
      renderer.flush

      buf.to_s.includes?("\e[").should be_true
    end

    it "writes strings" do
      buf = IO::Memory.new
      renderer = TerminalRenderer.new(buf, ["TERM=xterm-256color"])

      n = renderer.write_string("Hello, World!")
      n.should eq(13)

      renderer.flush
      buf.to_s.includes?("Hello, World!").should be_true
    end

    it "writes bytes" do
      buf = IO::Memory.new
      renderer = TerminalRenderer.new(buf, ["TERM=xterm-256color"])

      data = "Hello, World!".to_slice
      n = renderer.write(data)
      n.should eq(data.size)

      renderer.flush
      buf.to_s.includes?("Hello, World!").should be_true
    end

    it "redraws" do
      buf = IO::Memory.new
      renderer = TerminalRenderer.new(buf, ["TERM=xterm-256color"])

      cellbuf = RenderBuffer.new(3, 1)
      cellbuf.set_cell(0, 0, Cell.new("X", 1))

      renderer.render(cellbuf)
      renderer.flush
      first = buf.to_s
      buf.clear

      renderer.redraw(cellbuf)
      renderer.flush
      second = buf.to_s

      first.includes?("X").should be_true
      second.includes?("X").should be_true
    end

    it "erases" do
      buf = IO::Memory.new
      renderer = TerminalRenderer.new(buf, ["TERM=xterm-256color"])

      cellbuf = RenderBuffer.new(3, 1)
      cellbuf.set_cell(0, 0, Cell.new("X", 1))

      renderer.erase
      renderer.render(cellbuf)
      renderer.flush

      buf.to_s.includes?("X").should be_true
    end

    it "resizes" do
      buf = IO::Memory.new
      renderer = TerminalRenderer.new(buf, ["TERM=xterm-256color"])

      renderer.resize(80, 24)
      cellbuf = RenderBuffer.new(80, 24)
      renderer.render(cellbuf)
      renderer.flush
    end

    it "prepends strings" do
      buf = IO::Memory.new
      renderer = TerminalRenderer.new(buf, ["TERM=xterm-256color"])

      renderer.resize(10, 5)
      cellbuf = RenderBuffer.new(10, 5)

      renderer.prepend_string(cellbuf, "Prepended line")
      renderer.render(cellbuf)
      renderer.flush

      buf.to_s.includes?("Prepended line").should be_true
    end

    it "prepends lines" do
      buf = IO::Memory.new
      renderer = TerminalRenderer.new(buf, ["TERM=xterm-256color"])

      renderer.resize(10, 5)
      cellbuf = RenderBuffer.new(10, 5)

      line = Line.new(5)
      "Hello".each_char_with_index do |char, index|
        line.set(index, Cell.new(char.to_s, 1))
      end

      renderer.prepend_string(cellbuf, line.render)
      renderer.render(cellbuf)
      renderer.flush

      buf.to_s.includes?("Hello").should be_true
    end

    it "reports capabilities" do
      buf = IO::Memory.new
      renderer = TerminalRenderer.new(buf, ["TERM=xterm-256color"])
      renderer.caps.includes?(Capabilities::CHA).should be_true

      linux = TerminalRenderer.new(buf, ["TERM=linux"])
      linux.caps.includes?(Capabilities::VPA).should be_true
      linux.caps.includes?(Capabilities::HPA).should be_true
      linux.caps.includes?(Capabilities::REP).should be_false
    end

    it "supports tab stops" do
      buf = IO::Memory.new
      renderer = TerminalRenderer.new(buf, ["TERM=xterm-256color"])

      renderer.tab_stops = 8
      cellbuf = RenderBuffer.new(20, 1)
      renderer.render(cellbuf)
      renderer.flush

      renderer.tab_stops = -1
      renderer.render(cellbuf)
      renderer.flush
    end

    it "supports backspace" do
      buf = IO::Memory.new
      renderer = TerminalRenderer.new(buf, ["TERM=xterm-256color"])

      renderer.backspace = true
      cellbuf = RenderBuffer.new(10, 1)
      renderer.render(cellbuf)
      renderer.flush

      renderer.backspace = false
      renderer.render(cellbuf)
      renderer.flush
    end

    it "supports map newline" do
      buf = IO::Memory.new
      renderer = TerminalRenderer.new(buf, ["TERM=xterm-256color"])

      renderer.map_newline = true
      cellbuf = RenderBuffer.new(10, 2)
      renderer.render(cellbuf)
      renderer.flush

      renderer.map_newline = false
      renderer.render(cellbuf)
      renderer.flush
    end

    it "tracks touched lines" do
      buf = IO::Memory.new
      renderer = TerminalRenderer.new(buf, ["TERM=xterm-256color"])
      cellbuf = RenderBuffer.new(5, 3)

      renderer.touched(cellbuf).should eq(0)

      cell = Cell.new("X", 1)
      cellbuf.set_cell(0, 0, cell)
      cellbuf.set_cell(0, 2, cell)

      renderer.touched(cellbuf).should eq(2)

      renderer.render(cellbuf)
      renderer.touched(cellbuf).should eq(3)

      actual = 0
      cellbuf.touched.each do |line|
        if line && (line.first_cell != -1 || line.last_cell != -1)
          actual += 1
        end
      end
      actual.should eq(0)
    end

    it "handles wide characters" do
      buf = IO::Memory.new
      renderer = TerminalRenderer.new(buf, ["TERM=xterm-256color"])
      cellbuf = RenderBuffer.new(10, 1)

      wide = ["🌟", "中", "文", "字"]
      wide.each_with_index do |char, idx|
        cellbuf.set_cell(idx * 2, 0, Cell.new(char, 2))
      end

      renderer.render(cellbuf)
      renderer.flush

      output = buf.to_s
      wide.each do |char|
        output.includes?(char).should be_true
      end
    end

    it "handles zero width characters" do
      buf = IO::Memory.new
      renderer = TerminalRenderer.new(buf, ["TERM=xterm-256color"])
      cellbuf = RenderBuffer.new(5, 1)

      cellbuf.set_cell(0, 0, Cell.new("a\u0301", 1))
      cellbuf.set_cell(1, 0, Cell.new("\u200B", 0))

      renderer.render(cellbuf)
      renderer.flush

      buf.to_s.includes?("a\u0301").should be_true
    end

    it "renders styled text" do
      buf = IO::Memory.new
      renderer = TerminalRenderer.new(buf, ["TERM=xterm-256color"])
      cellbuf = RenderBuffer.new(10, 1)

      styles = [
        Style.new(attrs: Attr::BOLD),
        Style.new(fg: Color.new(255_u8, 0_u8, 0_u8)),
        Style.new(bg: Color.new(0_u8, 255_u8, 0_u8)),
        Style.new(attrs: Attr::BOLD, fg: Color.new(0_u8, 0_u8, 255_u8)),
      ]

      styles.each_with_index do |style, idx|
        cellbuf.set_cell(idx, 0, Cell.new("X", 1, style))
      end

      renderer.render(cellbuf)
      renderer.flush

      buf.to_s.includes?("\e[").should be_true
    end

    it "renders hyperlinks" do
      buf = IO::Memory.new
      renderer = TerminalRenderer.new(buf, ["TERM=xterm-256color"])
      cellbuf = RenderBuffer.new(10, 1)

      link = Ultraviolet.new_link("https://example.com")
      cellbuf.set_cell(0, 0, Cell.new("link", 4, Style.new, link))

      renderer.render(cellbuf)
      renderer.flush

      buf.to_s.includes?("link").should be_true
    end

    it "switches buffers with correct inline scroll behavior" do
      buf = IO::Memory.new
      renderer = TerminalRenderer.new(buf, ["TERM=xterm-256color"])

      cellbuf = RenderBuffer.new(5, 3)
      cell = Cell.new("X", 1)
      cellbuf.set_cell(0, 0, cell)

      renderer.render(cellbuf)
      renderer.flush

      large = RenderBuffer.new(10, 6)
      large.set_cell(0, 1, cell)

      renderer.render(large)
      renderer.flush

      buf.to_s.should eq("\e[HX\r\n\n\e[J\e[H\e[K\nX\e[K\r\n\e[K\n\n\n")
    end

    it "handles relative cursor" do
      buf = IO::Memory.new
      renderer = TerminalRenderer.new(buf, ["TERM=xterm-256color"])
      renderer.relative_cursor = true

      cellbuf = RenderBuffer.new(10, 3)
      cellbuf.set_cell(5, 1, Cell.new("X", 1))

      renderer.render(cellbuf)
      renderer.flush

      buf.to_s.includes?("X").should be_true

      renderer.relative_cursor = false
      buf.clear
      renderer.render(cellbuf)
      renderer.flush
    end

    it "supports logger" do
      buf = IO::Memory.new
      logger = TestLogger.new
      renderer = TerminalRenderer.new(buf, ["TERM=xterm-256color"])
      renderer.logger = logger

      cellbuf = RenderBuffer.new(3, 1)
      cellbuf.set_cell(0, 0, Cell.new("X", 1))

      renderer.render(cellbuf)
      renderer.flush

      logger.buf.size.should be > 0

      renderer.logger = nil
      logger.buf.clear
      renderer.render(cellbuf)
      renderer.flush
      logger.buf.size.should eq(0)
    end

    it "handles scroll optimization" do
      buf = IO::Memory.new
      renderer = TerminalRenderer.new(buf, ["TERM=xterm-256color"])
      renderer.fullscreen = true

      cellbuf = RenderBuffer.new(10, 5)
      5.times do |y|
        10.times do |x|
          cellbuf.set_cell(x, y, Cell.new((('A'.ord + y)).chr.to_s, 1))
        end
      end

      renderer.render(cellbuf)
      renderer.flush
      buf.clear

      newbuf = RenderBuffer.new(10, 5)
      4.times do |y|
        10.times do |x|
          newbuf.set_cell(x, y, Cell.new((('A'.ord + y + 1)).chr.to_s, 1))
        end
      end
      10.times do |x|
        newbuf.set_cell(x, 4, Cell.new("F", 1))
      end

      renderer.render(newbuf)
      renderer.flush

      buf.to_s.includes?("F").should be_true
    end

    it "handles multiple prepends" do
      buf = IO::Memory.new
      renderer = TerminalRenderer.new(buf, ["TERM=xterm-256color"])

      renderer.resize(20, 10)
      cellbuf = RenderBuffer.new(20, 10)

      renderer.prepend_string(cellbuf, "First line")
      renderer.prepend_string(cellbuf, "Second line")

      line1 = Line.new(10)
      line2 = Line.new(10)
      "Third line".each_char_with_index do |char, index|
        line1.set(index, Cell.new(char.to_s, 1)) if index < line1.width
      end
      "Fourth lin".each_char_with_index do |char, index|
        line2.set(index, Cell.new(char.to_s, 1)) if index < line2.width
      end

      renderer.prepend_string(cellbuf, "#{line1.render}\n#{line2.render}")
      renderer.render(cellbuf)
      renderer.flush

      output = buf.to_s
      ["First line", "Second line", "Third line", "Fourth lin"].each do |value|
        output.includes?(value).should be_true
      end
    end

    it "handles edge cases" do
      buf = IO::Memory.new
      renderer = TerminalRenderer.new(buf, ["TERM=xterm-256color"])

      empty = RenderBuffer.new(0, 0)
      renderer.render(empty)
      renderer.flush

      cellbuf = RenderBuffer.new(3, 3)
      cellbuf.set_cell(1, 1, nil)
      renderer.render(cellbuf)
      renderer.flush

      large = RenderBuffer.new(1000, 1000)
      large.set_cell(999, 999, Cell.new("X", 1))
      renderer.render(large)
      renderer.flush
    end

    it "handles terminal optimizations" do
      alacritty = TerminalRenderer.new(IO::Memory.new, ["TERM=alacritty"])
      alacritty.caps.includes?(Capabilities::CHT).should be_false

      screen = TerminalRenderer.new(IO::Memory.new, ["TERM=screen"])
      screen.caps.includes?(Capabilities::REP).should be_false

      tmux = TerminalRenderer.new(IO::Memory.new, ["TERM=tmux"])
      tmux.caps.includes?(Capabilities::VPA).should be_true
    end

    it "handles cursor movement optimizations" do
      buf = IO::Memory.new
      renderer = TerminalRenderer.new(buf, ["TERM=xterm-256color"])
      renderer.tab_stops = 8

      cellbuf = RenderBuffer.new(20, 1)
      cellbuf.set_cell(8, 0, Cell.new("X", 1))
      cellbuf.set_cell(16, 0, Cell.new("X", 1))

      renderer.render(cellbuf)
      renderer.flush
      buf.to_s.includes?("X").should be_true
    end

    it "handles backspace optimization" do
      buf = IO::Memory.new
      renderer = TerminalRenderer.new(buf, ["TERM=xterm-256color"])
      renderer.backspace = true

      cellbuf = RenderBuffer.new(10, 1)
      cellbuf.set_cell(5, 0, Cell.new("X", 1))

      renderer.move_to(8, 0)
      renderer.move_to(3, 0)

      renderer.render(cellbuf)
      renderer.flush
      buf.to_s.includes?("X").should be_true
    end

    it "handles newline mapping" do
      buf = IO::Memory.new
      renderer = TerminalRenderer.new(buf, ["TERM=xterm-256color"])
      renderer.map_newline = true
      renderer.relative_cursor = true

      cellbuf = RenderBuffer.new(10, 3)
      cell = Cell.new("X", 1)
      cellbuf.set_cell(0, 0, cell)
      cellbuf.set_cell(0, 1, cell)
      cellbuf.set_cell(0, 2, cell)

      renderer.render(cellbuf)
      renderer.flush

      buf.to_s.includes?("X").should be_true
    end

    it "handles underline styles" do
      buf = IO::Memory.new
      renderer = TerminalRenderer.new(buf, ["TERM=xterm-256color"])

      cellbuf = RenderBuffer.new(10, 1)
      styles = [
        Style.new(underline: Underline::Single),
        Style.new(underline: Underline::Double),
        Style.new(underline: Underline::Curly),
        Style.new(underline: Underline::Dotted),
        Style.new(underline: Underline::Dashed),
      ]

      styles.each_with_index do |style, idx|
        cellbuf.set_cell(idx, 0, Cell.new("U", 1, style)) if idx < cellbuf.width
      end

      renderer.render(cellbuf)
      renderer.flush
      buf.to_s.includes?("U").should be_true
    end

    it "handles text attributes" do
      buf = IO::Memory.new
      renderer = TerminalRenderer.new(buf, ["TERM=xterm-256color"])

      cellbuf = RenderBuffer.new(10, 1)
      styles = [
        Style.new(attrs: Attr::ITALIC),
        Style.new(attrs: Attr::FAINT),
        Style.new(attrs: Attr::BLINK),
        Style.new(attrs: Attr::REVERSE),
        Style.new(attrs: Attr::STRIKETHROUGH),
      ]

      styles.each_with_index do |style, idx|
        cellbuf.set_cell(idx, 0, Cell.new("A", 1, style)) if idx < cellbuf.width
      end

      renderer.render(cellbuf)
      renderer.flush
      buf.to_s.includes?("A").should be_true
    end

    it "handles color downsampling" do
      profiles = [ColorProfile::TrueColor, ColorProfile::ANSI256, ColorProfile::ANSI, ColorProfile::Ascii]

      profiles.each do |profile|
        buf = IO::Memory.new
        renderer = TerminalRenderer.new(buf, ["TERM=xterm-256color"])
        renderer.color_profile = profile

        cellbuf = RenderBuffer.new(3, 1)
        cellbuf.set_cell(0, 0, Cell.new("C", 1, Style.new(fg: Color.new(123_u8, 234_u8, 45_u8))))

        renderer.render(cellbuf)
        renderer.flush
        buf.to_s.includes?("C").should be_true
      end
    end

    it "handles phantom cursor" do
      buf = IO::Memory.new
      renderer = TerminalRenderer.new(buf, ["TERM=xterm-256color"])
      renderer.color_profile = ColorProfile::TrueColor
      renderer.fullscreen = true
      renderer.relative_cursor = false

      cellbuf = RenderBuffer.new(5, 3)
      cell = Cell.new("X", 1)
      3.times do |y|
        cellbuf.set_cell(4, y, cell)
      end

      renderer.render(cellbuf)
      renderer.flush

      buf.to_s.should eq("\e[1;5HX\r\n\e[5GX\r\n\e[5G\e[?7lX\e[?7h")
    end

    it "handles line clearing optimizations" do
      buf = IO::Memory.new
      renderer = TerminalRenderer.new(buf, ["TERM=xterm-256color"])

      cellbuf = RenderBuffer.new(10, 3)
      cell = Cell.new("X", 1)
      10.times do |x|
        cellbuf.set_cell(x, 0, cell)
      end

      renderer.render(cellbuf)
      renderer.flush
      buf.clear

      newbuf = RenderBuffer.new(10, 3)
      newbuf.set_cell(0, 0, cell)

      renderer.render(newbuf)
      renderer.flush
      buf.to_s.includes?("X").should be_true
    end

    it "handles repeat character optimization" do
      buf = IO::Memory.new
      renderer = TerminalRenderer.new(buf, ["TERM=xterm-256color"])
      cellbuf = RenderBuffer.new(20, 1)

      cell = Cell.new("A", 1)
      15.times do |x|
        cellbuf.set_cell(x, 0, cell)
      end

      renderer.render(cellbuf)
      renderer.flush
      buf.to_s.includes?("A").should be_true
    end

    it "handles erase character optimization" do
      buf = IO::Memory.new
      renderer = TerminalRenderer.new(buf, ["TERM=xterm-256color"])
      cellbuf = RenderBuffer.new(20, 1)

      cellbuf.set_cell(0, 0, Cell.new("A", 1))
      space = Cell.new(" ", 1)
      (5...15).each do |x|
        cellbuf.set_cell(x, 0, space)
      end

      renderer.render(cellbuf)
      renderer.flush
      buf.to_s.includes?("A").should be_true
    end

    it "handles updates" do
      cases = [
        {
          "simple style change",
          ["A", "\e[1mA"],
          ["\rA\r\n\n", "\e[2A\e[1mA\e[m"],
        },
        {
          "style and link change",
          ["A", "\e[31m\e]8;;https://example.com\e\\A\e]8;;\e\\"],
          ["\rA\r\n\n", "\e[2A\e[31m\e]8;;https://example.com\aA\e[m\e]8;;\a"],
        },
        {
          "the same true color style frames",
          [
            " \e[38;2;255;128;0mABC\n DEF",
            " \e[38;2;255;128;0mABC\n DEF",
            " \e[38;2;255;128;0mABC\n DEF",
          ],
          [
            "\r \e[38;5;208mABC\e[m\r\n\e[38;5;208m DEF\e[m\r\n",
            "",
            "",
          ],
        },
      ]

      cases.each do |entry|
        _name, frames, expected = entry
        buf = IO::Memory.new
        renderer = TerminalRenderer.new(buf, ["TERM=xterm-256color", "TTY_FORCE=1"])
        renderer.relative_cursor = true

        scr = ScreenBuffer.new(5, 3)
        frames.each_with_index do |frame, idx|
          StyledString.new(frame).draw(scr, scr.bounds)
          renderer.render(scr)
          renderer.flush
          buf.to_s.should eq(expected[idx])
          buf.clear
        end
      end
    end

    it "prepends one line" do
      buf = IO::Memory.new
      renderer = TerminalRenderer.new(buf, ["TERM=xterm-256color"])

      renderer.resize(10, 5)
      cellbuf = ScreenBuffer.new(10, 5)
      StyledString.new("This-is-a .").draw(cellbuf, cellbuf.bounds)
      renderer.render(cellbuf)
      renderer.flush

      StyledString.new("This-is-a .").draw(cellbuf, cellbuf.bounds)
      renderer.prepend_string(cellbuf, "Prepended-a-new-line")
      renderer.render(cellbuf)
      renderer.flush

      buf.to_s.should eq("\e[HThis-is-a\r\n\n\n\n\n\n\e[H\e[2LPrepended-a-new-line\r\n")
    end

    it "enters and exits alt screen" do
      buf = IO::Memory.new
      renderer = TerminalRenderer.new(buf, ["TERM=xterm-256color"])
      cellbuf = RenderBuffer.new(3, 3)

      renderer.move_to(1, 1)
      renderer.cur.x.should eq(1)
      renderer.cur.y.should eq(1)

      renderer.enter_alt_screen
      renderer.render(cellbuf)
      renderer.fullscreen?.should be_true
      renderer.cur.x.should eq(0)
      renderer.cur.y.should eq(0)

      renderer.exit_alt_screen
      renderer.flags.includes?(TerminalFlags::RelativeCursor).should be_true
      renderer.cur.x.should eq(1)
      renderer.cur.y.should eq(1)

      renderer.flush
      buf.to_s.should eq("\e[2;2H\e[?1049h\e[H\e[2J\e[?1049l")
    end
  end
end
