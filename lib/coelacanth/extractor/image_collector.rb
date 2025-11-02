# frozen_string_literal: true

module Coelacanth
  class Extractor
    # Collects image metadata from the extracted DOM node.
    class ImageCollector
      def call(node)
        return [] unless node

        node.css("img").map do |image|
          {
            src: image["src"].to_s.strip,
            alt: image["alt"].to_s.strip
          }
        end.reject { |entry| entry[:src].empty? }
      end
    end
  end
end
