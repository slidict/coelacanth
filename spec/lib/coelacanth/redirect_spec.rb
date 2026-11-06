# frozen_string_literal: true

RSpec.describe Coelacanth::Redirect do
  subject { described_class.new }

  describe "#resolve_redirect" do
    let(:url) { "http://example.com" }
    let(:redirect_url) { "http://example.com/redirect" }

    it "with no redirect" do
      response = instance_double(Net::HTTPSuccess, code: "200", body: "<html>Success</html>")
      allow(Coelacanth::HTTP).to receive(:get_response).with(URI.parse(url)).and_return(response)

      expect(subject.resolve_redirect(url)).to eq(url)
    end

    it "with deep redirect" do
      response = instance_double(Net::HTTPRedirection, code: "302", body: "<html>Redirect</html>")
      allow(response).to receive(:[]).with("location").and_return(redirect_url.to_s)
      allow(Coelacanth::HTTP).to receive(:get_response).with(URI.parse(url)).and_return(response)
      allow(Coelacanth::HTTP).to receive(:get_response).with(URI.parse(redirect_url)).and_return(response)

      expect { subject.resolve_redirect(url) }.to raise_error(Coelacanth::DeepRedirectError)
    end

    it "with invalid redirect" do
      response = instance_double(Net::HTTPRedirection, code: "302", body: "<html>Redirect</html>")
      allow(response).to receive(:[]).with("location").and_return(nil)
      allow(Coelacanth::HTTP).to receive(:get_response).with(URI.parse(url)).and_return(response)

      expect { subject.resolve_redirect(url) }.to raise_error(Coelacanth::RedirectError)
    end

    it "with redirect" do
      redirect_response = instance_double(Net::HTTPRedirection, code: "302", body: "<html>Redirect</html>")
      success_response = instance_double(Net::HTTPSuccess, code: "200", body: "<html>OK</html>")
      allow(redirect_response).to receive(:[]).with("location").and_return(redirect_url.to_s)

      allow(Coelacanth::HTTP).to receive(:get_response).and_return(
        *([redirect_response] * 9 << success_response)
      )

      expect(subject.resolve_redirect(url)).to eq(redirect_url)
    end

    it "returns the original URL when a timeout occurs" do
      allow(Coelacanth::HTTP).to receive(:get_response).and_raise(Coelacanth::TimeoutError, "timeout")

      expect(subject.resolve_redirect(url)).to eq(url)
    end
  end
end
