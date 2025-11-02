# frozen_string_literal: true

require "oga"

require_relative "utilities"

module Coelacanth
  module Extractor
    # Sanitizes HTML and prepares an Oga document.
    class Normalizer
      REMOVABLE_SELECTORS = %w[script style noscript iframe form nav aside].freeze

      def call(html:, base_url: nil)
        document = Oga.parse_html(html)
        remove_noise(document)
        normalize_images(document, base_url)
        document
      end

      private

      def remove_noise(document)
        REMOVABLE_SELECTORS.each do |selector|
          document.css(selector).each(&:remove)
        end
      end

      def normalize_images(document, base_url)
        return unless base_url

        document.css("img").each do |image|
          src = image["src"].to_s.strip
          next if src.empty?

          absolute = Utilities.absolute_url(base_url, src)
          image.set("src", absolute) if absolute
        end
      end
    end
  end
end
