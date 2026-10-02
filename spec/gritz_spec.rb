# frozen_string_literal: true

RSpec.describe Gritz do
  it "has a version number" do
    expect(Gritz::VERSION).not_to be nil
  end

  it "loads the controller framework" do
    expect(Gritz.const_defined?(:Controller)).to be true
  end

  it "loads the native adapter" do
    expect(Gritz.const_defined?(:Native)).to be true
    expect(Gritz::Transport.const_defined?(:Native)).to be true
  end
end
