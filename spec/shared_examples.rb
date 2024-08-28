shared_context "with common stubs" do |yaml_content|
  let(:config) { described_class.new }
  let(:config_path) { config.send(:root).join("config/coelacanth.yml") }

  before do
    allow(File).to receive(:read).with(config_path).and_return(yaml_content)
  end
end

shared_examples "reads configuration" do |key, expected_value|
  it "reads the configuration value for the given key" do
    expect(config.read(key)).to eq(expected_value)
  end

  it "returns nil for a non-existent key" do
    expect(config.read("non_existent_key")).to be_nil
  end
end

shared_context "when Rails is defined" do
  before do
    stub_const("Rails", Class.new)
    allow(Rails).to receive(:env).and_return("test")
    allow(Rails).to receive(:root).and_return(Pathname.new("/root"))
  end
end

shared_context "when Rails is not defined" do
  before do
    hide_const("Rails")
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("RACK_ENV").and_return("test")
  end
end

RSpec.shared_examples "a remote client" do |config_values|
  let(:config) { instance_double("Config") }
  let(:client) { Coelacanth::Client.new }
  let(:browser) { instance_double("Ferrum::Browser") }
  let(:page) { instance_double("Ferrum::Page") }
  let(:headers) { instance_double("Headers") }
  let(:config_path) { Pathname.new("/path/to/config/coelacanth.yml") }

  before do
    allow(config).to receive(:root).and_return(Pathname.new("/path/to"))
    allow(config).to receive(:read).with("remote_client.headers").and_return(config_values[:headers])
    allow(config).to receive(:read).with("remote_client.ws_url").and_return(config_values[:ws_url])
    allow(config).to receive(:read).with("remote_client.timeout").and_return(config_values[:timeout])
    allow(Ferrum::Browser).to receive(:new).with(ws_url: config_values[:ws_url], timeout: config_values[:timeout]).and_return(browser)
    allow(browser).to receive(:create_page).and_return(page)
    allow(page).to receive(:headers).and_return(headers)
    allow(headers).to receive(:set).with(config_values[:headers])
  end

  it "creates a remote client with the correct headers" do
    expect(client.send(:remote_client)).to eq(page)
    expect(headers).to have_received(:set).with(config_values[:headers]) unless config_values[:headers].nil?
  end
end
