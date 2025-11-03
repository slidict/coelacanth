require "spec_helper"
require "coelacanth/client/ferrum"

RSpec.describe Coelacanth::Client::Ferrum do
  let(:url) { "https://example.com" }
  let(:config) do
    instance_double(Coelacanth::Configure).tap do |cfg|
      allow(cfg).to receive(:read) do |key|
        {
          "remote_client.headers" => nil,
          "remote_client.ws_url" => "ws://example.test/devtools/browser/SECRET",
          "remote_client.timeout" => 5,
          "client" => "ferrum"
        }[key]
      end
    end
  end
  let(:browser) { instance_double(::Ferrum::Browser) }
  let(:network) { instance_double("FerrumNetwork") }

  before do
    allow(Coelacanth).to receive(:config).and_return(config)
    allow(::Ferrum::Browser).to receive(:new).and_return(browser)
    allow(browser).to receive(:class).and_return(::Ferrum::Browser)
    allow(browser).to receive(:goto)
    allow(browser).to receive(:network).and_return(network)
    allow(browser).to receive(:body).and_return("<html></html>")
    allow(network).to receive(:status).and_return(200)
    allow(network).to receive(:wait_for_idle!).and_return(nil)
  end

  after do
    allow(Coelacanth).to receive(:config).and_call_original
  end

  let(:client) { described_class.new(url) }

  describe "#get_response" do
    it "raises an error with sanitized remote client information" do
      allow(network).to receive(:wait_for_idle!).and_raise(StandardError, "wait failed")

      expect { client.get_response }.to raise_error(RuntimeError) do |error|
        expect(error.message).to include("RemoteClient: Ferrum::Browser")
        expect(error.message).to include("object_id=")
        expect(error.message).not_to include("#<")
        expect(error.message).not_to include("SECRET")
      end
    end
  end

  describe "#get_screenshot" do
    it "raises an error with sanitized remote client information" do
      allow(network).to receive(:wait_for_idle!).and_raise(StandardError, "wait failed")

      expect { client.get_screenshot }.to raise_error(RuntimeError) do |error|
        expect(error.message).to include("RemoteClient: Ferrum::Browser")
        expect(error.message).to include("object_id=")
        expect(error.message).not_to include("#<")
        expect(error.message).not_to include("SECRET")
      end
    end
  end
end
