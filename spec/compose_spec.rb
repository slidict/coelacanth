# frozen_string_literal: true

require "yaml"

RSpec.describe "compose.yml" do
  subject(:compose) { YAML.safe_load_file("compose.yml") }

  it "provides Gotenberg to the app service" do
    app = compose.fetch("services").fetch("app")

    expect(app.fetch("depends_on")).to include("gotenberg")
    expect(app.fetch("environment")).to include(
      "COELACANTH_GOTENBERG_URL=${COELACANTH_GOTENBERG_URL:-http://gotenberg:3000}",
      "COELACANTH_GOTENBERG_WAIT_DELAY=${COELACANTH_GOTENBERG_WAIT_DELAY:-}",
      "COELACANTH_GOTENBERG_USER_AGENT=${COELACANTH_GOTENBERG_USER_AGENT:-}"
    )
  end

  it "defines a Gotenberg service on the application network" do
    gotenberg = compose.fetch("services").fetch("gotenberg")

    expect(gotenberg.fetch("image")).to eq("gotenberg/gotenberg:8")
    expect(gotenberg.fetch("networks")).to include("app-tier")
  end
end
