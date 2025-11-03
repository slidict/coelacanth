require "spec_helper"
require "coelacanth/client/screenshot_one"
require "webmock/rspec"

RSpec.describe Coelacanth::Client::ScreenshotOne do
  let(:url) { "http://example.com" }
  let(:config) { double("Config", read: "dummy_api_key") }
  let(:screenshot_one) { described_class.new(url, config) }

  describe "#get_response" do
    context "when the request is successful" do
      it "returns the response body" do
        stub_request(:get, url).to_return(status: 200, body: "response body")

        expect(screenshot_one.get_response).to eq("response body")
      end

      it "sets the status code" do
        stub_request(:get, url).to_return(status: 200, body: "response body")

        screenshot_one.get_response

        expect(screenshot_one.instance_variable_get(:@status_code)).to eq(200)
      end
    end

    context "when the request fails" do
      it "raises an OpenURI::HTTPError" do
        stub_request(:get, url).to_return(status: 404)

        expect { screenshot_one.get_response }.to raise_error(OpenURI::HTTPError)
      end

      it "sets the status code" do
        stub_request(:get, url).to_return(status: 404)

        begin
          screenshot_one.get_response
        rescue OpenURI::HTTPError
          # Ignored
        end

        expect(screenshot_one.instance_variable_get(:@status_code)).to eq(404)
      end
    end

    context "when the request times out" do
      let(:ferrum_client) { instance_double(Coelacanth::Client::Ferrum, get_response: "fallback body") }

      before do
        stub_request(:get, url).to_timeout
        allow(ferrum_client).to receive(:instance_variable_get).with(:@status_code).and_return(200)
        allow(Coelacanth::Client::Ferrum).to receive(:new).with(url, config).and_return(ferrum_client)
      end

      it "falls back to the Ferrum client" do
        expect(screenshot_one.get_response).to eq("fallback body")
        expect(Coelacanth::Client::Ferrum).to have_received(:new).with(url, config)
      end
    end
  end

  describe "#get_screenshot" do
    let(:api_url) { "https://api.screenshotone.com/take" }
    let(:screenshot_response) { "screenshot data" }

    it "returns the screenshot data" do
      stub_request(:get, /#{api_url}/).to_return(status: 200, body: screenshot_response)

      expect(screenshot_one.get_screenshot).to eq(screenshot_response)
    end

    it "raises an error if the response is not successful" do
      stub_request(:get, /#{api_url}/).to_return(status: 500)

      expect { screenshot_one.get_screenshot }.to raise_error(RuntimeError, /Failed to fetch screenshot/)
    end

    it "falls back to the Ferrum client on timeout" do
      ferrum_client = instance_double(Coelacanth::Client::Ferrum, get_screenshot: "fallback screenshot")
      stub_request(:get, /#{api_url}/).to_timeout
      allow(Coelacanth::Client::Ferrum).to receive(:new).with(url, config).and_return(ferrum_client)

      expect(screenshot_one.get_screenshot).to eq("fallback screenshot")
      expect(Coelacanth::Client::Ferrum).to have_received(:new).with(url, config)
    end
  end
end
