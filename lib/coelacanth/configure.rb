# frozen_string_literal: true
require "yaml"
require "erb"

module Coelacanth
  # Coelacanth::Configure
  class Configure
    CONFIG_PATH = "config/coelacanth.yml"

    def read(key)
      @yaml ||= YAML.unsafe_load(ERB.new(File.read(file)).result)[env]
      p @yaml
      p File.read(file)
      p file
      p env
      @yaml[key]
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

      rails_env || rack_env || "development"
    end

    def rails_env
      ENV.key?("RAILS_ENV") && !ENV["RAILS_ENV"].empty? && ENV["RAILS_ENV"]
    end

    def rack_env
      ENV.key?("RACK_ENV") && !ENV["RACK_ENV"].empty? && ENV["RACK_ENV"]
    end
  end
end
