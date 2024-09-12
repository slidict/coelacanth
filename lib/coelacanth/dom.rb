# frozen_string_literal: true

require "ferrum"
require "oga"

module Coelacanth
  # Coelacanth::Dom
  class Dom
    def oga(url)
      raise URI::InvalidURIError unless Validator.new.valid_url?(url)
      Oga.parse_xml(get_response(@url))
    end
  end
end
