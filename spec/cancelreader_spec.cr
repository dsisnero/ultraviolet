require "./spec_helper"

describe Ultraviolet::CancelReader do
  it "constructs with nil" do
    reader = Ultraviolet::CancelReader.new(nil)
    reader.cancel.should be_true
  end
end
