# frozen_string_literal: true

require "yaml"

RSpec.describe "Dockerfile" do
  subject(:lines) { File.readlines("Dockerfile").map(&:strip) }

  let(:from) { lines.find { |line| line.start_with?("FROM ") } }

  it "builds from an image that needs no registry credentials" do
    expect(from).to eq("FROM ruby:3.4-bookworm")
  end

  it "tracks the Ruby version the CI matrix tests" do
    matrix = YAML.safe_load_file(".github/workflows/main.yml")
                 .fetch("jobs").fetch("build")
                 .fetch("strategy").fetch("matrix").fetch("ruby")

    expect(from).to include(*matrix)
  end

  it "sets the working directory before copying the project in" do
    # The official ruby image sets no WORKDIR, unlike the base this replaced. Without
    # one, COPY would place the project in / and bundle install would run there, and
    # useradd -d /app would point at a directory that does not exist.
    workdir = lines.index("WORKDIR /app")
    copy = lines.index("COPY . .")

    expect(workdir).not_to be_nil
    expect(copy).not_to be_nil
    expect(workdir).to be < copy
  end
end
