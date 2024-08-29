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
    let(:url) { "http://example.com" }
    let(:redirect_url) { "http://example.com/redirect" }

    it "with no redirect" do
      response = instance_double(Net::HTTPRedirection, code: "200", body: "<html>Success</html>")
      allow(Net::HTTP).to receive(:get_response).with(URI.parse(url)).and_return(response)

      expect(subject.resolve_redirect(url)).to eq(url)
    end

    it "with deep redirect" do
      response = instance_double(Net::HTTPRedirection, code: "302", body: "<html>Redirect</html>")
      allow(response).to receive(:[]).with("location").and_return(redirect_url.to_s)
      allow(Net::HTTP).to receive(:get_response).with(URI.parse(url)).and_return(response)
      allow(Net::HTTP).to receive(:get_response).with(URI.parse(redirect_url)).and_return(response)

      expect { subject.resolve_redirect(url) }.to raise_error(Coelacanth::DeepRedirectError)
    end

    it "with invalid redirect" do
      response = instance_double(Net::HTTPRedirection, code: "302", body: "<html>Redirect</html>")
      allow(response).to receive(:[]).with("location").and_return(nil)
      allow(Net::HTTP).to receive(:get_response).with(URI.parse(url)).and_return(response)

      expect { subject.resolve_redirect(url) }.to raise_error(Coelacanth::RedirectError)
    end

    it "with redirect" do
      redirect_response = instance_double(Net::HTTPRedirection, code: "302", body: "<html>Redirect</html>")
      success_response = instance_double(Net::HTTPSuccess, code: "200", body: "<html>OK</html>")
      allow(redirect_response).to receive(:[]).with("location").and_return(redirect_url.to_s)

      allow(Net::HTTP).to receive(:get_response).and_return(
        *([redirect_response] * 9 << success_response)
      )

      expect(subject.resolve_redirect(url)).to eq(redirect_url)
    end
  end

  describe "#remote_client" do
    context "when headers are provided" do
      it_behaves_like "a remote client", {
        headers: { "Authorization" => "Bearer 1234567890", "User-Agent" => "Coelacanth Chrome Extension" },
        ws_url: "ws://chrome:3000/chrome",
        timeout: 10
      }
    end
  end
end
