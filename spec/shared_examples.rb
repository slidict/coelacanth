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
