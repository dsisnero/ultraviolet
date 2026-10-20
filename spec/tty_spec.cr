require "./spec_helper"

{% unless flag?(:win32) %}
  describe "Ultraviolet.notify_winch" do
    it "forwards SIGWINCH to a buffered channel" do
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
        sleep 20.milliseconds
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
        sleep 20.milliseconds
      end
    end
  end
{% end %}

{% unless flag?(:win32) %}
  describe "Ultraviolet winch subscriptions" do
    it "keeps other listeners alive when one context stops" do
      first = Channel(Nil).new(1)
      second = Channel(Nil).new(1)
      stop_first = Channel(Nil).new(1)
      stop_second = Channel(Nil).new(1)

      Ultraviolet.notify_winch_context(first, stop_first)
      Ultraviolet.notify_winch_context(second, stop_second)

      begin
        Process.signal(Signal::WINCH, Process.pid)

        select
        when first.receive
        when timeout(1.second)
          fail "first listener did not receive SIGWINCH"
        end

        select
        when second.receive
        when timeout(1.second)
          fail "second listener did not receive SIGWINCH"
        end

        stop_first.close
        sleep 50.milliseconds

        Process.signal(Signal::WINCH, Process.pid)

        select
        when first.receive
          fail "stopped listener received SIGWINCH"
        when timeout(100.milliseconds)
          # expected
        end

        select
        when second.receive
          # expected
        when timeout(1.second)
          fail "remaining listener stopped receiving SIGWINCH"
        end
      ensure
        stop_first.close unless stop_first.closed?
        stop_second.close unless stop_second.closed?
        sleep 20.milliseconds
      end
    end
  end
{% end %}
