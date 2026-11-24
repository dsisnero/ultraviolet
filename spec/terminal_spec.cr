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

# Go's `Terminal` is a thin facade over a `TerminalScreen` (`t.scr`), and this
# port's is too: the screen owns the screen state, so stopping can undo what the
# application enabled without `Terminal` keeping a second copy of it.
describe "Terminal screen" do
  it "exposes the screen and delegates the drawing surface to it" do
    output = IO::Memory.new
    term = Ultraviolet::Terminal.new(IO::Memory.new, output, ["TERM=xterm-256color"])

    term.screen.should be_a(Ultraviolet::TerminalScreen)
    term.resize(4, 2)
    term.set_cell(1, 1, Ultraviolet::Cell.new("X", 1))

    term.cell_at(1, 1).try(&.string).should eq("X")
    term.screen.cell_at(1, 1).try(&.string).should eq("X")
    term.bounds.should eq(Ultraviolet.rect(0, 0, 4, 2))
    term.width.should eq(4)
    term.height.should eq(2)
  end

  it "queues state as it is set and writes it on flush, as Go does" do
    output = IO::Memory.new
    term = Ultraviolet::Terminal.new(IO::Memory.new, output, ["TERM=xterm-256color"])

    term.enter_alt_screen
    term.set_mouse_mode(Ultraviolet::MouseMode::Motion)
    term.set_mouse_encoding(Ultraviolet::MouseEncoding::SGRPixel)
    term.enable_bracketed_paste
    term.hide_cursor

    # Go's setters write into the screen's buffer; nothing reaches the terminal
    # until Flush drains it.
    output.to_s.should be_empty
    term.screen.alt_screen?.should be_true
    term.screen.mouse_mode.should eq(Ultraviolet::MouseMode::Motion)
    term.screen.mouse_encoding.should eq(Ultraviolet::MouseEncoding::SGRPixel)
    term.screen.bracketed_paste?.should be_true
    term.screen.cursor_visible?.should be_false

    term.flush
    written = output.to_s
    written.should contain("\e[?1049h")
    written.should contain("\e[?1003h")
    written.should contain("\e[?1016h")
    written.should contain("\e[?2004h")
    written.should contain("\e[?25l")
  end

  it "starts on wcwidth measurement, like Go" do
    output = IO::Memory.new
    term = Ultraviolet::Terminal.new(IO::Memory.new, output, ["TERM=xterm-256color"])

    conjunct = "स्ते"
    term.width_method.call(conjunct).should eq(2)
    term.screen.width_method.call(conjunct).should eq(2)
  end

  it "switches the alternate screen through the screen" do
    output = IO::Memory.new
    term = Ultraviolet::Terminal.new(IO::Memory.new, output, ["TERM=xterm-256color"])

    term.enter_alt_screen
    term.exit_alt_screen
    term.screen.alt_screen?.should be_false
    term.flush

    written = output.to_s
    written.should contain("\e[?1049h")
    written.should contain("\e[?1049l")
  end
end

describe "Terminal display" do
  # `display` was defined twice and the later, shorter definition won, dropping
  # the alt-screen, cursor, and prepend handling. A display that ignored the
  # screen state wrote nothing at all.
  it "applies the terminal state it was given" do
    output = IO::Memory.new
    term = Ultraviolet::Terminal.new(IO::Memory.new, output, ["TERM=xterm-256color"])

    term.hide_cursor
    term.display
    output.to_s.should contain("\e[?25l")

    # The state is recorded, so a second display has nothing to change.
    output.clear
    term.display
    output.to_s.should_not contain("\e[?25l")
  end
end

