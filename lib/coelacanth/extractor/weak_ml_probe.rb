# frozen_string_literal: true

require "oga"

require_relative "utilities"

module Coelacanth
  # Lightweight probabilistic scorer that emulates a learned classifier using heuristics.
  class ExtractorWeakMlProbe
      Result = Struct.new(
        :title,
        :node,
        :published_at,
        :byline,
        :source_tag,
        :confidence,
        keyword_init: true
      )

      BLOCK_SELECTOR = "article, main, section, div".freeze
      TOKEN_WEIGHTS = {
        "content" => 1.1,
        "article" => 1.0,
        "body" => 0.9,
        "post" => 0.8,
        "entry" => 0.75,
        "text" => 0.6,
        "story" => 0.6,
        "blog" => 0.5,
        "share" => -1.0,
        "nav" => -1.3,
        "footer" => -1.2,
        "header" => -1.1,
        "related" => -0.8
      }.freeze

      FEATURE_WEIGHTS = {
        bias: -1.2,
        text_length: 0.002,
        link_density: -2.6,
        punctuation_density: 1.8,
        depth: -0.12,
        token_score: 1.6
      }.freeze

      def call(doc:, url: nil)
        candidates = doc.css(BLOCK_SELECTOR).map do |node|
          evaluate(node)
        end.compact

        return if candidates.empty?

        best = candidates.max_by { |candidate| candidate[:probability] }
        return if best[:probability] < 0.45

        Result.new(
          title: title_from_meta(doc),
          node: best[:node],
          published_at: published_at_from_meta(doc),
          byline: byline_from_meta(doc),
          source_tag: :ml,
          confidence: best[:probability].clamp(0.0, 0.9)
        )
      end

      private

      def evaluate(node)
        text_length = ExtractorUtilities.text_length(node)
        return if text_length < 60

        features = {
          text_length: text_length,
          link_density: ExtractorUtilities.link_density(node),
          punctuation_density: ExtractorUtilities.punctuation_density(node),
          depth: ExtractorUtilities.depth(node),
          token_score: token_score(node)
        }

        score = linear_combination(features)
        probability = logistic(score)

        { node: node, probability: probability }
      end

      def token_score(node)
        ExtractorUtilities.class_id_tokens(node).sum do |token|
          TOKEN_WEIGHTS.fetch(token, 0.0)
        end
      end

      def linear_combination(features)
        FEATURE_WEIGHTS[:bias] +
          FEATURE_WEIGHTS[:text_length] * features[:text_length] +
          FEATURE_WEIGHTS[:link_density] * features[:link_density] +
          FEATURE_WEIGHTS[:punctuation_density] * features[:punctuation_density] +
          FEATURE_WEIGHTS[:depth] * features[:depth] +
          FEATURE_WEIGHTS[:token_score] * features[:token_score]
      end

      def logistic(score)
        1.0 / (1.0 + Math.exp(-score))
      end

      def title_from_meta(doc)
        ExtractorUtilities.meta_content(
          doc,
          "meta[property='og:title']",
          "meta[name='twitter:title']",
          "meta[name='title']"
        ) || doc.at_css("title")&.text&.strip
      end

      def published_at_from_meta(doc)
        ExtractorUtilities.parse_time(
          ExtractorUtilities.meta_content(
            doc,
            "meta[property='article:published_time']",
            "meta[name='pubdate']",
            "meta[name='publish_date']",
            "meta[name='date']"
          )
        )
      end

      def byline_from_meta(doc)
        ExtractorUtilities.meta_content(
          doc,
          "meta[name='author']",
          "meta[property='article:author']"
        )
      end
    end
end
