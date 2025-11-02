# frozen_string_literal: true

require_relative "utilities"

module Coelacanth
  class Extractor
    # Identifies sidebar or inline news listings and returns link arrays.
    class ListingCollector
      CANDIDATE_SELECTOR = "aside, section, div, ul, ol, dl".freeze
      MIN_ITEMS = 3
      MIN_TITLE_LENGTH = 2

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
        return true if nested_listing_container?(node)

        return false unless primary_node
        return false unless primary_node.respond_to?(:name)
        return false if %w[body html].include?(primary_node.name)

        node == primary_node ||
          ancestor?(node, primary_node) ||
          ancestor?(primary_node, node)
      end

      def nested_listing_container?(node)
        Utilities.ancestors(node).any? do |ancestor|
          Utilities.element?(ancestor) && LISTING_CONTAINER_TAGS.include?(ancestor.name)
        end
      end

      LISTING_CONTAINER_TAGS = %w[aside section div ul ol dl].freeze

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
        return [] if direct_children.empty?

        anchor_children = direct_children.select { |child| contains_link?(child) }
        return anchor_children if anchor_children.length >= MIN_ITEMS

        groups = %w[li article div section p dd]

        groups.each do |tag|
          grouped = direct_children.select { |child| child.name == tag }
          return grouped if grouped.length >= MIN_ITEMS
        end

        list_container = direct_children.find { |child| %w[ul ol dl].include?(child.name) }
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
        snippet_from_node_text(node, title) || metadata_context(node, title)
      end

      def snippet_from_node_text(node, title)
        text = normalize_text(node.text)
        snippet = text.sub(title, "").strip
        snippet.empty? ? nil : truncate(snippet)
      end

      def metadata_context(node, title)
        candidate = time_text(node) || preceding_metadata(node)
        return nil if candidate.nil?

        candidate = candidate.sub(title, "").strip
        candidate.empty? ? nil : truncate(candidate)
      end

      def time_text(node)
        node.css("time").filter_map { |time| normalize_text(time.text) }.find { |text| !text.empty? }
      end

      def preceding_metadata(node)
        previous = Utilities.previous_element(node)
        3.times do
          break unless previous

          text = normalize_text(previous.text)
          return text unless text.empty?

          previous = Utilities.previous_element(previous)
        end

        nil
      end

      def truncate(text)
        return text if text.length <= 120

        text[0...117] + "..."
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
        structure_score = structural_score(node)
        heading_score = heading ? 45 : 0
        item_score = items.length * 40
        density_score = Utilities.link_density(node) * 90
        adjacency_score = sibling_sequence_bonus(node)
        depth_penalty = Utilities.depth(node) * 5
        length_penalty = long_text_penalty(node)

        structure_score + heading_score + item_score + density_score + adjacency_score - depth_penalty - length_penalty
      end

      def structural_score(node)
        children = candidate_children(node)
        return 0 if children.empty?

        dominant_tag, dominant_children = children.group_by(&:name).max_by { |_, nodes| nodes.length }
        dominant_count = dominant_children.length

        uniform_bonus = dominant_count == children.length ? 60 : 20
        list_bonus = %w[ul ol dl].include?(node.name) ? 90 : 0
        list_bonus += 45 if dominant_tag && %w[li dd].include?(dominant_tag)

        distribution_bonus = distribution_consistency_bonus(children)

        dominant_count * 12 + uniform_bonus + list_bonus + distribution_bonus
      end

      def distribution_consistency_bonus(children)
        return 0 if children.length < MIN_ITEMS

        lengths = children.map { |child| Utilities.text_length(child) }
        average = lengths.sum.to_f / lengths.length
        variance = lengths.map { |len| (len - average).abs }

        variance.max <= 120 ? 40 : 10
      end

      def sibling_sequence_bonus(node)
        siblings = Utilities.sibling_elements(node)
        return 0 if siblings.empty?

        index = siblings.index(node)
        return 0 unless index

        forward = 0
        while (candidate = siblings[index + forward + 1]) && similar_structure?(node, candidate)
          forward += 1
        end

        backward = 0
        while index - backward - 1 >= 0 && (candidate = siblings[index - backward - 1]) && similar_structure?(node, candidate)
          backward += 1
        end

        (forward + backward) * 15
      end

      def similar_structure?(node, other)
        return false unless other

        node_children = candidate_children(node)
        other_children = candidate_children(other)
        return false if node_children.empty? || other_children.empty?

        node_children.first.name == other_children.first.name && node_children.length == other_children.length
      end

      def long_text_penalty(node)
        children = candidate_children(node)
        return 0 if children.empty?

        overlong = children.count { |child| Utilities.text_length(child) > 280 }
        overlong * 30
      end

      def minimum_score
        180
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
