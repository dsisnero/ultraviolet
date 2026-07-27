require "./spec_helper"

describe "Casso::LRU" do
  it "stores and retrieves values" do
    cache = Casso::LRU(Int32, String).new(20)

    20.times do |i|
      v = i.to_s
      cache.add(i, v).should be_false

      got, ok = cache.get(i)
      ok.should be_true
      got.should eq(v)
    end
  end

  it "evicts oldest entry when over capacity" do
    cache = Casso::LRU(Int32, String).new(20)

    20.times do |i|
      cache.add(i, i.to_s).should be_false
    end

    cache.add(20, "20").should be_true

    _, ok = cache.get(0)
    ok.should be_false

    21.times do |i|
      next if i == 0
      _, ok = cache.get(i)
      ok.should be_true
    end
  end

  it "moves updated key to front preventing early eviction" do
    cache = Casso::LRU(Int32, String).new(3)

    cache.add(0, "a")
    cache.add(1, "b")
    cache.add(2, "c")

    cache.add(0, "updated")

    cache.add(3, "d").should be_true

    _, ok = cache.get(1)
    ok.should be_false

    got, ok = cache.get(0)
    ok.should be_true
    got.should eq("updated")
  end

  it "handles empty cache" do
    cache = Casso::LRU(Int32, String).new(10)
    _, ok = cache.get(42)
    ok.should be_false
  end
end
