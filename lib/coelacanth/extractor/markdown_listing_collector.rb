# frozen_string_literal: true

require_relative "utilities"

module Coelacanth
  class Extractor
    # Extracts structured listings from Markdown content.
    class MarkdownListingCollector
      LIST_ITEM_PATTERN = /\A(?:[-*+]|\d+\.)\s+/.freeze
      HEADING_PATTERN = /\A#+\s*/.freeze
      MIN_ITEMS = 3
      MIN_TITLE_LENGTH = 2

      def call(markdown:, base_url: nil)
        return [] if markdown.to_s.strip.empty?

        listings = []
        current = nil
        pending_heading = nil

        finalize_current = lambda do
          next unless current

          if current[:items].length >= MIN_ITEMS
            listings << { heading: current[:heading], items: current[:items] }
          end

          current = nil
        end

        markdown.each_line do |line|
          stripped = line.strip

          if stripped.empty?
            finalize_current.call
            next
          end

          if heading_line?(stripped)
            finalize_current.call
            pending_heading = normalize_heading(stripped)
            next
          end

          if list_item_line?(stripped)
            current ||= { heading: pending_heading, items: [] }
            pending_heading = nil

            if (item = build_item(stripped, base_url))
              current[:items] << item
            end
          else
            finalize_current.call
            pending_heading = nil
          end
        end

        finalize_current.call

        listings
      end

      private

      def heading_line?(line)
        line.start_with?("#") && line.match?(HEADING_PATTERN)
      end

      def list_item_line?(line)
        line.match?(LIST_ITEM_PATTERN)
      end

      def normalize_heading(line)
        line.sub(HEADING_PATTERN, "").strip
      end

      def build_item(line, base_url)
        content = line.sub(LIST_ITEM_PATTERN, "").strip
        return if content.empty?

        if (match = content.match(/\A\[([^\]]+)\]\(([^\)]+)\)(.*)\z/))
          title = match[1].to_s.strip
          href = match[2].to_s.strip
          trailing = match[3].to_s.strip

          return if title.length < MIN_TITLE_LENGTH

          url = Utilities.absolute_url(base_url, href) || href
          item = { title: title, url: url }

          snippet = normalize_snippet(trailing)
          item[:snippet] = snippet unless snippet.nil? || snippet.empty?
          item
        else
          title = content
          return if title.length < MIN_TITLE_LENGTH

          { title: title }
        end
      end

      def normalize_snippet(text)
        stripped = text.to_s.sub(/\A[-–—:]\s*/, "").strip
        stripped.empty? ? nil : stripped
      end
    end
  end
end
