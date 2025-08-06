# frozen_string_literal: true

require "oga"

module Coelacanth
  # Coelacanth::Dom
  class Dom
    # Fetches and parses the DOM of the given URL using Oga.
    #
    # @param url [String] the target URL
    # @return [Oga::XML::Document] parsed DOM document
    def oga(url)
      @doc = Oga.parse_html(Net::HTTP.get_response(URI.parse(url)).body)
    end

    # Extracts the page title from the previously fetched DOM.
    #
    # @return [String, nil] the text inside the <title> tag or nil if absent
    def title
      return unless @doc

      node = @doc.at_xpath("//title")
      node&.text
    end
  end
end
