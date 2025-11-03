# frozen_string_literal: true

require "spec_helper"

RSpec.describe "coelacanth.gemspec" do
  let(:gemspec) { Gem::Specification.load(File.expand_path("../coelacanth.gemspec", __dir__)) }

  it "does not include AGENTS.md in the packaged files" do
    expect(gemspec.files).not_to include("AGENTS.md")
  end
end
