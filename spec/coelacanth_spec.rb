# frozen_string_literal: true

require 'spec_helper'
require 'coelacanth'

RSpec.describe Coelacanth do
  it "has a version number" do
    expect(Coelacanth::VERSION).not_to be nil
  end

  describe "#analyze" do
    let(:url) { "http://example.com" }
    let(:client) { instance_double(Coelacanth::Client) }
    let(:dom) { instance_double(Coelacanth::Dom) }
    let(:config) { instance_double(Coelacanth::Configure) }

    before do
      allow(Coelacanth).to receive(:config).and_return(config)
      allow(Coelacanth::Client).to receive(:new).with(url).and_return(client)
      allow(Coelacanth::Dom).to receive(:new).and_return(dom)
      allow(dom).to receive(:oga).with(url).and_return("parsed_dom")
    end

    it "returns a hash with remote_client and parsed_dom" do
      result = Coelacanth.analyze(url)
      expect(result).to eq({
        oga: "parsed_dom"
      })
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
