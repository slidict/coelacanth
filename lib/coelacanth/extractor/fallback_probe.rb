# frozen_string_literal: true

require "oga"

require_relative "utilities"

module Coelacanth
  # Attempts final recovery strategies when all other probes fail.
  class ExtractorFallbackProbe
      Result = Struct.new(
        :title,
        :node,
        :published_at,
        :byline,
        :source_tag,
        :confidence,
        keyword_init: true
      )

      def call(doc:, url: nil)
        body = doc.at_css("body") || doc
        Result.new(
          title: doc.at_css("title")&.text&.strip,
          node: body,
          published_at: nil,
          byline: nil,
          source_tag: :fallback,
          confidence: 0.35
        )
      end
    end
end
