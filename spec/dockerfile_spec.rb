# frozen_string_literal: true

require "yaml"

RSpec.describe "Dockerfile" do
  subject(:lines) { File.readlines("Dockerfile").map(&:strip) }

  let(:from) { lines.find { |line| line.start_with?("FROM ") } }

  it "builds from an image that needs no registry credentials" do
    # An official Docker Hub library image, which pulls anonymously. The base this
    # replaced lived under an organisation and required a docker login.
    expect(from).to start_with("FROM ruby:")
  end

  it "tracks a Ruby version the CI matrix tests" do
    matrix = YAML.safe_load_file(".github/workflows/main.yml")
                 .fetch("jobs").fetch("build")
                 .fetch("strategy").fetch("matrix").fetch("ruby")

    expect(matrix.map(&:to_s)).to include(from[/ruby:(\d+\.\d+)/, 1])
  end

  it "sets the working directory before copying the project in" do
    # The official ruby image sets no WORKDIR, unlike the base this replaced. Without
    # one, COPY would place the project in / and bundle install would run there.
    workdir = lines.index("WORKDIR /app")
    copy = lines.index("COPY . .")

    expect(workdir).not_to be_nil
    expect(copy).not_to be_nil
    expect(workdir).to be < copy
  end

  it "starts through the entrypoint that drops to the host user" do
    # Without it the container runs as root and leaves root-owned files in the checkout.
    expect(lines).to include(a_string_matching(/\AENTRYPOINT .*docker-entrypoint\.sh/))
  end

  it "copies the entrypoint outside the bind-mounted /app" do
    # ./:/app masks the image's /app at runtime, so a script read from there would be
    # whatever the host checkout holds.
    copy = lines.find { |line| line.start_with?("COPY ") && line.include?("docker-entrypoint.sh") }
    destination = copy&.split&.last

    expect(destination).to start_with("/")
    expect(destination).not_to start_with("/app")
  end

  it "has no numeric comparison against an empty string" do
    # `[ "$UID" -ne "" ]` errors instead of evaluating false, so its body never ran.
    expect(File.read("Dockerfile")).not_to include('-ne ""')
  end

  it "takes no UID at build time" do
    # The UID to match depends on the host that mounts the checkout, not the build.
    expect(lines).not_to include(a_string_matching(/\AARG UID\b/))
  end
end

RSpec.describe "docker-entrypoint.sh" do
  subject(:lines) { File.readlines("docker-entrypoint.sh").map(&:strip) }

  let(:code) { lines.reject { |line| line.empty? || line.start_with?("#") } }

  it "is a POSIX shell script that stops on the first error" do
    # A failed useradd or chown must not fall through to running the command.
    expect(lines.first).to eq("#!/bin/sh")
    expect(code).to include("set -e")
  end

  it "runs as root when the UID is empty or 0" do
    # Windows hosts have no host UID to match, and a mount owned by root needs root.
    guard = code.index('if [ -z "$target" ] || [ "$target" = 0 ]; then')

    expect(guard).not_to be_nil
    expect(code[guard + 1]).to eq('exec "$@"')
  end

  it "hands the bundle path to the user before dropping privileges" do
    # Gems are installed as root at build time, and bundle install has to write there.
    chown = code.index('chown -R "$target" "$bundle_path"')
    drop = code.index { |line| line.start_with?("exec setpriv ") }

    expect(chown).not_to be_nil
    expect(drop).not_to be_nil
    expect(chown).to be < drop
  end

  it "rejects a UID that is not a number" do
    # It is passed to useradd and setpriv, which must not see arbitrary text.
    # Asserted as the branch's own lines rather than as "an exit 1 exists
    # somewhere", which would still pass with this guard deleted.
    guard = code.index("*[!0-9]*)")

    expect(guard).not_to be_nil
    expect(code[guard + 1]).to start_with("echo ")
    expect(code[guard + 2]).to eq("exit 1")
  end

  it "points HOME at the user it switches to" do
    # setpriv keeps the environment, so HOME would stay root's and Bundler would
    # fall back to a temporary home.
    home = code.index { |line| line.start_with?("HOME=") }
    drop = code.index { |line| line.start_with?("exec setpriv ") }

    expect(home).not_to be_nil
    expect(code).to include("export HOME")
    expect(home).to be < drop
  end

  it "drops privileges as the last thing it does" do
    # exec replaces the shell, so a step placed after it would silently never run.
    expect(code.last).to start_with('exec setpriv --reuid "$target"')
  end

  it "has LF line endings" do
    # It is COPYed into the image, so with CRLF the shebang reads as `/bin/sh\r`,
    # which does not exist, and the container cannot start. Checked as bytes
    # because the assertions above strip \r and would pass either way.
    expect(File.binread("docker-entrypoint.sh")).not_to include("\r")
  end

  it "is pinned to LF in .gitattributes" do
    # The byte check above passes on a Linux CI runner whatever the rule says, so
    # only this catches the rule going missing and breaking Windows checkouts.
    #
    # Normalised before matching: the rule covers `*.sh`, not `.gitattributes`
    # itself, so on a Windows checkout this file carries CRLF and a `$`-anchored
    # match would reject the very rule it is looking for.
    rules = File.read(".gitattributes").gsub("\r\n", "\n")

    expect(rules).to match(/^\*\.sh +text +eol=lf$/)
  end
end
