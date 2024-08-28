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
end