{% unless flag?(:win32) %}
  # Terminal#start needs a tty, so these drive a pseudo terminal: the master
  # end is what a user's typing looks like to the process.
  describe "Terminal input" do
    it "delivers input through the poll reader" do
      master, slave = pty_pair
      term = Ultraviolet::Terminal.new(slave, slave, ["TERM=xterm-256color"])

      begin
        term.start
        term.running?.should be_true

        master.write("a".to_slice)
        master.flush

        key = read_key(term, 5.seconds)
        key.should_not be_nil
        key.as(Ultraviolet::Key).text.should eq("a")
      ensure
        term.stop
        master.close
        slave.close
      end

      term.running?.should be_false
    end

    # Go's Terminal.Start asks whether the terminal measures width by grapheme
    # cluster (DECRQM for mode 2027) and its event loop switches to grapheme
    # width when the reply says the mode is settable or set. Nothing called the
    # port's request/enable helpers before this, so the negotiation never
    # happened and `width_method` stayed on wcwidth measurement.
    it "negotiates grapheme width when the terminal supports mode 2027" do
      master, slave = pty_pair(24, 80)
      term = Ultraviolet::Terminal.new(slave, slave, ["TERM=xterm-256color"])
      # A Devanagari conjunct: uniwidth measures 2 columns, grapheme clustering 1.
      sample = "स्ते"

      begin
        term.start
        drain_events(term)
        term.width_method.call(sample).should eq(2)

        term.send_event(Ultraviolet::ModeReportEvent.new(mode: 2027, value: Ansi::ModeSet.value.to_i32))
        term.events.receive # forwarded only after the negotiation ran

        term.width_method.call(sample).should eq(Ansi.string_width(sample))
        term.width_method.call(sample).should eq(1)
        captured_output(master).should contain("\e[?2027h")
      ensure
        term.stop
        master.close
        slave.close
      end
    end

    it "keeps wcwidth when the terminal does not recognize mode 2027" do
      master, slave = pty_pair(24, 80)
      term = Ultraviolet::Terminal.new(slave, slave, ["TERM=xterm-256color"])
      sample = "स्ते"

      begin
        term.start
        drain_events(term)
        before = term.width_method.call(sample)
        before.should eq(2)

        # ModeNotRecognized: the terminal cannot honor the mode.
        term.send_event(Ultraviolet::ModeReportEvent.new(mode: 2027, value: 0))
        term.events.receive

        term.width_method.call(sample).should eq(before)
        captured_output(master).should_not contain("\e[?2027h")
      ensure
        term.stop
        master.close
        slave.close
      end
    end

    # Port of grapheme_width_test.go: TestGraphemeWidthGating. Only settable or
    # active states switch to grapheme measurement; a terminal that does not
    # recognize the mode (or has it permanently reset) stays on wcwidth.
    it "gates grapheme width on the mode 2027 report" do
      warning_sign = "\u26A0\uFE0F"
      cases = {
        Ansi::ModeSet.value.to_i32              => 2,
        Ansi::ModeReset.value.to_i32            => 2,
        Ansi::ModePermanentlySet.value.to_i32   => 2,
        Ansi::ModeNotRecognized.value.to_i32    => 1,
        Ansi::ModePermanentlyReset.value.to_i32 => 1,
      }

      cases.each do |mode_value, expected|
        master, slave = pty_pair(24, 80)
        term = Ultraviolet::Terminal.new(slave, slave, ["TERM=xterm-256color"])
        begin
          term.start
          drain_events(term)
          term.width_method.call(warning_sign).should eq(1)

          term.send_event(Ultraviolet::ModeReportEvent.new(mode: 2027, value: mode_value))
          term.events.receive

          term.width_method.call(warning_sign).should eq(expected), "mode value #{mode_value}"
        ensure
          term.stop
          master.close
          slave.close
        end
      end
    end

    # Port of TestGraphemeWidthGatingPreservesOverride: a late mode-2027 report
    # must not clobber a width method the application set explicitly.
    it "keeps an explicit width method when the mode 2027 report arrives" do
      warning_sign = "\u26A0\uFE0F"
      master, slave = pty_pair(24, 80)
      term = Ultraviolet::Terminal.new(slave, slave, ["TERM=xterm-256color"])

      begin
        term.start
        drain_events(term)
        term.width_method = Ultraviolet::DEFAULT_WIDTH_METHOD

        term.send_event(Ultraviolet::ModeReportEvent.new(mode: 2027, value: Ansi::ModeSet.value.to_i32))
        term.events.receive

        term.width_method.call(warning_sign).should eq(1)
        captured_output(master).should_not contain("\e[?2027h")
      ensure
        term.stop
        master.close
        slave.close
      end
    end

    # Upstream's TestStopWithInputInFlightDoesNotPanic: Stop used to clear the
    # reader while the input loop could still evaluate it.
    it "stops while input is in flight" do
      5.times do
        master, slave = pty_pair
        term = Ultraviolet::Terminal.new(slave, slave, ["TERM=xterm-256color"])
        begin
          term.start
          master.write("x".to_slice)
          master.flush
          term.stop
        ensure
          master.close
          slave.close
        end
        term.running?.should be_false
      end
    end

    # A second start after a stop must get a fresh poll reader: the first one
    # is canceled and closed, and a canceled reader rejects every read.
    it "restarts input after stop" do
      master, slave = pty_pair
      term = Ultraviolet::Terminal.new(slave, slave, ["TERM=xterm-256color"])

      begin
        2.times do |round|
          term.start
          master.write("b".to_slice)
          master.flush

          key = read_key(term, 5.seconds)
          key.should_not be_nil, "round #{round}: expected input after start"
          term.stop
        end
      ensure
        term.stop
        master.close
        slave.close
      end
    end

    # Go's Stop goes through TerminalScreen.Reset, so every mode the screen
    # tracked is undone without the application resetting it by hand — that is
    # why examples/mouse no longer emits its own reset.
    it "resets the screen state the application enabled on stop" do
      master, slave = pty_pair
      term = Ultraviolet::Terminal.new(slave, slave, ["TERM=xterm-256color"])

      begin
        term.start
        term.enter_alt_screen
        term.set_mouse_mode(Ultraviolet::MouseMode::Motion)
        term.set_mouse_encoding(Ultraviolet::MouseEncoding::SGRPixel)
        term.enable_bracketed_paste
        term.hide_cursor
        term.flush

        enabled = captured_output(master)
        enabled.should contain("\e[?1049h")
        enabled.should contain("\e[?1003h")
        enabled.should contain("\e[?1016h")
        enabled.should contain("\e[?2004h")

        term.stop
        reset = captured_output(master)
        reset.should contain("\e[?1049l") # alternate screen off
        reset.should contain("\e[?1003l") # any-event tracking off
        reset.should contain("\e[?1016l") # SGR-pixel encoding off
        reset.should contain("\e[?2004l") # bracketed paste off
        reset.should contain("\e[?25h")   # cursor shown again
      ensure
        term.stop
        master.close
        slave.close
      end
    end
  end

  # drain_events discards whatever the terminal has already queued. Start queues
  # the initial WindowSizeEvent, and SendEvent blocks while the event loop is
  # still forwarding it (Go's evc is unbuffered too), so drain before injecting.
  private def drain_events(term : Ultraviolet::Terminal, budget : Time::Span = 300.milliseconds) : Nil
    deadline = Time.instant + budget
    loop do
      remaining = deadline - Time.instant
      break if remaining <= Time::Span.zero

      select
      when term.events.receive
        # discard
      when timeout(remaining)
        break
      end
    end
  end

  # captured_output drains whatever the terminal wrote to the pty so far.
  private def captured_output(master : IO::FileDescriptor) : String
    buffer = IO::Memory.new
    master.read_timeout = 300.milliseconds
    begin
      loop do
        chunk = Bytes.new(1024)
        read = master.read(chunk)
        break if read == 0
        buffer.write(chunk[0, read])
        master.read_timeout = 100.milliseconds
      end
    rescue IO::TimeoutError
    end
    buffer.to_s
  end

  # read_key waits for the next key event, skipping the window-size events a
  # start reports on its own.
  private def read_key(term : Ultraviolet::Terminal, budget : Time::Span) : Ultraviolet::Key?
    deadline = Time.instant + budget
    loop do
      remaining = deadline - Time.instant
      return nil if remaining <= Time::Span.zero

      select
      when event = term.events.receive
        key = key_in(event)
        return key if key
      when timeout(remaining)
        return nil
      end
    end
  end

  private def key_in(event : Ultraviolet::Event) : Ultraviolet::Key?
    event.is_a?(Array) ? event.find(&.is_a?(Ultraviolet::Key)).as?(Ultraviolet::Key) : event.as?(Ultraviolet::Key)
  end
{% end %}

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
