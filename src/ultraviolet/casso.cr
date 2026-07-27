module Casso
  enum SymbolKind : UInt8
    External
    Slack
    Error
    Dummy
  end

  struct Symbol
    @@counter : UInt64 = 0_u64

    getter value : UInt64

    def initialize(@value : UInt64)
    end

    def self.new(kind : SymbolKind) : self
      @@counter += 1
      val = (@@counter & 0x3fffffffffffffff_u64) | (kind.value.to_u64 << 62)
      new(val)
    end

    def self.zero : self
      new(0_u64)
    end

    def kind : SymbolKind
      SymbolKind.from_value((value >> 62).to_u8)
    end

    def is_zero? : Bool
      @value == 0
    end

    def restricted? : Bool
      !is_zero? && (kind.slack? || kind.error?)
    end

    def external? : Bool
      !is_zero? && kind.external?
    end

    def is_dummy? : Bool
      !is_zero? && kind.dummy?
    end

    def t(coeff : Float64) : Term
      Term.new(coeff, self)
    end

    def ==(other : self) : Bool
      @value == other.value
    end

    def hash(hasher)
      @value.hash(hasher)
    end
  end

  struct Term
    getter coeff : Float64
    getter id : Symbol

    def initialize(@coeff : Float64, @id : Symbol)
    end
  end

  enum Op : UInt8
    Eq
    Gte
    Lte
  end

  alias Priority = Float64

  struct Constraint
    getter op : Op
    getter expr : Expr

    def initialize(@op : Op, @expr : Expr)
    end

    def self.new(op : Op, constant : Float64, terms : Array(Term)) : self
      new(op, Expr.new(constant, terms))
    end

    def clone : Constraint
      Constraint.new(@op, @expr.clone)
    end
  end

  class Expr
    property constant : Float64
    property terms : Array(Term)

    def initialize(@constant : Float64 = 0.0, @terms : Array(Term) = Array(Term).new)
    end

    def clone : Expr
      Expr.new(@constant, @terms.dup)
    end

    def find(id : Symbol) : Int32
      @terms.index { |t| t.id == id } || -1
    end

    def delete(idx : Int32)
      @terms.delete_at(idx)
    end

    def add_symbol(coeff : Float64, id : Symbol)
      idx = find(id)
      if idx == -1
        unless Casso.eqz(coeff)
          @terms << Term.new(coeff, id)
        end
        return
      end
      @terms[idx] = Term.new(@terms[idx].coeff + coeff, id)
      if Casso.eqz(@terms[idx].coeff)
        delete(idx)
      end
    end

    def add_expr(coeff : Float64, other : Expr)
      @constant += coeff * other.constant
      other.terms.each do |t|
        add_symbol(coeff * t.coeff, t.id)
      end
    end

    def negate
      @constant = -@constant
      @terms = @terms.map { |t| Term.new(-t.coeff, t.id) }
    end

    def solve_for(id : Symbol)
      idx = find(id)
      return if idx == -1

      coeff = -1.0 / @terms[idx].coeff
      delete(idx)

      return if coeff == 1.0

      @constant *= coeff
      @terms = @terms.map { |t| Term.new(t.coeff * coeff, t.id) }
    end

    def solve_for_symbols(lhs : Symbol, rhs : Symbol)
      add_symbol(-1.0, lhs)
      solve_for(rhs)
    end

    def substitute(id : Symbol, other : Expr)
      idx = find(id)
      return if idx == -1
      coeff = @terms[idx].coeff
      delete(idx)
      add_expr(coeff, other)
    end
  end

  def self.eqz(val : Float64) : Bool
    if val < 0
      -val < 1.0e-8
    else
      val < 1.0e-8
    end
  end

  struct Tag
    getter priority : Priority
    getter marker : Symbol
    getter other : Symbol

    def initialize(@priority : Priority, @marker : Symbol, @other : Symbol)
    end
  end

  class LRU(K, V)
    def initialize(@size : Int32)
      raise "lru: negative size given: #{@size}" if @size < 0
      @items = Hash(K, V).new
      @order = Array(K).new
    end

    def get(key : K)
      v = @items[key]?
      if v
        touch(key)
        {v, true}
      else
        {nil, false}
      end
    end

    def add(key : K, value : V) : Bool
      if @items.has_key?(key)
        @items[key] = value
        touch(key)
        return false
      end

      @items[key] = value
      @order.unshift(key)

      if @order.size > @size
        evicted = @order.pop
        @items.delete(evicted)
        return true
      end

      false
    end

    private def touch(key : K)
      idx = @order.index(key)
      return unless idx
      @order.delete_at(idx)
      @order.unshift(key)
    end
  end

  class Solver
    @tabs : Hash(Symbol, Constraint)
    @tags : Hash(Symbol, Tag)
    @infeasible : Array(Symbol)
    @objective : Expr
    @artificial : Expr

    def initialize
      @tabs = Hash(Symbol, Constraint).new
      @tags = Hash(Symbol, Tag).new
      @infeasible = Array(Symbol).new
      @objective = Expr.new(0.0)
      @artificial = Expr.new(0.0)
    end

    REQUIRED = 1_000_000_000_f64

    def debug_tabs
      @tabs.each do |sym, constraint|
        puts "  tab[#{sym.value}]: const=#{constraint.expr.constant}, terms=#{constraint.expr.terms.map { |t| "{c:#{t.coeff},id:#{t.id.value}}" }}"
      end
      puts "  infeasible: #{@infeasible.map(&.value)}"
      puts "  objective: const=#{@objective.constant}, terms=#{@objective.terms.map { |t| "{c:#{t.coeff},id:#{t.id.value}}" }}"
    end

    def val(id : Symbol) : Float64
      row = @tabs[id]?
      return 0.0 unless row
      row.expr.constant
    end

    def add(priority : Priority, cell : Constraint) : Bool
      marker_tag = Tag.new(priority, Symbol.zero, Symbol.zero)

      c = Constraint.new(cell.op, Expr.new(cell.expr.constant))

      cell.expr.terms.each do |term|
        next if Casso.eqz(term.coeff)
        return false if term.id.is_zero?
        resolved = @tabs[term.id]?
        if resolved
          c.expr.add_expr(term.coeff, resolved.expr)
        else
          c.expr.add_symbol(term.coeff, term.id)
        end
      end

      case c.op
      in .lte?
        marker_tag = Tag.new(priority, Symbol.new(SymbolKind::Slack), Symbol.zero)
        c.expr.add_symbol(1.0, marker_tag.marker)
        if priority < REQUIRED
          error_sym = Symbol.new(SymbolKind::Error)
          marker_tag = Tag.new(priority, marker_tag.marker, error_sym)
          c.expr.add_symbol(-1.0, error_sym)
          @objective.add_symbol(priority, error_sym)
        end
      in .gte?
        marker_tag = Tag.new(priority, Symbol.new(SymbolKind::Slack), Symbol.zero)
        c.expr.add_symbol(-1.0, marker_tag.marker)
        if priority < REQUIRED
          error_sym = Symbol.new(SymbolKind::Error)
          marker_tag = Tag.new(priority, marker_tag.marker, error_sym)
          c.expr.add_symbol(1.0, error_sym)
          @objective.add_symbol(priority, error_sym)
        end
      in .eq?
        if priority < REQUIRED
          marker = Symbol.new(SymbolKind::Error)
          other = Symbol.new(SymbolKind::Error)
          marker_tag = Tag.new(priority, marker, other)
          c.expr.add_symbol(-1.0, marker)
          c.expr.add_symbol(1.0, other)
          @objective.add_symbol(priority, marker)
          @objective.add_symbol(priority, other)
        else
          marker = Symbol.new(SymbolKind::Dummy)
          marker_tag = Tag.new(priority, marker, Symbol.zero)
          c.expr.add_symbol(1.0, marker)
        end
      end

      c.expr.negate if c.expr.constant < 0.0

      subject = find_subject(c, marker_tag)
      if subject.is_zero?
        return false unless augment_artificial_variable(c)
      else
        c.expr.solve_for(subject)
        substitute(subject, c.expr)
        @tabs[subject] = c
      end

      @tags[marker_tag.marker] = marker_tag
      optimize_against(@objective)
    end

    private def find_subject(cell : Constraint, t : Tag) : Symbol
      cell.expr.terms.each do |term|
        return term.id if term.id.external?
      end

      if t.marker.restricted?
        idx = cell.expr.find(t.marker)
        if idx != -1 && cell.expr.terms[idx].coeff < 0.0
          return t.marker
        end
      end

      if t.other.restricted?
        idx = cell.expr.find(t.other)
        if idx != -1 && cell.expr.terms[idx].coeff < 0.0
          return t.other
        end
      end

      cell.expr.terms.each do |term|
        return Symbol.zero unless term.id.is_dummy?
      end

      return Symbol.zero unless Casso.eqz(cell.expr.constant)

      t.marker
    end

    private def substitute(id : Symbol, e : Expr)
      @tabs.each_key do |symbol|
        row = @tabs[symbol]
        row.expr.substitute(id, e)
        @tabs[symbol] = row
        next if symbol.external? || row.expr.constant >= 0.0
        @infeasible << symbol
      end
      @objective.substitute(id, e)
      @artificial.substitute(id, e)
    end

    private def optimize_against(objective : Expr) : Bool
      loop do
        entry = Symbol.zero
        exit = Symbol.zero

        objective.terms.each do |term|
          unless term.id.is_dummy? || term.coeff >= 0.0
            entry = term.id
            break
          end
        end
        return true if entry.is_zero?

        ratio = Float64::MAX

        @tabs.each do |symbol, row|
          next if symbol.external?
          idx = row.expr.find(entry)
          next if idx == -1
          coeff = row.expr.terms[idx].coeff
          next if coeff >= 0.0
          r = -row.expr.constant / coeff
          if r < ratio
            ratio = r
            exit = symbol
          end
        end

        row = @tabs.delete(exit) || Constraint.new(Op::Eq, Expr.new(0.0))

        row.expr.solve_for_symbols(exit, entry)

        substitute(entry, row.expr)
        @tabs[entry] = row
      end
    end

    private def augment_artificial_variable(row : Constraint) : Bool
      art = Symbol.new(SymbolKind::Slack)

      @tabs[art] = row.clone
      @artificial = row.expr.clone

      return false unless optimize_against(@artificial)

      success = Casso.eqz(@artificial.constant)
      @artificial = Expr.new(0.0)

      artificial = @tabs.delete(art)
      if artificial
        if artificial.expr.terms.empty?
          return true
        end

        entry = Symbol.zero
        artificial.expr.terms.each do |term|
          if term.id.restricted?
            entry = term.id
            break
          end
        end
        return false if entry.is_zero?

        artificial.expr.solve_for_symbols(art, entry)

        substitute(entry, artificial.expr)
        @tabs[entry] = artificial
      end

      @tabs.each_key do |symbol|
        row = @tabs[symbol]
        idx = row.expr.find(art)
        if idx != -1
          row.expr.delete(idx)
          @tabs[symbol] = row
        end
      end

      idx = @objective.find(art)
      @objective.delete(idx) if idx != -1

      success
    end
  end
end
