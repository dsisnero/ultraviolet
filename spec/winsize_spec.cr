require "./spec_helper"

{% unless flag?(:win32) %}
  describe "winsize ioctl" do
    # ioctl is variadic in C, so its pointer argument has to be passed as one.
    # With a fixed-arity declaration the kernel writes the winsize to the
    # address it finds in the variadic slot, which on AArch64 is stack garbage,
    # and the caller reads back uninitialized memory.
    it "reads the size the pty was created with" do
      master, slave = pty_pair(40, 100)
      notifier = Ultraviolet::SizeNotifier.new(slave)

      begin
        cells, _pixels = notifier.window_size
        {cells.width, cells.height}.should eq({100, 40})
      ensure
        master.close
        slave.close
      end
    end

    it "reports the size through a started terminal" do
      master, slave = pty_pair(24, 80)
      term = Ultraviolet::Terminal.new(slave, slave, ["TERM=xterm-256color"])

      begin
        term.start
        term.get_size.should eq({80, 24})
      ensure
        term.stop
        master.close
        slave.close
      end
    end
  end
{% end %}
