# frozen_string_literal: true

RSpec.describe Coelacanth::Dom do
  subject { described_class.new }

  describe "#oga" do
    let(:url) { "http://example.com" }
    let(:html_content) { "<html><body><h1>Example</h1></body></html>" }
    let(:parsed_dom) { Oga.parse_html(html_content) }

    before do
      stub_request(:get, url).to_return(status: 200, body: html_content)
    end

    it "returns an Oga instance" do
      result = subject.oga(url)
      expect(result).to be_an_instance_of(Oga::XML::Document)
    end

    it "parses the HTML content correctly" do
      result = subject.oga(url)
      expect(result.to_xml).to eq(parsed_dom.to_xml)
    end
  end

  describe "#title" do
    let(:url) { "http://example.com" }
    let(:html_content) { "<html><head><title>Example Title</title></head><body></body></html>" }

    before do
      stub_request(:get, url).to_return(status: 200, body: html_content)
    end

    it "returns the page title" do
      subject.oga(url)
      expect(subject.title).to eq("Example Title")
    end
  end
end
