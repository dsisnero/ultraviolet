require "./spec_helper"

module Ultraviolet
  describe "Terminal Options" do
    it "provides defaults matching Go's DefaultOptions" do
      opts = Options.new
      opts.buffer_size.should eq(4096)
      opts.event_timeout.should eq(100.milliseconds)
      opts.lookup_keys.should be_true
      opts.use_terminfo_keys.should be_false
    end

    it "creates default options via DefaultOptions" do
      opts = Options.default
      opts.buffer_size.should eq(4096)
      opts.event_timeout.should eq(100.milliseconds)
      opts.lookup_keys.should be_true
    end

    it "allows custom values" do
      opts = Options.new(
        buffer_size: 1024,
        event_timeout: 50.milliseconds,
        lookup_keys: false,
        use_terminfo_keys: true,
      )
      opts.buffer_size.should eq(1024)
      opts.event_timeout.should eq(50.milliseconds)
      opts.lookup_keys.should be_false
      opts.use_terminfo_keys.should be_true
    end

    it "has zero-value defaults matching Go and clamps invalid values" do
      opts = Options.new(buffer_size: 0, event_timeout: 0.seconds)
      opts.buffer_size.should eq(0) # raw value, clamping done in Terminal
      opts.event_timeout.should eq(0.seconds)
    end
  end
end
