# frozen_string_literal: true

RSpec.describe Coelacanth::Configure do
  let(:config) { described_class.new }
  let(:config_path) { config.send(:root).join("config/coelacanth.yml") }
  let(:yaml_content) { { "test" => { "some_key" => "some_value" } }.to_yaml }

  shared_context "with common stubs" do
    before do
      allow(File).to receive(:read).with(config_path).and_return(yaml_content)
    end
  end

  describe "#read" do
    context "when Rails is defined" do
      before do
        stub_const("Rails", Class.new)
        allow(Rails).to receive(:env).and_return("test")
        allow(Rails).to receive(:root).and_return(Pathname.new("/root"))
      end
      include_context "with common stubs"

      it "reads the configuration value for the given key" do
        expect(config.read("some_key")).to eq("some_value")
      end

      it "returns nil for a non-existent key" do
        expect(config.read("non_existent_key")).to be_nil
      end
    end

    context "when Rails is not defined" do
      before do
        hide_const("Rails")
        allow(ENV).to receive(:[]).with("RAILS_ENV").and_return("test")
      end
      include_context "with common stubs"

      it "reads the configuration value for the given key" do
        expect(config.read("some_key")).to eq("some_value")
      end

      it "returns nil for a non-existent key" do
        expect(config.read("non_existent_key")).to be_nil
      end
    end
  end

  describe "#root" do
    context "when Rails is defined" do
      before do
        stub_const("Rails", Class.new)
        allow(Rails).to receive(:root).and_return(Pathname.new("/root"))
      end
      include_context "with common stubs"

      it "returns Rails.root" do
        expect(config.send(:root)).to eq(Pathname.new("/root"))
      end
    end

    context "when Rails is not defined" do
      before do
        hide_const("Rails")
      end

      it "returns the gem root directory" do
        expect(config.send(:root)).to eq(Pathname.new(File.expand_path("../..", __dir__)))
      end
    end
  end
end
