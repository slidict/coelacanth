# frozen_string_literal: true

require "oga"

module Coelacanth
  # Coelacanth::Dom
  class Dom
    def oga(url, html: nil)
      html ||= Net::HTTP.get_response(URI.parse(url)).body
      Oga.parse_xml(html)
    end
  end
end
