require "./spec_helper"

describe Ultraviolet::TabStops do
  it "initializes and sets stops" do
    tests = [
      {
        name:     "default interval of 8",
        width:    24,
        interval: Ultraviolet::DEFAULT_TAB_INTERVAL,
        checks:   [
          {col: 0, expected: true},
          {col: 7, expected: false},
          {col: 8, expected: true},
          {col: 15, expected: false},
          {col: 16, expected: true},
          {col: 23, expected: false},
        ],
      },
      {
        name:     "custom interval of 4",
        width:    16,
        interval: 4,
        checks:   [
          {col: 0, expected: true},
          {col: 3, expected: false},
          {col: 4, expected: true},
          {col: 7, expected: false},
          {col: 8, expected: true},
          {col: 12, expected: true},
          {col: 15, expected: false},
        ],
      },
    ]

    tests.each do |test_case|
      stops = Ultraviolet::TabStops.new(test_case[:width], test_case[:interval])
      test_case[:checks].each do |check|
        stops.stop?(check[:col]).should eq(check[:expected]), test_case[:name]
      end

      custom_col = test_case[:interval] + 1
      stops.set(custom_col)
      stops.stop?(custom_col).should be_true

      regular_stop = test_case[:interval]
      stops.reset(regular_stop)
      stops.stop?(regular_stop).should be_false
    end
  end

  it "navigates between tab stops" do
    stops = Ultraviolet::TabStops.new(24, Ultraviolet::DEFAULT_TAB_INTERVAL)
    tests = [
      {name: "from column 0", col: 0, next: 8, prev: 0},
      {name: "from column 4", col: 4, next: 8, prev: 0},
      {name: "from column 8", col: 8, next: 16, prev: 0},
      {name: "from column 20", col: 20, next: 23, prev: 16},
    ]

    tests.each do |test_case|
      stops.next(test_case[:col]).should eq(test_case[:next]), test_case[:name]
      stops.prev(test_case[:col]).should eq(test_case[:prev]), test_case[:name]
    end
  end

  it "clears stops" do
    stops = Ultraviolet::TabStops.new(24, Ultraviolet::DEFAULT_TAB_INTERVAL)
    stops.stop?(0).should be_true
    stops.stop?(8).should be_true
    stops.stop?(16).should be_true

    stops.clear
    (0...24).each do |i|
      stops.stop?(i).should be_false
    end
  end

  it "resizes stops" do
    tests = [
      {
        name:     "grow buffer",
        initial:  16,
        resized:  24,
        interval: Ultraviolet::DEFAULT_TAB_INTERVAL,
        checks:   [
          {col: 0, expected: true},
          {col: 8, expected: true},
          {col: 16, expected: true},
          {col: 23, expected: false},
        ],
      },
      {
        name:     "same size - no change",
        initial:  16,
        resized:  16,
        interval: Ultraviolet::DEFAULT_TAB_INTERVAL,
        checks:   [
          {col: 0, expected: true},
          {col: 8, expected: true},
          {col: 15, expected: false},
        ],
      },
      {
        name:     "resize with custom interval",
        initial:  8,
        resized:  16,
        interval: 4,
        checks:   [
          {col: 0, expected: true},
          {col: 4, expected: true},
          {col: 8, expected: true},
          {col: 12, expected: true},
          {col: 15, expected: false},
        ],
      },
    ]

    tests.each do |test_case|
      stops = Ultraviolet::TabStops.new(test_case[:initial], test_case[:interval])
      stops.width.should eq(test_case[:initial])
      stops.resize(test_case[:resized])
      stops.width.should eq(test_case[:resized])

      test_case[:checks].each do |check|
        stops.stop?(check[:col]).should eq(check[:expected]), test_case[:name]
      end

      expected_len = (test_case[:resized] + (stops.interval - 1)) // stops.interval
      stops.stops.size.should eq(expected_len)
    end
  end

  it "handles resize edge cases" do
    stops = Ultraviolet::TabStops.new(8, Ultraviolet::DEFAULT_TAB_INTERVAL)
    stops.resize(0)
    stops.width.should eq(0)
    stops.stop?(0).should be_false

    stops = Ultraviolet::TabStops.new(8, Ultraviolet::DEFAULT_TAB_INTERVAL)
    stops.resize(1000)
    stops.stop?(992).should be_true
    stops.stop?(999).should be_false

    stops = Ultraviolet::TabStops.new(8, Ultraviolet::DEFAULT_TAB_INTERVAL)
    [16, 8, 24, 4].each do |size|
      stops.resize(size)
      stops.width.should eq(size)
      stops.stop?(0).should be_true
    end
  end
end
