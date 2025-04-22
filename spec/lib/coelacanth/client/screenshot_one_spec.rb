require "spec_helper"
require "coelacanth/client/screenshot_one"
require "webmock/rspec"

RSpec.describe Coelacanth::Client::ScreenshotOne do
  let(:url) { "http://example.com" }
  let(:config) { double("Config", read: "dummy_api_key") }
  let(:screenshot_one) { described_class.new(url, config) }

  describe "#get_response" do
    context "when the request is successful" do
      before do
        stub_request(:get, url).to_return(status: 200, body: "response body")
      end

      it "returns the response body" do
        expect(screenshot_one.get_response).to eq("response body")
      end

      it "sets the status code" do
        screenshot_one.get_response
        expect(screenshot_one.instance_variable_get(:@status_code)).to eq(200)
      end
    end

    context "when the request fails" do
      before do
        stub_request(:get, url).to_return(status: 404)
      end

      it "raises an OpenURI::HTTPError" do
        expect { screenshot_one.get_response }.to raise_error(OpenURI::HTTPError)
      end

      it "sets the status code" do
        begin
          screenshot_one.get_response
        rescue OpenURI::HTTPError
          # Ignored
        end
        expect(screenshot_one.instance_variable_get(:@status_code)).to eq(404)
      end
    end
  end

  describe "#get_screenshot" do
    let(:api_url) { "https://api.screenshotone.com/take" }
    let(:screenshot_response) { "screenshot data" }

    before do
      stub_request(:get, /#{api_url}/).to_return(status: 200, body: screenshot_response)
    end

    it "returns the screenshot data" do
      expect(screenshot_one.get_screenshot).to eq(screenshot_response)
    end

    it "raises an error if the response is not successful" do
      stub_request(:get, /#{api_url}/).to_return(status: 500)
      expect { screenshot_one.get_screenshot }.to raise_error(RuntimeError, /Failed to fetch screenshot/)
    end
  end
end
