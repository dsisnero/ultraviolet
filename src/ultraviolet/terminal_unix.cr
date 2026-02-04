{% unless flag?(:win32) %}
  module Ultraviolet
    class Terminal
      private def optimize_movements : Nil
        state = @in_tty_state || @out_tty_state
        unless state
          {@in_tty, @out_tty}.each do |tty|
            next unless tty
            candidate = TtyState.new
            if LibC.tcgetattr(tty.fd, pointerof(candidate)) == 0
              state = candidate
              break
            end
          end
        end
        return unless state

        @use_tabs = Ultraviolet.supports_hard_tabs(state.c_oflag.to_u64)
        @use_bspace = Ultraviolet.supports_backspace(state.c_lflag.to_u64)
      end

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

      private def platform_size : {Int32, Int32}
        tty = @in_tty || @out_tty
        raise ErrNotTerminal unless tty

        winsize = uninitialized LibC::Winsize
        if LibC.ioctl(tty.fd, TIOCGWINSZ, pointerof(winsize).as(Void*)) != 0
          raise Errno.new("ioctl")
        end

        {winsize.ws_col.to_i, winsize.ws_row.to_i}
      end
    end

    def self.supports_hard_tabs(oflag : UInt64) : Bool
      (oflag & LibC::TABDLY.to_u64) == LibC::TAB0.to_u64
    end

    def self.supports_backspace(lflag : UInt64) : Bool
      (lflag & LibC::BSDLY.to_u64) == LibC::BS0.to_u64
    end
  end
{% end %}
