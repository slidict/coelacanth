# frozen_string_literal: true

require "oga"

require_relative "utilities"

module Coelacanth
  # Scores DOM nodes based on simple heuristics to locate the primary article body.
  class ExtractorHeuristicProbe
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
      TAG_WEIGHTS = Hash.new(0).merge(
        "article" => 80,
        "main" => 60,
        "section" => 30,
        "div" => 10
      ).freeze
      NEGATIVE_TOKENS = %w[nav footer header sidebar related share menu].freeze
      POSITIVE_TOKENS = %w[content article body post entry text].freeze

      def call(doc:, url: nil)
        candidates = doc.css(BLOCK_SELECTOR).map do |node|
          score_candidate(node)
        end.compact

        return if candidates.empty?

        best = candidates.max_by { |candidate| candidate[:score] }
        return if best[:score] < 120

        Result.new(
          title: title_from_meta(doc),
          node: expand(best[:node]),
          published_at: published_at_from_meta(doc),
          byline: byline_from_meta(doc),
          source_tag: :heuristic,
          confidence: confidence(best[:score])
        )
      end

      private

      def score_candidate(node)
        text_length = ExtractorUtilities.text_length(node)
        return if text_length < 80

        link_density = ExtractorUtilities.link_density(node)
        punct_density = ExtractorUtilities.punctuation_density(node)
        tag_weight = TAG_WEIGHTS[node.name]
        class_weight = class_score(node)
        depth_penalty = ExtractorUtilities.depth(node) * 4
        sibling_bonus = sibling_variance(node)

        score = (
          text_length * 0.35 +
          punct_density * 280 -
          link_density * 160 +
          tag_weight +
          class_weight +
          sibling_bonus -
          depth_penalty
        )

        { node: node, score: score }
      end

      def class_score(node)
        tokens = ExtractorUtilities.class_id_tokens(node)
        score = tokens.count { |token| POSITIVE_TOKENS.include?(token) } * 40
        score -= tokens.count { |token| NEGATIVE_TOKENS.include?(token) } * 60
        score
      end

      def sibling_variance(node)
        parent = node.parent
        return 0 unless parent

        siblings = parent.children.select { |child| child.is_a?(Oga::XML::Element) }
        return 0 if siblings.length < 2

        lengths = siblings.map { |sibling| ExtractorUtilities.text_length(sibling) }
        mean = lengths.sum.to_f / lengths.length
        variance = lengths.map { |length| (length - mean)**2 }.sum.to_f / lengths.length
        Math.sqrt(variance) * 0.25
      end

      def expand(node)
        return node unless node.parent

        before = neighboring_nodes(node, -1).reverse
        after = neighboring_nodes(node, 1)

        wrap_fragment(before + [node] + after)
      end

      def neighboring_nodes(node, direction)
        siblings = []
        current = node
        loop do
          current = direction.negative? ? current.previous_element : current.next_element
          break unless current

          break unless include_in_expansion?(current)

          siblings << current
        end
        siblings
      end

      def include_in_expansion?(node)
        %w[h1 h2 h3 h4 h5 h6 img blockquote p ul ol figure].include?(node.name)
      end

      def wrap_fragment(nodes)
        container = Oga::XML::Element.new(name: "article")
        nodes.each { |node| container.children << node }
        container
      end

      def confidence(score)
        value = 1.0 / (1.0 + Math.exp(-(score - 140) / 90.0))
        value.clamp(0.0, 0.95)
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
