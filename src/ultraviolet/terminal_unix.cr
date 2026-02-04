{% unless flag?(:win32) %}
  module Ultraviolet
    class Terminal
      private def make_raw : Nil
        raise ErrNotTerminal if @in_tty.nil? && @out_tty.nil?

        last_error = nil
        {@in_tty, @out_tty}.each do |tty|
          next unless tty

          state = TtyState.new
          if LibC.tcgetattr(tty.fd, pointerof(state)) != 0
            last_error = Errno.new("tcgetattr")
            next
          end

          raw_state = state
          LibC.cfmakeraw(pointerof(raw_state))
          if LibC.tcsetattr(tty.fd, LibC::TCSANOW, pointerof(raw_state)) != 0
            last_error = Errno.new("tcsetattr")
            next
          end

          if tty == @in_tty
            @in_tty_state = state
          else
            @out_tty_state = state
          end
          return
        end

        raise last_error if last_error
        raise ErrNotTerminal
      end

      private def restore_tty : Nil
        last_error = nil
        if tty = @in_tty
          if state = @in_tty_state
            if LibC.tcsetattr(tty.fd, LibC::TCSANOW, pointerof(state)) != 0
              last_error = Errno.new("tcsetattr")
            end
          end
        end

        if tty = @out_tty
          if state = @out_tty_state
            if LibC.tcsetattr(tty.fd, LibC::TCSANOW, pointerof(state)) != 0
              last_error = Errno.new("tcsetattr")
            end
          end
        end

        raise last_error if last_error
      end
    end
  end
{% end %}
