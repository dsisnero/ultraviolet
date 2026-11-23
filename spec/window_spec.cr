require "./spec_helper"

# Upstream has no window_test.go, so these characterize the constructors that
# examples/boxes.cr needs. They were broken for a while: both called a `private`
# class method through the class, which Crystal rejects, and nothing exercised
# them.
describe "Window constructors" do
  it "builds a standalone window with new_window" do
    win = Ultraviolet::Window.new_window(20, 10)

    win.width.should eq(20)
    win.height.should eq(10)
    win.has_parent?.should be_false
    win.bounds.should eq(Ultraviolet.rect(0, 0, 20, 10))
  end

  it "builds a standalone window with new_screen" do
    win = Ultraviolet::Window.new_screen(12, 6)

    win.width.should eq(12)
    win.height.should eq(6)
    win.has_parent?.should be_false
  end

  it "exposes the same constructors at module level" do
    Ultraviolet.new_window(8, 4).bounds.should eq(Ultraviolet.rect(0, 0, 8, 4))
    Ultraviolet.new_screen(8, 4).bounds.should eq(Ultraviolet.rect(0, 0, 8, 4))
  end

  it "creates child windows positioned inside the parent" do
    root = Ultraviolet::Window.new_screen(30, 10)
    child = root.new_window(2, 3, 6, 4)

    child.has_parent?.should be_true
    child.bounds.should eq(Ultraviolet.rect(2, 3, 6, 4))
  end

  it "rejects negative dimensions" do
    # ErrInvalidDimensions is a instantiated exception constant, not a class.
    expect_raises(Exception, "invalid dimensions") do
      Ultraviolet::Window.new_window(-1, 4)
    end
  end
end
