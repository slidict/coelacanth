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
    let(:url) {"http://example.com" }
    let(:redirect_url) { "http://example.com/redirect" }

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
      allow(Net::HTTP).to receive(:get_response).with(url)
                                                .and_return(Net::HTTPUnknownResponse.new(nil, "500",
                                                                                         "Internal Server Error"))

      expect { subject.resolve_redirect(url) }.to raise_error(Coelacanth::RedirectError)
    end
  end

  describe "#remote_client" do
    it "creates a new Ferrum::Browser instance" do
      browser_double = instance_double(Ferrum::Browser)
      page_double = double("page")
      allow(Ferrum::Browser).to receive(:new).and_return(browser_double)
      allow(browser_double).to receive(:create_page).and_return(page_double)

      remote_client = subject.send(:remote_client)

      expect(Ferrum::Browser).to have_received(:new).with(ws_url: "ws://chrome:3000/chrome", timeout: 10)
      expect(browser_double).to have_received(:create_page)
      expect(remote_client).to eq(page_double)
    end

    it "caches the @remote_client instance" do
      browser_double = instance_double(Ferrum::Browser)
      page_double = double("page")
      allow(Ferrum::Browser).to receive(:new).and_return(browser_double)
      allow(browser_double).to receive(:create_page).and_return(page_double)

      first_call = subject.send(:remote_client)
      second_call = subject.send(:remote_client)

      expect(first_call).to eq(second_call)
      expect(Ferrum::Browser).to have_received(:new).once
      expect(browser_double).to have_received(:create_page).once
    end
  end
end
