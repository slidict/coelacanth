# frozen_string_literal: true

require "yaml"

RSpec.describe "gem-push workflow" do
  subject(:workflow) { YAML.safe_load_file(".github/workflows/gem-push.yml") }

  let(:jobs) { workflow.fetch("jobs") }
  let(:check) { jobs.fetch("check") }
  let(:publish_steps) { jobs.fetch("publish").fetch("steps") }

  def step(steps, name)
    steps.find { |s| s["name"] == name } || raise("step #{name.inspect} not found")
  end

  def publish_if(name)
    step(publish_steps, name).fetch("if")
  end

  it "parses" do
    expect(workflow).to be_a(Hash)
  end

  it "gives the check job only read access, including packages" do
    # The GPR lookup needs packages: read. Nothing write-scoped belongs in check.
    expect(check.fetch("permissions")).to eq("contents" => "read", "packages" => "read")
  end

  it "exposes the GPR state and the release decision to later jobs" do
    expect(check.fetch("outputs").keys).to include("gpr_published", "release_needed")
  end

  it "gates the GPR push on GitHub Packages state, not RubyGems state" do
    # Gating it on `published` is what left a version on RubyGems but never on GPR.
    expect(publish_if("Publish to GPR")).to include("gpr_published")
    expect(publish_if("Publish to GPR")).not_to include("outputs.published")
  end

  it "still gates the RubyGems push on RubyGems state" do
    expect(publish_if("Publish to RubyGems")).to include("outputs.published ==")
  end

  it "keeps the changelog and the Release off a GPR-only run" do
    # release-action creates a missing tag at HEAD, which is not the commit that
    # produced the published gem.
    expect(publish_if("Generate CHANGELOG")).to include("release_needed")
    expect(publish_if("Update GitHub Release")).to include("release_needed")
  end

  it "tests before a GPR-only push" do
    # Such a run publishes while `published` is true, so it must not skip the suite.
    expect(jobs.fetch("test").fetch("if")).to include("gpr_published")
  end

  it "creates the tag before release-action can create it" do
    names = publish_steps.map { |s| s["name"] }

    expect(names.index("Create release tag")).to be < names.index("Update GitHub Release")
  end

  describe "the GPR lookup" do
    let(:run) { step(check.fetch("steps"), "Check GitHub Packages for this version").fetch("run") }
    let(:lines) { run.lines.map(&:strip) }

    it "treats a 404 as a confirmed absence" do
      # The package does not exist until its first push.
      expect(run).to include("grep -qi 'HTTP 404'")
    end

    it "fails closed on any other failure" do
      # A failed lookup reading as "absent" would hide a broken check behind a push.
      error = lines.index { |line| line.start_with?('echo "::error::') }

      expect(error).not_to be_nil
      expect(lines[error + 1..]).to include("exit 1")
    end

    it "sets false only in the no-match and 404 branches" do
      # If the final else branch also set false, a failed lookup would pass silently.
      falses = lines.each_index.select { |i| lines[i] == "gpr_published=false" }

      expect(falses.size).to eq(2)
      expect(lines[falses.first - 1]).to eq("else")
      # The `else` that pairs with the match inside the rc == 0 branch.
      expect(lines[falses.first - 2]).to eq("gpr_published=true")
      expect(lines[falses.last - 2]).to eq("elif grep -qi 'HTTP 404' gpr_err; then")
    end
  end
end
