# frozen_string_literal: true

require "time"
require "uri"

module Coelacanth
  class Extractor
    # Shared helpers for the extractor pipeline.
    module Utilities
      PUNCTUATION = %w[。 、 ． ・ . , ! ? ： ； ; :]

      module_function

      def text_length(node)
        node&.text&.strip&.length.to_i
      end

      def link_text_length(node)
        return 0 unless node

        node.css("a").sum { |anchor| anchor.text.strip.length }
      end

      def punctuation_density(node)
        length = text_length(node)
        return 0.0 if length.zero?

        count = node.text.chars.count { |char| PUNCTUATION.include?(char) }
        count.to_f / length
      end

      def link_density(node)
        length = text_length(node)
        return 0.0 if length.zero?

        link_text_length(node).to_f / length
      end

      def depth(node)
        ancestors(node).length
      end

      def ancestors(node)
        return [] unless node

        if node.respond_to?(:ancestors)
          Array(node.ancestors)
        else
          collect_ancestors(node)
        end
      end

      def collect_ancestors(node)
        ancestors = []
        current = node

        while current.respond_to?(:parent) && (current = current.parent)
          ancestors << current
        end

        ancestors
      end

      def element?(node)
        return false unless node

        if node.respond_to?(:element?)
          node.element?
        elsif defined?(::Oga::XML::Element) && node.is_a?(::Oga::XML::Element)
          true
        elsif node.respond_to?(:type)
          node.type == :element
        else
          false
        end
      end

      def element_children(node)
        return [] unless node.respond_to?(:children)

        node.children.select { |child| element?(child) }
      end

      def sibling_elements(node)
        parent = node.respond_to?(:parent) ? node.parent : nil
        return [] unless parent

        element_children(parent)
      end

      def previous_element(node)
        siblings = sibling_elements(node)
        index = siblings.index(node)
        return unless index && index.positive?

        siblings[index - 1]
      end

      def next_element(node)
        siblings = sibling_elements(node)
        index = siblings.index(node)
        return unless index

        siblings[index + 1]
      end

      def class_id_tokens(node)
        tokens = []
        tokens.concat(split_tokens(node[:class])) if node[:class]
        tokens.concat(split_tokens(node[:id])) if node[:id]
        tokens
      end

      def split_tokens(value)
        value.to_s.split(/[\s_-]+/).map(&:downcase)
      end

      def meta_content(doc, *selectors)
        selectors.each do |selector|
          if (node = doc.at_css(selector))
            return node["content"].to_s.strip unless node["content"].to_s.strip.empty?
          end
        end
        nil
      end

      def parse_time(value)
        return if value.nil? || value.empty?

        Time.parse(value)
      rescue ArgumentError
        nil
      end

      def absolute_url(base_url, path)
        return if path.nil? || path.empty?
        return path if path =~ /^https?:/i

        URI.join(base_url, path).to_s
      rescue URI::Error
        path
      end
    end
  end
end
