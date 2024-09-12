# frozen_string_literal: true

RSpec.describe Coelacanth::Validator do
  subject { described_class.new }

  describe "#valid_url?" do
    it "with valid (http)" do
      expect(subject.valid_url?("http://example.com")).to be true
      expect(subject.valid_url?("example.com")).to be false
    end

    it "with valid (https)" do
      expect(subject.valid_url?("https://example.com")).to be true
    end

    it "with invalid (ftp)" do
      expect(subject.valid_url?("ftp://example.com")).to be false
    end

    it "with invalid (no protocol)" do
      expect(subject.valid_url?("example.com")).to be false
    end
  end
end
