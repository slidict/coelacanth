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

  it "pushes to GPR only on a confirmed absence" do
    # `!= 'true'` also admits `unknown`, which the step itself turns into a failure
    # rather than a push. Gating on `== 'false'` instead would make an unreadable
    # lookup pass silently with nothing mirrored.
    expect(publish_if("Publish to GPR")).to include("!= 'true'")
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

  it "runs the suite for a publish of this commit, and only for that" do
    # A catch-up mirrors the artifact RubyGems already serves, so it publishes nothing
    # built from this commit and a red HEAD must not block it. Asserting the gate
    # itself, not just the absence of `gpr_published`, which any gate could satisfy.
    expect(jobs.fetch("test").fetch("if")).to include("needed == 'true'")
    expect(jobs.fetch("test").fetch("if")).to include("published == 'false'")
    expect(jobs.fetch("test").fetch("if")).not_to include("gpr_published")
  end

  describe "the GPR push" do
    let(:run) { step(publish_steps, "Publish to GPR").fetch("run") }

    it "never builds a gem of its own" do
      # Running after the changelog steps, a rebuild would pick up the staged
      # CHANGELOG.md through `git ls-files` and so differ from the published gem. The
      # fresh path reuses what the RubyGems push built; the catch-up path downloads.
      expect(run).not_to include("gem build")
    end

    it "fails rather than push when the published artifact is missing" do
      guard = run.lines.index { |line| line.include?('[ ! -f "$gem_file" ]') }

      expect(guard).not_to be_nil
      expect(run.lines[guard + 1]).to include("::error::")
      expect(run.lines[guard + 2].strip).to eq("exit 1")
    end

    it "mirrors the published artifact for a version RubyGems already has" do
      expect(run).to include("rubygems.org/downloads/$gem_file")
    end

    it "refuses to publish an artifact it could not verify" do
      # Each failure must stop the step, never fall back to building HEAD. Asserted per
      # branch so removing any one of them fails here; a count of `exit 1` would not.
      expect(run).to include("sha256sum")
      [
        "could not reach RubyGems",
        "does not serve",
        "could not reach the RubyGems versions API",
        "reports no sha256",
        "does not match the sha256"
      ].each do |message|
        guard = run.lines.index { |line| line.include?("::error::") && line.include?(message) }

        expect(guard).not_to(be_nil, "no ::error:: mentioning #{message.inspect}")
        expect(run.lines[guard + 1].strip).to eq("exit 1")
      end
    end

    it "reports an unreadable lookup instead of pushing" do
      # `check` leaves `unknown` rather than failing the whole job, so this is where an
      # unreadable lookup has to become visible.
      guard = run.lines.index { |line| line.include?('[ "$GPR_PUBLISHED" != false ]') }

      expect(guard).not_to be_nil
      expect(run.lines[guard + 1]).to include("::error::")
      expect(run.lines[guard + 2].strip).to eq("exit 1")
    end

    it "pushes the one file it decided on, not whatever matches a glob" do
      expect(run).to include('gem push --KEY github --host https://rubygems.pkg.github.com/${OWNER} "$gem_file"')
    end

    it "tolerates a repush rejection, which the RubyGems push must not" do
      # GPR's state is read from GPR, so the message means GPR holds or reserves the
      # version and the push can never succeed. For RubyGems it would also mean
      # "yanked", which its lookup cannot see.
      expect(run).to include("repushing of gem versions is not allowed")
      expect(step(publish_steps, "Publish to RubyGems").fetch("run"))
        .not_to include("repushing of gem versions is not allowed")
    end
  end

  it "pushes to GPR last, so nothing else depends on the host it cannot read" do
    # A GPR failure must not strand the RubyGems push, the tag or the Release, and
    # running after the RubyGems push stops a yanked version (which reads as
    # `published=false`) from reaching GPR as a build of the current HEAD.
    names = publish_steps.map { |s| s["name"] }

    expect(names.last).to eq("Publish to GPR")
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

    it "calls an unreadable lookup unknown, not absent" do
      # Absent means "push it". A failed lookup must not earn that, and must not fail
      # the whole check job either: the RubyGems push, the tag and the Release do not
      # need GitHub Packages.
      expect(lines).to include("gpr_published=unknown")
      expect(lines.grep(/^echo "::warning::could not determine/)).not_to be_empty
      expect(lines).not_to include("exit 1")
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
