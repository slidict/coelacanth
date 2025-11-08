# frozen_string_literal: true

require "spec_helper"
require "uri"
require "webmock/rspec"

RSpec.describe Coelacanth::HTTP do
  let(:page_uri) { URI("https://example.com/private") }
  let(:public_uri) { URI("https://example.com/public") }

  before do
    allow(Coelacanth::Robots).to receive(:allowed?).and_return(true)
  end

  it "allows requests when robots.txt permits the path" do
    expect(Coelacanth::Robots).to receive(:allowed?).with(public_uri).and_return(true)
    stub_request(:get, public_uri.to_s).to_return(status: 200, body: "ok", headers: { "Content-Type" => "text/plain" })

    response = described_class.get_response(public_uri)

    expect(response).to be_a(Net::HTTPSuccess)
    expect(response.body).to eq("ok")
    expect(response.status_code).to eq(200)
    expect(response.headers).to include("content-type" => "text/plain")
    expect(response.final_url).to eq(public_uri.to_s)
  end

  it "raises an error when robots.txt disallows the path" do
    expect(Coelacanth::Robots).to receive(:allowed?).with(page_uri).and_return(false)

    expect do
      described_class.get_response(page_uri)
    end.to raise_error(Coelacanth::RobotsDisallowedError, /disallowed by robots\.txt/)

    expect(a_request(:get, page_uri.to_s)).not_to have_been_made
  end

  it "allows requests when robots.txt is missing" do
    expect(Coelacanth::Robots).to receive(:allowed?).with(public_uri).and_return(true)
    stub_request(:get, public_uri.to_s).to_return(status: 200, body: "ok")

    response = described_class.get_response(public_uri)

    expect(response).to be_a(Net::HTTPSuccess)
    expect(response.body).to eq("ok")
    expect(response.final_url).to eq(public_uri.to_s)
  end
end
