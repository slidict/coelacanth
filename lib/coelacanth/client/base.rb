# frozen_string_literal: true

require "ferrum"

module Coelacanth::Client
  # Coelacanth::Client
  class Base
    def initialize(url, config = Coelacanth.config)
      @validator = Coelacanth::Validator.new
      raise URI::InvalidURIError unless @validator.valid_url?(url)
      @config = config
      @url = url
    end

    def client
      @config.read("client")
    end

    def get_response(url = nil)
      raise "Must be implemented in subclass"
    end

    def get_screenshot
      raise "Must be implemented in subclass"
    end
  end
end
