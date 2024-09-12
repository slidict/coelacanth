# frozen_string_literal: true

RSpec.describe Coelacanth::Dom do
  subject { described_class.new }

  describe "#oga" do
    let(:url) { "http://example.com" }
    let(:html_content) { "<html><body><h1>Example</h1></body></html>" }
    let(:client) { instance_double(Coelacanth::Client) }
    let(:parsed_dom) { Oga.parse_html(html_content) }

    before do
      allow(Coelacanth::Client).to receive(:new).with(url).and_return(client)
      allow(client).to receive(:get_response).and_return(html_content)
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
end
