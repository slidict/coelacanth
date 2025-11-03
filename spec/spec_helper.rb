# frozen_string_literal: true

require "coelacanth"
require "webmock/rspec"
require_relative "./lib/shared_examples"

WebMock.disable_net_connect!(allow_localhost: true)

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.before do
    WebMock.reset!
    if defined?(Coelacanth::Robots)
      Coelacanth::Robots.clear_cache!
      allow(Coelacanth::Robots).to receive(:allowed?).and_return(true)
    end
  end

  config.after do
    WebMock.reset!
    Coelacanth::Robots.clear_cache! if defined?(Coelacanth::Robots)
  end
end
