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
    let(:extractor) { instance_double(Coelacanth::Extractor) }
    let(:config) { instance_double(Coelacanth::Configure) }
    let(:redirector) { instance_double(Coelacanth::Redirect, resolve_redirect: url) }
    let(:screenshot) { "screenshot_data" }
    let(:expected_response_metadata) do
      {
        status_code: 200,
        headers: { "content-type" => "text/html" },
        final_url: url
      }
    end
    let(:extraction_payload) do
      {
        title: "Example",
        body_markdown: "Body",
        body_markdown_list: ["Body"],
        body_morphemes: [{ token: "body", count: 1, score: 0.7 }],
        response_metadata: expected_response_metadata
      }
    end
    let(:utf8_html) { "<html><body>デジタル庁のテスト</body></html>" }
    let(:binary_html) { utf8_html.dup.force_encoding(Encoding::ASCII_8BIT) }
    let(:http_response) do
      double(
        "http_response",
        body: binary_html,
        code: "200",
        status_code: 200,
        headers: { "content-type" => "text/html" },
        final_url: url
      )
    end

    before do
      allow(Coelacanth).to receive(:config).and_return(config)
      allow(Coelacanth::Dom).to receive(:new).and_return(dom)
      allow(Coelacanth::Extractor).to receive(:new).and_return(extractor)
      allow(Coelacanth::Redirect).to receive(:new).and_return(redirector)
    end

    shared_examples "analyze workflow" do
      it "returns the expected payload" do
        result = Coelacanth.analyze(url)

        expect(result).to eq({
          dom: "parsed_dom",
          screenshot: screenshot,
          extraction: extraction_payload,
          response: expected_response_metadata
        })
      end
    end

    context "when the HTTP request succeeds" do
      before do
        allow(Coelacanth::HTTP).to receive(:get_response).and_return(http_response)

        allow(dom).to receive(:oga) do |passed_url, html:|
          expect(passed_url).to eq(url)
          expect(html.encoding).to eq(Encoding::UTF_8)
          expect(html).to eq(utf8_html)
          "parsed_dom"
        end

        allow(extractor).to receive(:call) do |**args|
          expect(args[:html].encoding).to eq(Encoding::UTF_8)
          expect(args[:html]).to eq(utf8_html)
          expect(args[:url]).to eq(url)
          expect(args[:response_metadata]).to eq(expected_response_metadata)
          extraction_payload
        end
      end

      context "when client is ferrum" do
        before do
          allow(config).to receive(:read).with("client").and_return("ferrum")
          allow(Coelacanth::Client::Ferrum).to receive(:new).with(url).and_return(ferrum_client)
          allow(ferrum_client).to receive(:get_screenshot).and_return(screenshot)
        end

        include_examples "analyze workflow"
      end

      context "when client is screenshot_one" do
        before do
          allow(config).to receive(:read).with("client").and_return("screenshot_one")
          allow(Coelacanth::Client::ScreenshotOne).to receive(:new).with(url).and_return(screenshot_one_client)
          allow(screenshot_one_client).to receive(:get_screenshot).and_return(screenshot)
        end

        include_examples "analyze workflow"
      end
    end

    context "when the HTTP request times out" do
      let(:expected_response_metadata) do
        {
          status_code: nil,
          headers: {},
          final_url: url
        }
      end

      before do
        allow(Coelacanth::HTTP).to receive(:get_response).and_raise(Coelacanth::TimeoutError, "timeout")
        allow(config).to receive(:read).with("client").and_return("ferrum")
        allow(Coelacanth::Client::Ferrum).to receive(:new).with(url).and_return(ferrum_client)
        allow(ferrum_client).to receive(:get_screenshot).and_return(screenshot)
        allow(dom).to receive(:oga).with(url, html: "").and_return("parsed_dom")
        allow(extractor).to receive(:call).with(
          html: "",
          url: url,
          response_metadata: expected_response_metadata
        ).and_return(extraction_payload)
      end

      it "continues with empty HTML" do
        result = Coelacanth.analyze(url)

        expect(result).to eq({
          dom: "parsed_dom",
          screenshot: screenshot,
          extraction: extraction_payload,
          response: expected_response_metadata
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
