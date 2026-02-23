module Ultraviolet
  enum ProgressBarState
    None
    Default
    Error
    Indeterminate
    Warning

    def to_s(io : IO) : Nil
      io << case self
      in .none?          then "None"
      in .default?       then "Default"
      in .error?         then "Error"
      in .indeterminate? then "Indeterminate"
      in .warning?       then "Warning"
      end
    end
  end

  struct ProgressBar
    property state : ProgressBarState
    property value : Int32

    def initialize(@state : ProgressBarState, @value : Int32)
      @value = @value.clamp(0, 100)
    end
  end

  def self.new_progress_bar(state : ProgressBarState, value : Int32) : ProgressBar
    ProgressBar.new(state, value)
  end
end
