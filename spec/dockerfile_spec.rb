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
end
