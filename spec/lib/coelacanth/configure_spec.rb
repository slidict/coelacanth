# frozen_string_literal: true

RSpec.describe Coelacanth::Configure do
  describe "#read" do
    context "when Rails is defined" do
      include_context "when Rails is defined"
      include_context "with common stubs", { "test" => { "some_key" => "some_value" } }.to_yaml
      it_behaves_like "reads configuration", "some_key", "some_value"
    end

    context "when Rails is not defined" do
      include_context "when Rails is not defined"
      include_context "with common stubs", { "test" => { "some_key" => "some_value" } }.to_yaml
      it_behaves_like "reads configuration", "some_key", "some_value"
    end
  end

  describe "remote client headers" do
    subject(:headers) { described_class.new.read("remote_client.headers") }

    let(:default_headers) { { "User-Agent" => "Coelacanth Chrome Extension" } }

    around do |example|
      original_authorization = ENV["COELACANTH_REMOTE_CLIENT_AUTHORIZATION"]
      original_user_agent = ENV["COELACANTH_REMOTE_CLIENT_USER_AGENT"]

      begin
        example.run
      ensure
        if original_authorization.nil?
          ENV.delete("COELACANTH_REMOTE_CLIENT_AUTHORIZATION")
        else
          ENV["COELACANTH_REMOTE_CLIENT_AUTHORIZATION"] = original_authorization
        end

        if original_user_agent.nil?
          ENV.delete("COELACANTH_REMOTE_CLIENT_USER_AGENT")
        else
          ENV["COELACANTH_REMOTE_CLIENT_USER_AGENT"] = original_user_agent
        end
      end
    end

    before do
      ENV.delete("COELACANTH_REMOTE_CLIENT_USER_AGENT")
    end

    context "when the authorization environment variable is unset" do
      before do
        ENV.delete("COELACANTH_REMOTE_CLIENT_AUTHORIZATION")
      end

      it "returns only the default user agent header" do
        expect(headers).to eq(default_headers)
      end
    end

    context "when the authorization environment variable is blank" do
      before do
        ENV["COELACANTH_REMOTE_CLIENT_AUTHORIZATION"] = "  "
      end

      it "returns only the default user agent header" do
        expect(headers).to eq(default_headers)
      end
    end

    context "when the authorization environment variable is provided" do
      before do
        ENV["COELACANTH_REMOTE_CLIENT_AUTHORIZATION"] = "Bearer example-token"
      end

      it "includes the authorization header" do
        expect(headers).to eq(
          default_headers.merge("Authorization" => "Bearer example-token")
        )
      end
    end
  end
end
