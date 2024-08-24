# frozen_string_literal: true

RSpec.describe Coelacanth::Client do
  subject { described_class.new }

  describe ".valid_url?" do

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

  describe ".resolve_redirect" do
    let(:url) { URI.parse("http://example.com") }
    let(:redirect_url) { URI.parse("http://example.com/redirect") }

    it "with no redirect" do
      allow(Net::HTTP).to receive(:get_response).with(url).and_return(Net::HTTPSuccess.new(nil, "200", "OK"))

      expect(subject.resolve_redirect(url)).to eq(url)
    end

    it "with redirect" do
      response = Net::HTTPRedirection.new("1.1", "302", "Found")
      allow(response).to receive(:[]).with("location").and_return(redirect_url.to_s)
      allow(Net::HTTP).to receive(:get_response).with(url).and_return(response)
      allow(Net::HTTP).to receive(:get_response).with(redirect_url).and_return(Net::HTTPSuccess.new(nil, "200", "OK"))

      expect(subject.resolve_redirect(url)).to eq(redirect_url)
    end

    it "with deep redirect" do
      response = Net::HTTPRedirection.new("1.1", "302", "Found")
      allow(response).to receive(:[]).with("location").and_return(redirect_url.to_s)
      allow(Net::HTTP).to receive(:get_response).with(url).and_return(response)
      allow(Net::HTTP).to receive(:get_response).with(redirect_url).and_return(response)

      expect { subject.resolve_redirect(url) }.to raise_error(Coelacanth::DeepRedirectError)
    end

    it "with invalid redirect" do
      allow(Net::HTTP).to receive(:get_response).with(url).and_return(Net::HTTPUnknownResponse.new(nil, "500", "Internal Server Error"))

      expect { subject.resolve_redirect(url) }.to raise_error(Coelacanth::RedirectError)
    end
  end
end
