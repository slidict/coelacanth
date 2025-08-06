# frozen_string_literal: true

require 'spec_helper'
require 'coelacanth'
require 'webmock/rspec'

RSpec.describe Coelacanth do
  it "has a version number" do
    expect(Coelacanth::VERSION).not_to be nil
  end

  describe "#analyze" do
    let(:url) { "http://example.com" }
    let(:ferrum_client) { instance_double(Coelacanth::Client::Ferrum) }
    let(:screenshot_one_client) { instance_double(Coelacanth::Client::ScreenshotOne) }
    let(:dom) { instance_double(Coelacanth::Dom) }
    let(:config) { instance_double(Coelacanth::Configure) }
    let(:screenshot) { "screenshot_data" }
    let(:title) { "Example Title" }

    before do
      allow(Coelacanth).to receive(:config).and_return(config)
        allow(Coelacanth::Dom).to receive(:new).and_return(dom)
        allow(dom).to receive(:oga).with(url).and_return("parsed_dom")
        allow(dom).to receive(:title).and_return(title)

      # Stub HTTP requests
      stub_request(:get, "http://example.com/")
        .with(
          headers: {
            'Accept' => '*/*',
            'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
            'Host' => 'example.com',
            'User-Agent' => 'Ruby'
          }
        )
        .to_return(status: 200, body: "", headers: {})
    end

    context "when client is ferrum" do
      before do
        allow(config).to receive(:read).with("client").and_return("ferrum")
        allow(Coelacanth::Client::Ferrum).to receive(:new).with(url).and_return(ferrum_client)
        allow(ferrum_client).to receive(:get_screenshot).and_return(screenshot)
      end

      it "uses Ferrum client and returns the expected result" do
        result = Coelacanth.analyze(url)
        expect(result).to eq({
          dom: "parsed_dom",
          title: title,
          screenshot: screenshot
        })
      end
    end

    context "when client is screenshot_one" do
      before do
        allow(config).to receive(:read).with("client").and_return("screenshot_one")
        allow(Coelacanth::Client::ScreenshotOne).to receive(:new).with(url).and_return(screenshot_one_client)
        allow(screenshot_one_client).to receive(:get_screenshot).and_return(screenshot)
      end

      it "uses ScreenshotOne client and returns the expected result" do
        result = Coelacanth.analyze(url)
        expect(result).to eq({
          dom: "parsed_dom",
          title: title,
          screenshot: screenshot
        })
      end
    end
  end

  describe "#config" do
    it "returns a Configure instance" do
      expect(Coelacanth.config).to be_an_instance_of(Coelacanth::Configure)
    end

    it "memoizes the config instance" do
      config_instance = Coelacanth.config
      expect(Coelacanth.config).to be(config_instance)
    end
  end
end
