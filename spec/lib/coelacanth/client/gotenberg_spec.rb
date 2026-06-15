# frozen_string_literal: true

require "spec_helper"
require "coelacanth/client/gotenberg"
require "webmock/rspec"

RSpec.describe Coelacanth::Client::Gotenberg do
  let(:url) { "http://example.com" }
  let(:config) do
    instance_double(Coelacanth::Configure).tap do |cfg|
      allow(cfg).to receive(:read) do |key|
        {
          "client" => "gotenberg",
          "gotenberg.url" => "http://gotenberg.test:3000",
          "gotenberg.open_timeout" => 5,
          "gotenberg.read_timeout" => 30,
          "gotenberg.wait_delay" => "2s",
          "gotenberg.user_agent" => "Coelacanth Gotenberg",
          "gotenberg.extra_http_headers" => { "Authorization" => "Bearer token" }
        }[key]
      end
    end
  end
  let(:client) { described_class.new(url, config) }

  describe "#get_response" do
    it "fetches the page body directly" do
      stub_request(:get, url).to_return(status: 200, body: "response body")

      expect(client.get_response).to eq("response body")
      expect(client.instance_variable_get(:@status_code)).to eq(200)
    end

    it "raises an HTTP error when the page request fails" do
      stub_request(:get, url).to_return(status: 404, body: "not found")

      expect { client.get_response }.to raise_error(OpenURI::HTTPError)
      expect(client.instance_variable_get(:@status_code)).to eq(404)
    end
  end

  describe "#get_screenshot" do
    let(:endpoint) { "http://gotenberg.test:3000/forms/chromium/screenshot/url" }

    it "posts a multipart request to Gotenberg and returns the screenshot" do
      stub_request(:post, endpoint).to_return(status: 200, body: "png data")

      expect(client.get_screenshot).to eq("png data")
      expect(WebMock).to have_requested(:post, endpoint)
        .with(headers: { "Content-Type" => /multipart\/form-data/ })
      expect(client.send(:gotenberg_form_fields)).to include(
        ["url", url],
        ["waitDelay", "2s"],
        ["userAgent", "Coelacanth Gotenberg"],
        ["extraHttpHeaders", %({"Authorization":"Bearer token"})]
      )
    end

    it "raises an error when Gotenberg returns a non-success response" do
      stub_request(:post, endpoint).to_return(status: 503, body: "unavailable")

      expect { client.get_screenshot }
        .to raise_error(RuntimeError, /Failed to fetch screenshot from Gotenberg: 503/)
    end

    it "raises a Coelacanth timeout error when Gotenberg times out" do
      stub_request(:post, endpoint).to_timeout

      expect { client.get_screenshot }
        .to raise_error(Coelacanth::TimeoutError, /Gotenberg screenshot request timed out/)
    end
  end
end
