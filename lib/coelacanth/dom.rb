# frozen_string_literal: true

require "oga"

module Coelacanth
  # Coelacanth::Dom
  class Dom
    def oga(url)
      Oga.parse_xml(Client::Ferrum.new(url).get_response)
    end
  end
end
