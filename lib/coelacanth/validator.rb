# frozen_string_literal: true

require "ferrum"

module Coelacanth
  # Coelacanth::Validator
  class Validator
    def valid_url?(url)
      uri = URI.parse(url)
      uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)
    rescue URI::InvalidURIError
      false
    end
  end
end
