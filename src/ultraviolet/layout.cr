module Ultraviolet
  module Layout
    FLOAT_PRECISION_MULTIPLIER = 100.0

    private CACHE_SIZE   = 500
    private GLOBAL_CACHE = Casso::LRU(CacheKey, CacheValue).new(CACHE_SIZE)

    private record CacheKey, area : Rectangle, direction : Direction, constraint_types : String, padding : Padding, spacing : Int32, flex : Flex

    private record CacheValue, segments : Array(Rectangle), spacers : Array(Rectangle)

    enum Direction
      Vertical
      Horizontal
    end

    enum Flex
      Start
      Legacy
      End
      Center
      SpaceBetween
      SpaceEvenly
      SpaceAround
    end

    struct Padding
      getter top : Int32
      getter right : Int32
      getter bottom : Int32
      getter left : Int32

      def initialize(@top : Int32 = 0, @right : Int32 = 0, @bottom : Int32 = 0, @left : Int32 = 0)
      end

      def apply(area : Rectangle) : Rectangle
        horizontal = @right + @left
        vertical = @top + @bottom

        if area.dx < horizontal || area.dy < vertical
          return Rectangle.new(Position.new(0, 0), Position.new(0, 0))
        end

        Ultraviolet.rect(
          area.min.x + @left,
          area.min.y + @top,
          Math.max(0, area.dx - horizontal),
          Math.max(0, area.dy - vertical)
        )
      end
    end

    def self.pad : Padding
      Padding.new
    end

    def self.pad(all : Int32) : Padding
      Padding.new(all, all, all, all)
    end

    def self.pad(vertical : Int32, horizontal : Int32) : Padding
      Padding.new(vertical, horizontal, vertical, horizontal)
    end

    def self.pad(top : Int32, right : Int32, bottom : Int32, left : Int32) : Padding
      Padding.new(top, right, bottom, left)
    end

    module Constraint
    end

    struct Min
      include Constraint
      getter value : Int32

      def initialize(@value : Int32)
      end
    end

    struct Max
      include Constraint
      getter value : Int32

      def initialize(@value : Int32)
      end
    end

    struct Len
      include Constraint
      getter value : Int32

      def initialize(@value : Int32)
      end
    end

    struct Percent
      include Constraint
      getter value : Int32

      def initialize(@value : Int32)
      end
    end

    struct Ratio
      include Constraint
      getter num : Int32
      getter den : Int32

      def initialize(@num : Int32, @den : Int32)
      end
    end

    struct Fill
      include Constraint
      getter value : Int32

      def initialize(@value : Int32)
      end
    end

    private REQUIRED = 1_001_001_000_f64
    private STRONG   =     1_000_000_f64
    private MEDIUM   =         1_000_f64
    private WEAK     =             1_f64

    private SPACER_SIZE_EQ   = REQUIRED / 10.0
    private MIN_SIZE_GTE     = STRONG * 100.0
    private MAX_SIZE_LTE     = STRONG * 100.0
    private LENGTH_SIZE_EQ   = STRONG * 10.0
    private PERCENT_SIZE_EQ  = STRONG
    private RATIO_SIZE_EQ    = STRONG / 10.0
    private MIN_SIZE_EQ      = MEDIUM * 10.0
    private MAX_SIZE_EQ      = MEDIUM * 10.0
    private FILL_GROW        = MEDIUM
    private GROW             = 100.0
    private SPACE_GROW       = WEAK * 10.0
    private ALL_SEGMENT_GROW = WEAK

    private struct Element
      getter start : Casso::Symbol
      getter end : Casso::Symbol

      def initialize(@start : Casso::Symbol, @end : Casso::Symbol)
      end

      def empty : Casso::Constraint
        Casso::Constraint.new(Casso::Op::Eq, 0, [@end.t(1), @start.t(-1)])
      end

      def size_eq_const(size : Int32) : Casso::Constraint
        Casso::Constraint.new(Casso::Op::Eq, -size.to_f64 * FLOAT_PRECISION_MULTIPLIER, [@end.t(1), @start.t(-1)])
      end

      def size_lte(size : Int32) : Casso::Constraint
        Casso::Constraint.new(Casso::Op::Lte, -size.to_f64 * FLOAT_PRECISION_MULTIPLIER, [@end.t(1), @start.t(-1)])
      end

      def size_gte(size : Int32) : Casso::Constraint
        Casso::Constraint.new(Casso::Op::Gte, -size.to_f64 * FLOAT_PRECISION_MULTIPLIER, [@end.t(1), @start.t(-1)])
      end

      def size_eq_size(other : Element) : Casso::Constraint
        Casso::Constraint.new(Casso::Op::Eq, 0, [@end.t(1), @start.t(-1), other.end.t(-1), other.start.t(1)])
      end

      def size_eq_scaled_size(other : Element, f : Float64) : Casso::Constraint
        Casso::Constraint.new(Casso::Op::Eq, 0, [@end.t(1), @start.t(-1), other.end.t(-f), other.start.t(f)])
      end

      def size_eq_double(other : Element) : Casso::Constraint
        Casso::Constraint.new(Casso::Op::Eq, 0, [@end.t(1), @start.t(-1), other.end.t(-2), other.start.t(2)])
      end
    end

    def self.new_elements(variables : Array(Casso::Symbol)) : Array(Element)
      elements = Array(Element).new
      count = variables.size - variables.size % 2
      (0...count).step(2) do |i|
        elements << Element.new(variables[i], variables[i + 1])
      end
      elements
    end

    def self.configure_area(solver : Casso::Solver, area : Element, area_start : Float64, area_end : Float64)
      solver.add(REQUIRED, Casso::Constraint.new(Casso::Op::Eq, -area_start, [area.start.t(1)]))
      solver.add(REQUIRED, Casso::Constraint.new(Casso::Op::Eq, -area_end, [area.end.t(1)]))
    end

    def self.configure_variable_in_area_constraints(solver : Casso::Solver, variables : Array(Casso::Symbol), area : Element)
      variables.each do |v|
        solver.add(REQUIRED, Casso::Constraint.new(Casso::Op::Gte, 0, [v.t(1), area.start.t(-1)]))
        solver.add(REQUIRED, Casso::Constraint.new(Casso::Op::Lte, 0, [v.t(1), area.end.t(-1)]))
      end
    end

    def self.configure_variable_constraints(solver : Casso::Solver, variables : Array(Casso::Symbol))
      vars = variables[1..]
      count = vars.size
      (0...(count - count % 2)).step(2) do |i|
        left = vars[i]
        right = vars[i + 1]
        solver.add(REQUIRED, Casso::Constraint.new(Casso::Op::Lte, 0, [left.t(1), right.t(-1)]))
      end
    end

    # ameba:disable Metrics/CyclomaticComplexity
    def self.configure_flex_constraints(solver : Casso::Solver, area : Element, spacers : Array(Element), flex : Flex, spacing : Int32)
      spacers_except_first_and_last = spacers.size > 2 ? spacers[1..-2] : [] of Element

      case flex
      when Flex::Legacy
        spacers_except_first_and_last.each do |spacer|
          solver.add(SPACER_SIZE_EQ, spacer.size_eq_const(spacing))
        end
        if spacers.size >= 2
          solver.add(REQUIRED - WEAK, spacers[0].empty)
          solver.add(REQUIRED - WEAK, spacers[-1].empty)
        end
      when Flex::SpaceEvenly
        combinations(spacers.size, 2).each do |i, j|
          solver.add(SPACER_SIZE_EQ, spacers[i].size_eq_size(spacers[j]))
        end
        spacers.each do |spacer|
          solver.add(SPACER_SIZE_EQ, spacer.size_gte(spacing))
          solver.add(SPACE_GROW, spacer.size_eq_size(area))
        end
      when Flex::SpaceAround
        if spacers.size <= 2
          combinations(spacers.size, 2).each do |i, j|
            solver.add(SPACER_SIZE_EQ, spacers[i].size_eq_size(spacers[j]))
          end
          spacers.each do |spacer|
            solver.add(SPACER_SIZE_EQ, spacer.size_gte(spacing))
            solver.add(SPACE_GROW, spacer.size_eq_size(area))
          end
        else
          first = spacers[0]
          last = spacers[-1]
          middle = spacers[1..-2]
          combinations(middle.size, 2).each do |i, j|
            solver.add(SPACER_SIZE_EQ, middle[i].size_eq_size(middle[j]))
          end
          unless middle.empty?
            m0 = middle[0]
            solver.add(SPACER_SIZE_EQ, first.size_eq_double(m0))
            solver.add(SPACER_SIZE_EQ, last.size_eq_double(m0))
          end
          spacers.each do |spacer|
            solver.add(SPACER_SIZE_EQ, spacer.size_gte(spacing))
            solver.add(SPACE_GROW, spacer.size_eq_size(area))
          end
        end
      when Flex::SpaceBetween
        combinations(spacers_except_first_and_last.size, 2).each do |i, j|
          solver.add(SPACER_SIZE_EQ, spacers_except_first_and_last[i].size_eq_size(spacers_except_first_and_last[j]))
        end
        spacers_except_first_and_last.each do |spacer|
          solver.add(SPACER_SIZE_EQ, spacer.size_gte(spacing))
          solver.add(SPACE_GROW, spacer.size_eq_size(area))
        end
        if spacers.size >= 2
          solver.add(REQUIRED - WEAK, spacers[0].empty)
          solver.add(REQUIRED - WEAK, spacers[-1].empty)
        end
      when Flex::Start
        spacers_except_first_and_last.each do |spacer|
          solver.add(SPACER_SIZE_EQ, spacer.size_eq_const(spacing))
        end
        if spacers.size >= 2
          solver.add(REQUIRED - WEAK, spacers[0].empty)
          solver.add(GROW, spacers[-1].size_eq_size(area))
        end
      when Flex::Center
        spacers_except_first_and_last.each do |spacer|
          solver.add(SPACER_SIZE_EQ, spacer.size_eq_const(spacing))
        end
        if spacers.size >= 2
          solver.add(GROW, spacers[0].size_eq_size(area))
          solver.add(GROW, spacers[-1].size_eq_size(area))
          solver.add(SPACER_SIZE_EQ, spacers[0].size_eq_size(spacers[-1]))
        end
      when Flex::End
        spacers_except_first_and_last.each do |spacer|
          solver.add(SPACER_SIZE_EQ, spacer.size_eq_const(spacing))
        end
        if spacers.size >= 2
          solver.add(REQUIRED - WEAK, spacers[-1].empty)
          solver.add(GROW, spacers[0].size_eq_size(area))
        end
      end
    end

    def self.configure_constraints(solver : Casso::Solver, area : Element, segments : Array(Element), constraints : Array(Constraint), flex : Flex)
      limit = Math.min(constraints.size, segments.size)
      limit.times do |i|
        constraint = constraints[i]
        segment = segments[i]

        case constraint
        when Max
          size = constraint.value
          solver.add(MAX_SIZE_LTE, segment.size_lte(size))
          solver.add(MAX_SIZE_EQ, segment.size_eq_const(size))
        when Min
          size = constraint.value
          solver.add(MIN_SIZE_GTE, segment.size_gte(size))
          if flex == Flex::Legacy
            solver.add(MIN_SIZE_EQ, segment.size_eq_const(size))
          else
            solver.add(FILL_GROW, segment.size_eq_size(area))
          end
        when Len
          solver.add(LENGTH_SIZE_EQ, segment.size_eq_const(constraint.value))
        when Percent
          f = constraint.value.to_f64 / 100.0
          solver.add(PERCENT_SIZE_EQ, segment.size_eq_scaled_size(area, f))
        when Ratio
          f = constraint.num.to_f64 / Math.max(1, constraint.den).to_f64
          solver.add(RATIO_SIZE_EQ, segment.size_eq_scaled_size(area, f))
        when Fill
          solver.add(FILL_GROW, segment.size_eq_size(area))
        end
      end
    end

    def self.configure_fill_constraints(solver : Casso::Solver, segments : Array(Element), constraints : Array(Constraint), flex : Flex)
      valid_constraints = [] of Constraint
      valid_segments = [] of Element

      limit = Math.min(constraints.size, segments.size)
      limit.times do |i|
        c = constraints[i]
        seg = segments[i]
        next if c.is_a?(Min) && flex == Flex::Legacy
        if c.is_a?(Fill) || c.is_a?(Min)
          valid_constraints << c
          valid_segments << seg
        end
      end

      combinations(valid_constraints.size, 2).each do |i, j|
        left_constraint = valid_constraints[i]
        left_segment = valid_segments[i]
        right_constraint = valid_constraints[j]
        right_segment = valid_segments[j]

        left_scaling = left_constraint.is_a?(Fill) ? Math.max(1e-6, left_constraint.value.to_f64) : 1.0
        right_scaling = right_constraint.is_a?(Fill) ? Math.max(1e-6, right_constraint.value.to_f64) : 1.0

        c = Casso::Constraint.new(Casso::Op::Eq, 0, [
          left_segment.end.t(right_scaling),
          left_segment.start.t(-right_scaling),
          right_segment.end.t(-left_scaling),
          right_segment.start.t(left_scaling),
        ])
        solver.add(GROW, c)
      end
    end

    def self.changes_to_rects(changes : Hash(Casso::Symbol, Float64), elements : Array(Element), area : Rectangle, direction : Direction) : Array(Rectangle)
      elements.map do |e|
        start_val = changes[e.start]? || 0.0
        end_val = changes[e.end]? || 0.0

        start_rounded = (start_val.round / FLOAT_PRECISION_MULTIPLIER).round.to_i
        end_rounded = (end_val.round / FLOAT_PRECISION_MULTIPLIER).round.to_i

        size = Math.max(0, end_rounded - start_rounded)

        if direction == Direction::Horizontal
          Ultraviolet.rect(start_rounded, area.min.y, size, area.dy)
        else
          Ultraviolet.rect(area.min.x, start_rounded, area.dx, size)
        end
      end
    end

    def self.combinations(n : Int32, k : Int32) : Array({Int32, Int32})
      result = [] of {Int32, Int32}
      return result if n < k || k < 1
      (0...(n - 1)).each do |i|
        ((i + 1)...n).each do |j|
          result << {i, j}
        end
      end
      result
    end

    struct Splitter
      getter direction : Direction
      getter constraints : Array(Constraint)
      getter padding : Padding
      getter spacing : Int32
      getter flex : Flex

      def initialize(@direction : Direction = Direction::Vertical,
                     @constraints : Array(Constraint) = Array(Constraint).new,
                     @padding : Padding = Padding.new,
                     @spacing : Int32 = 0,
                     @flex : Flex = Flex::Start)
      end

      def with_direction(direction : Direction) : Splitter
        Splitter.new(direction, @constraints, @padding, @spacing, @flex)
      end

      def with_padding(padding : Padding) : Splitter
        Splitter.new(@direction, @constraints, padding, @spacing, @flex)
      end

      def with_spacing(spacing : Int32) : Splitter
        Splitter.new(@direction, @constraints, @padding, spacing, @flex)
      end

      def with_flex(flex : Flex) : Splitter
        Splitter.new(@direction, @constraints, @padding, @spacing, flex)
      end

      def with_constraints(constraints : Array(Constraint)) : Splitter
        Splitter.new(@direction, constraints, @padding, @spacing, @flex)
      end

      def split(area : Rectangle) : Array(Rectangle)
        segments, _ = split_with_spacers(area)
        segments
      end

      def split_with_spacers(area : Rectangle) : {Array(Rectangle), Array(Rectangle)}
        key = cache_key(area)
        cached_val, found = GLOBAL_CACHE.get(key)
        if found && cached_val
          return cached_val.segments, cached_val.spacers
        end

        segments, spacers = resolve_split(area)
        GLOBAL_CACHE.add(key, CacheValue.new(segments, spacers))
        {segments, spacers}
      end

      private def cache_key(area : Rectangle) : CacheKey
        types = @constraints.map(&.class.name).join(",")
        CacheKey.new(area, @direction, types, @padding, @spacing, @flex)
      end

      private def resolve_split(area : Rectangle) : {Array(Rectangle), Array(Rectangle)}
        solver = Casso::Solver.new
        inner = @padding.apply(area)

        area_start, area_end = if @direction == Direction::Horizontal
                                 {inner.min.x.to_f64 * FLOAT_PRECISION_MULTIPLIER,
                                  inner.max.x.to_f64 * FLOAT_PRECISION_MULTIPLIER}
                               else
                                 {inner.min.y.to_f64 * FLOAT_PRECISION_MULTIPLIER,
                                  inner.max.y.to_f64 * FLOAT_PRECISION_MULTIPLIER}
                               end

        variable_count = @constraints.size * 2 + 2
        variables = Array(Casso::Symbol).new(variable_count) { Casso::Symbol.new(Casso::SymbolKind::External) }

        spacer_elements = Ultraviolet::Layout.new_elements(variables)
        segment_elements = Ultraviolet::Layout.new_elements(variables[1..])

        area_el = Element.new(variables[0], variables[variable_count - 1])

        Ultraviolet::Layout.configure_area(solver, area_el, area_start, area_end)
        Ultraviolet::Layout.configure_variable_in_area_constraints(solver, variables, area_el)
        Ultraviolet::Layout.configure_variable_constraints(solver, variables)
        Ultraviolet::Layout.configure_flex_constraints(solver, area_el, spacer_elements, @flex, @spacing)
        Ultraviolet::Layout.configure_constraints(solver, area_el, segment_elements, @constraints, @flex)
        Ultraviolet::Layout.configure_fill_constraints(solver, segment_elements, @constraints, @flex)

        if @flex != Flex::Legacy
          (0...(segment_elements.size - 1)).each do |i|
            left = segment_elements[i]
            right = segment_elements[i + 1]
            solver.add(ALL_SEGMENT_GROW, left.size_eq_size(right))
          end
        end

        changes = variables.to_h { |v| {v, solver.val(v)} }

        segments = Ultraviolet::Layout.changes_to_rects(changes, segment_elements, inner, @direction)
        spacers = Ultraviolet::Layout.changes_to_rects(changes, spacer_elements, inner, @direction)

        {segments, spacers}
      end
    end

    def self.vertical(*constraints : Constraint) : Splitter
      arr = Array(Constraint).new
      constraints.each { |con| arr << con }
      Splitter.new(Direction::Vertical, arr)
    end

    def self.horizontal(*constraints : Constraint) : Splitter
      arr = Array(Constraint).new
      constraints.each { |con| arr << con }
      Splitter.new(Direction::Horizontal, arr)
    end
  end
end
