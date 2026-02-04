module Ultraviolet
  module ScreenClear
    abstract def clear : Nil
  end

  module ScreenClearArea
    abstract def clear_area(area : Rectangle) : Nil
  end

  module ScreenFill
    abstract def fill(cell : Cell?) : Nil
  end

  module ScreenFillArea
    abstract def fill_area(cell : Cell?, area : Rectangle) : Nil
  end

  module ScreenClone
    abstract def clone : Buffer
  end

  module ScreenCloneArea
    abstract def clone_area(area : Rectangle) : Buffer?
  end

  class Buffer
    include ScreenClear
    include ScreenClearArea
    include ScreenFill
    include ScreenFillArea
    include ScreenClone
    include ScreenCloneArea
  end

  module Screen
    def self.clear(screen : Screen) : Nil
      if screen.is_a?(ScreenClear)
        screen.clear
      else
        fill(screen, nil)
      end
    end

    def self.clear_area(screen : Screen, area : Rectangle) : Nil
      if screen.is_a?(ScreenClearArea)
        screen.clear_area(area)
      else
        fill_area(screen, nil, area)
      end
    end

    def self.fill(screen : Screen, cell : Cell?) : Nil
      if screen.is_a?(ScreenFill)
        screen.fill(cell)
      else
        fill_area(screen, cell, screen.bounds)
      end
    end

    def self.fill_area(screen : Screen, cell : Cell?, area : Rectangle) : Nil
      if screen.is_a?(ScreenFillArea)
        screen.fill_area(cell, area)
        return
      end

      y = area.min.y
      while y < area.max.y
        x = area.min.x
        while x < area.max.x
          screen.set_cell(x, y, cell)
          x += 1
        end
        y += 1
      end
    end

    def self.clone_area(screen : Screen, area : Rectangle) : Buffer?
      if screen.is_a?(ScreenCloneArea)
        return screen.clone_area(area)
      end

      buffer = Buffer.new(area.dx, area.dy)
      y = area.min.y
      while y < area.max.y
        x = area.min.x
        while x < area.max.x
          cell = screen.cell_at(x, y)
          buffer.set_cell(x - area.min.x, y - area.min.y, cell.clone) if cell && !cell.zero?
          x += 1
        end
        y += 1
      end
      buffer
    end

    def self.clone(screen : Screen) : Buffer
      if screen.is_a?(ScreenClone)
        screen.clone
      else
        clone_area(screen, screen.bounds) || Buffer.new(0, 0)
      end
    end
  end
end
