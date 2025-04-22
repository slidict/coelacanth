# frozen_string_literal: true

RSpec.describe Coelacanth::Client::Ferrum do
  subject { described_class.new }

  describe "#remote_client" do
    context "when headers are provided" do
      it_behaves_like "a remote client", {
        headers: { "Authorization" => "Bearer 1234567890", "User-Agent" => "Coelacanth Chrome Extension" },
        ws_url: "ws://chrome:3000/chrome",
        timeout: 10
      }
    end
  end
end
