# frozen_string_literal: true

require "json"
require "oga"

require_relative "utilities"

module Coelacanth
  class Extractor
    # Attempts to pull article metadata such as JSON-LD and OpenGraph tags.
    class MetadataProbe
      ARTICLE_TYPES = %w[Article NewsArticle BlogPosting ReportageNewsArticle LiveBlogPosting].freeze

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
        from_jsonld(doc, url) || from_semantic_nodes(doc)
      end

      private

      def from_jsonld(doc, url)
        doc.css("script[type='application/ld+json']").each do |script|
          next if script.text.strip.empty?

          begin
            payload = JSON.parse(script.text)
          rescue JSON::ParserError
            next
          end

          candidates = payload.is_a?(Array) ? payload : [payload]
          candidates.each do |candidate|
            next unless article_type?(candidate)

            body = candidate["articleBody"].to_s.strip
            next if body.empty?

            node = Oga.parse_html("<article>#{body}</article>").at_css("article")
            return Result.new(
              title: candidate["headline"] || candidate["name"],
              node: node,
              published_at: Utilities.parse_time(candidate["datePublished"] || candidate["dateCreated"]),
              byline: extract_author(candidate["author"]),
              source_tag: :jsonld,
              confidence: 0.9
            )
          end
        end
        nil
      end

      def from_semantic_nodes(doc)
        node = doc.at_css("main, article, [role='main'], [itemprop='articleBody']")
        return if node.nil?

        Result.new(
          title: title_from_meta(doc),
          node: node,
          published_at: published_at_from_meta(doc),
          byline: byline_from_meta(doc),
          source_tag: :semantic,
          confidence: 0.82
        )
      end

      def article_type?(candidate)
        type = candidate["@type"]
        Array(type).any? { |value| ARTICLE_TYPES.include?(value) }
      end

      def extract_author(author)
        case author
        when String
          author
        when Hash
          author["name"]
        when Array
          author.map { |item| extract_author(item) }.compact.join(", ")
        end
      end

      def title_from_meta(doc)
        Utilities.meta_content(
          doc,
          "meta[property='og:title']",
          "meta[name='twitter:title']",
          "meta[name='title']"
        ) || doc.at_css("title")&.text&.strip
      end

      def published_at_from_meta(doc)
        Utilities.parse_time(
          Utilities.meta_content(
            doc,
            "meta[property='article:published_time']",
            "meta[name='pubdate']",
            "meta[name='publish_date']",
            "meta[name='date']"
          )
        )
      end

      def byline_from_meta(doc)
        Utilities.meta_content(
          doc,
          "meta[name='author']",
          "meta[property='article:author']"
        )
      end
    end
  end
end
