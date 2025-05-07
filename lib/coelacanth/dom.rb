# frozen_string_literal: true

require "oga"

module Coelacanth
  # Coelacanth::Dom
  class Dom
    def oga(url)
      Oga.parse_xml(Net::HTTP.get_response(URI.parse(url)))
    end
  end
end
