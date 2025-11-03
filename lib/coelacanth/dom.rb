# frozen_string_literal: true

require "oga"
require_relative "http"

module Coelacanth
  # Coelacanth::Dom
  class Dom
    def oga(url, html: nil)
      html ||= begin
        Coelacanth::HTTP.get_response(URI.parse(url)).body
      rescue Coelacanth::TimeoutError
        ""
      end
      Oga.parse_xml(html.to_s)
    end
  end
end
