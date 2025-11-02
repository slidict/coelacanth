# frozen_string_literal: true

require_relative "utilities"

module Coelacanth
  class Extractor
    # Identifies sidebar or inline news listings and returns link arrays.
    class ListingCollector
      CANDIDATE_SELECTOR = "aside, section, div, ul, ol".freeze
      MIN_ITEMS = 3
      MIN_TITLE_LENGTH = 6

      POSITIVE_TOKENS = %w[news latest new headlines topics pickup digest list updates hot trending feed article posts breaking].freeze
      POSITIVE_TOKENS_JA = %w[ニュース 新着 最新 注目 速報 トピックス トピック 特集 記事 まとめ].freeze
      NEGATIVE_TOKENS = %w[footer share comment comments sns tag tags breadcrumb search subscribe login author category categories hero heroimage].freeze
      NEGATIVE_TOKENS_JA = %w[フッター シェア コメント 関連 検索 メニュー ログイン 会員].freeze

      HEADING_TOKENS = %w[news latest new headlines updates digest].freeze
      HEADING_TOKENS_JA = %w[新着 最新 速報 ニュース トピックス トピック 注目].freeze

      def call(document:, base_url: nil, primary_node: nil)
        candidates = collect_candidates(document, base_url, primary_node)

        candidates
          .sort_by { |candidate| -candidate[:score] }
          .reject { |candidate| candidate[:score] < minimum_score }
          .first(3)
          .map { |candidate| format_candidate(candidate) }
      end

      private

      def collect_candidates(document, base_url, primary_node)
        document.css(CANDIDATE_SELECTOR).filter_map do |node|
          next if skip_node?(node, primary_node)

          items = extract_items(node, base_url)
          next if items.length < MIN_ITEMS

          heading = heading_for(node)
          score = score_node(node, items, heading)
          next if score < minimum_score

          { node: node, items: items, heading: heading, score: score }
        end
      end

      def skip_node?(node, primary_node)
        return false unless primary_node

        node == primary_node ||
          ancestor?(node, primary_node) ||
          ancestor?(primary_node, node)
      end

      def ancestor?(node, candidate)
        Utilities.ancestors(node).any? { |ancestor| ancestor == candidate }
      end

      def extract_items(node, base_url)
        item_nodes = candidate_children(node)
        return [] if item_nodes.empty?

        item_nodes.filter_map do |child|
          next unless contains_link?(child)

          anchor = primary_anchor(child)
          next unless anchor

          title = normalize_text(anchor.text)
          next if title.length < MIN_TITLE_LENGTH

          href = anchor["href"].to_s.strip
          next if href.empty?

          url = base_url ? Utilities.absolute_url(base_url, href) : href
          url ||= href

          snippet = build_snippet(child, title)

          item = { title: title, url: url }
          item[:snippet] = snippet unless snippet.nil? || snippet.empty?
          item
        end.uniq { |item| [item[:title], item[:url]] }
      end

      def candidate_children(node)
        direct_children = Utilities.element_children(node)
        groups = %w[li article div section p]

        groups.each do |tag|
          grouped = direct_children.select { |child| child.name == tag }
          return grouped if grouped.length >= MIN_ITEMS
        end

        list_container = direct_children.find { |child| %w[ul ol].include?(child.name) }
        return Utilities.element_children(list_container) if list_container

        []
      end

      def contains_link?(node)
        node.css("a[href]").any?
      end

      def primary_anchor(node)
        anchors = node.css("a[href]")
        anchors.max_by { |anchor| normalize_text(anchor.text).length }
      end

      def normalize_text(text)
        text.to_s.gsub(/[\r\n\t]/, " ").squeeze(" ").strip
      end

      def build_snippet(node, title)
        text = normalize_text(node.text)
        snippet = text.sub(title, "").strip
        snippet.empty? ? nil : snippet
      end

      def heading_for(node)
        if (heading = node.at_css("h1, h2, h3, h4"))
          return normalize_text(heading.text)
        end

        previous = Utilities.previous_element(node)
        3.times do
          break unless previous

          return normalize_text(previous.text) if previous.name =~ /h[1-6]/
          previous = Utilities.previous_element(previous)
        end

        nil
      end

      def score_node(node, items, heading)
        item_score = items.length * 40
        token_score = class_token_score(node)
        heading_score = heading_bonus(heading)
        density_score = Utilities.link_density(node) * 100
        depth_penalty = Utilities.depth(node) * 5
        length_penalty = long_text_penalty(node)

        item_score + token_score + heading_score + density_score - depth_penalty - length_penalty
      end

      def class_token_score(node)
        tokens = Utilities.class_id_tokens(node)
        score = 0

        tokens.each do |token|
          score += 35 if POSITIVE_TOKENS.include?(token)
          score -= 50 if NEGATIVE_TOKENS.include?(token)
        end

        POSITIVE_TOKENS_JA.each do |token|
          score += 35 if node[:class].to_s.include?(token) || node[:id].to_s.include?(token)
        end

        NEGATIVE_TOKENS_JA.each do |token|
          score -= 50 if node[:class].to_s.include?(token) || node[:id].to_s.include?(token)
        end

        score
      end

      def heading_bonus(heading)
        return 0 unless heading

        normalized = heading.downcase
        score = 0

        HEADING_TOKENS.each do |token|
          score += 45 if normalized.include?(token)
        end

        HEADING_TOKENS_JA.each do |token|
          score += 45 if heading.include?(token)
        end

        score
      end

      def long_text_penalty(node)
        children = candidate_children(node)
        return 0 if children.empty?

        overlong = children.count { |child| Utilities.text_length(child) > 280 }
        overlong * 30
      end

      def minimum_score
        120
      end

      def format_candidate(candidate)
        {
          heading: candidate[:heading],
          items: candidate[:items]
        }
      end
    end
  end
end
