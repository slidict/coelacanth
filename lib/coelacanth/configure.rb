# frozen_string_literal: true

require "yaml"
require "erb"

module Coelacanth
  # Coelacanth::Configure
  class Configure
    CONFIG_PATH = "config/coelacanth.yml"

    def read(key)
      return yaml[key] unless key.include?(".")

      key.split(".").reduce(yaml) { |hash, k| hash[k] }
    end

    def yaml
      @yaml ||= YAML.unsafe_load(ERB.new(File.read(file)).result)[env]
    end

    private

    def root
      return ::Rails.root if defined?(::Rails)

      Pathname.new(File.expand_path("../..", __dir__))
    end

    def file
      root.join(CONFIG_PATH)
    end

    def env
      return ::Rails.env if defined?(::Rails)

      env_value = ENV["RAILS_ENV"].to_s.strip
      env_value = ENV["RACK_ENV"].to_s.strip if env_value.empty?
      env_value.empty? ? "development" : env_value
    end
  end
end
