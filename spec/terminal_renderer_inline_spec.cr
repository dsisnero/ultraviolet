require "./spec_helper"

module Ultraviolet
  # Inline ("relative cursor") cursor movement, checked against the vendored Go
  # renderer.
  #
  # The golden is written by `make inline-golden` from
  # scripts/inline_oracle/main.go, which drives vendor/ultraviolet through the
  # same moves and records the bytes it writes. Each row is
  # `name <TAB> mode <TAB> moves <TAB> steps`, where moves are `x,y` pairs
  # separated by `;` and steps are the output of each move separated by `|`.
  #
  # The rule these cases pin: an inline downward move must be made with
  # newlines, not a cursor-down sequence, because only a newline scrolls the
  # screen to make room. How far the renderer has already scrolled must not
  # change that; a remembered scroll height used to, and it silently switched
  # long jumps to `CSI n B`.
  describe "TerminalRenderer inline cursor movement" do
    it "matches the Go golden" do
      path = File.join(__DIR__, "fixtures", "inline_moves_golden.tsv")
      File.read_lines(path).each do |line|
        next if line.blank?

        name, mode, scenario, want_steps = line.split('\t')
        want_steps = want_steps.split('|').map { |step| unescape(step) }

        buf = IO::Memory.new
        renderer = TerminalRenderer.new(buf, ["TERM=xterm-256color"])

        if mode == "render"
          # Frames of text, one cell per rune, wrapped at the buffer width like
          # the oracle's fill.
          scenarios = scenario.split('|')
          scenarios.each_with_index do |text, index|
            frame = RenderBuffer.new(70, 2)
            x = 0
            y = 0
            text.each_char do |char|
              frame.set_cell(x, y, Cell.new(char.to_s, 1))
              x += 1
              if x >= frame.width
                x = 0
                y += 1
              end
            end
            renderer.relative_cursor = true
            buf.clear
            renderer.render(frame)
            renderer.flush
            buf.to_s.should eq(want_steps[index]), "#{name} (frame #{index + 1})"
          end
          next
        end

        renderer.fullscreen = (mode == "fullscreen")
        renderer.relative_cursor = (mode == "inline")
        renderer.set_position(0, 0)

        moves = scenario.split(';').map { |pair| pair.split(',').map(&.to_i32) }
        want_steps.each_with_index do |want, index|
          x, y = moves[index]
          buf.clear
          renderer.move_to(x, y)
          renderer.flush
          buf.to_s.should eq(want), "#{name} (step #{index + 1})"
        end
      end
    end
  end

  # unescape turns the golden's `\xNN` escapes back into bytes.
  private def self.unescape(value : String) : String
    String.build do |sb|
      index = 0
      while index < value.size
        if value[index] == '\\' && value[index + 1]? == 'x'
          sb.write_byte(value[index + 2, 2].to_u8(16))
          index += 4
        else
          sb << value[index]
          index += 1
        end
      end
    end
  end
end
