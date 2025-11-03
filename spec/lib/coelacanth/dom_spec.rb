# frozen_string_literal: true

RSpec.describe Coelacanth::Dom do
  subject { described_class.new }

  describe "#oga" do
    let(:url) { "http://example.com" }
    let(:html_content) { "<html><body><h1>Example</h1></body></html>" }
    let(:parsed_dom) { Oga.parse_html(html_content) }

    context "when the request succeeds" do
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

    context "when the request times out" do
      before do
        stub_request(:get, url).to_timeout
      end

      it "returns an empty document" do
        result = subject.oga(url)
        expect(result.to_xml).to eq(Oga.parse_html("").to_xml)
      end
    end
  end
end
