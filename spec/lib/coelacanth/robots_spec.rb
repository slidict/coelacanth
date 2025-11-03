# frozen_string_literal: true

require "spec_helper"
require "uri"

RSpec.describe Coelacanth::Robots do
  let(:public_uri) { URI("https://example.com/public") }
  let(:private_uri) { URI("https://example.com/private") }
  let(:session_uri) { URI("https://example.com/private?session=123") }

  before do
    Coelacanth::Robots.clear_cache!
    allow(Coelacanth::Robots).to receive(:allowed?).and_call_original
  end

  it "returns true when the path is allowed" do
    stub_request(:get, "https://example.com/robots.txt").to_return(status: 200, body: <<~ROBOTS)
      User-agent: *
      Allow: /public
      Disallow: /private
    ROBOTS

    expect(described_class.allowed?(public_uri)).to be(true)
  end

  it "returns false when the path is disallowed" do
    stub_request(:get, "https://example.com/robots.txt").to_return(status: 200, body: <<~ROBOTS)
      User-agent: *
      Disallow: /private
    ROBOTS

    expect(described_class.allowed?(private_uri)).to be(false)
  end

  it "returns false when the query string is disallowed" do
    stub_request(:get, "https://example.com/robots.txt").to_return(status: 200, body: <<~ROBOTS)
      User-agent: *
      Disallow: /*?session=
    ROBOTS

    expect(described_class.allowed?(session_uri)).to be(false)
  end

  it "returns true when robots.txt is missing" do
    stub_request(:get, "https://example.com/robots.txt").to_return(status: 404)

    expect(described_class.allowed?(public_uri)).to be(true)
  end
end
