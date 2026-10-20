require "./spec_helper"

{% unless flag?(:win32) %}
  describe "Ultraviolet.notify_winch" do
    it "forwards SIGWINCH to a buffered channel" do
      channel = Channel(Nil).new(1)
      Ultraviolet.notify_winch(channel)

      begin
        Process.signal(Signal::WINCH, Process.pid)

        select
        when channel.receive
          # expected
        when timeout(1.second)
          fail "SIGWINCH was not forwarded"
        end
      ensure
        Signal::WINCH.reset
      end
    end
  end
{% end %}

{% unless flag?(:win32) %}
  describe "Ultraviolet.notify_winch_context" do
    it "forwards SIGWINCH until the stop channel is signalled" do
      channel = Channel(Nil).new(1)
      stop = Channel(Nil).new(1)
      Ultraviolet.notify_winch_context(channel, stop)

      begin
        Process.signal(Signal::WINCH, Process.pid)

        select
        when channel.receive
          # expected
        when timeout(1.second)
          fail "SIGWINCH was not forwarded"
        end
      ensure
        stop.close
        Signal::WINCH.reset
      end
    end
  end
{% end %}
