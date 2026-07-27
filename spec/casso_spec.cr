require "./spec_helper"

describe "Casso::Symbol" do
  it "creates symbols with correct kinds" do
    ext = Casso::Symbol.new(Casso::SymbolKind::External)
    ext.kind.should eq(Casso::SymbolKind::External)
    ext.is_zero?.should be_false
    ext.external?.should be_true
    ext.restricted?.should be_false
    ext.is_dummy?.should be_false

    slack = Casso::Symbol.new(Casso::SymbolKind::Slack)
    slack.kind.should eq(Casso::SymbolKind::Slack)
    slack.restricted?.should be_true

    err = Casso::Symbol.new(Casso::SymbolKind::Error)
    err.kind.should eq(Casso::SymbolKind::Error)
    err.restricted?.should be_true

    dummy = Casso::Symbol.new(Casso::SymbolKind::Dummy)
    dummy.kind.should eq(Casso::SymbolKind::Dummy)
    dummy.is_dummy?.should be_true
  end

  it "zero symbol is zero" do
    Casso::Symbol.zero.is_zero?.should be_true
  end

  it "term creation" do
    s = Casso::Symbol.new(Casso::SymbolKind::External)
    t = s.t(2.5)
    t.coeff.should eq(2.5)
    t.id.should eq(s)
  end
end

describe "Casso::Solver" do
  it "solves basic constraints" do
    l = Casso::Symbol.new(Casso::SymbolKind::External)
    m = Casso::Symbol.new(Casso::SymbolKind::External)
    r = Casso::Symbol.new(Casso::SymbolKind::External)

    a = Casso::Constraint.new(Casso::Op::Eq, 0, [r.t(1), l.t(1), m.t(-2)])
    b = Casso::Constraint.new(Casso::Op::Gte, -100, [r.t(1), l.t(-1)])
    c = Casso::Constraint.new(Casso::Op::Gte, 0, [l.t(1)])

    s = Casso::Solver.new
    s.add(1e9, a).should be_true
    s.add(1e9, b).should be_true
    s.add(1e9, c).should be_true

    s.val(l).should eq(0)
    s.val(m).should eq(50)
    s.val(r).should eq(100)
  end

  it "solves constraints requiring artificial variable" do
    s = Casso::Solver.new

    p1 = Casso::Symbol.new(Casso::SymbolKind::External)
    p2 = Casso::Symbol.new(Casso::SymbolKind::External)
    p3 = Casso::Symbol.new(Casso::SymbolKind::External)
    container = Casso::Symbol.new(Casso::SymbolKind::External)

    s.add(1e9, Casso::Constraint.new(Casso::Op::Eq, -100, [container.t(1)])).should be_true
    s.add(1e6, Casso::Constraint.new(Casso::Op::Gte, -30, [p1.t(1)])).should be_true
    s.add(1e3, Casso::Constraint.new(Casso::Op::Eq, 0, [p1.t(1), p3.t(-1)])).should be_true
    s.add(1e9, Casso::Constraint.new(Casso::Op::Eq, 0, [p2.t(1), p1.t(-2)])).should be_true
    s.add(1e9, Casso::Constraint.new(Casso::Op::Eq, 0, [container.t(1), p1.t(-1), p2.t(-1), p3.t(-1)])).should be_true

    s.val(p1).should eq(30)
    s.val(p2).should eq(60)
    s.val(p3).should eq(10)
    s.val(container).should eq(100)
  end

  it "returns false for unsatisfiable constraint" do
    s = Casso::Solver.new
    a = Casso::Symbol.new(Casso::SymbolKind::External)
    b = Casso::Symbol.new(Casso::SymbolKind::External)

    s.add(1e9, Casso::Constraint.new(Casso::Op::Eq, 0, [a.t(1)])).should be_true
    s.add(1e9, Casso::Constraint.new(Casso::Op::Eq, -10, [b.t(1)])).should be_true
    result = s.add(1e9, Casso::Constraint.new(Casso::Op::Eq, 0, [a.t(1), b.t(-1)]))
    result.should be_false
  end
end
