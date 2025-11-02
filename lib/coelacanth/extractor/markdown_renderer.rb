# frozen_string_literal: true

module Coelacanth
  class Extractor
    # Converts a DOM node into a lightweight Markdown representation.
    class MarkdownRenderer
      def self.render(node)
        new(node).render
      end

      def initialize(node)
        @node = node
      end

      def render
        return "" unless @node

        lines = traverse(@node)
        lines.compact.join("\n").gsub(/\n{3,}/, "\n\n")
      end

      private

      def traverse(node, depth = 0)
        return if node.nil?

        if document_node?(node)
          node.children.flat_map { |child| traverse(child, depth) }
        elsif element_node?(node)
          render_element(node, depth)
        elsif text_node?(node)
          text = node.text.to_s.strip
          text.empty? ? nil : text
        end
      end

      def render_element(node, depth)
        case node.name
        when "p"
          [node.children.flat_map { |child| traverse(child, depth) }.join(" "), ""]
        when "br"
          "\n"
        when "h1", "h2", "h3", "h4", "h5", "h6"
          level = node.name.delete_prefix("h").to_i
          heading = "#" * level + " " + inline_children(node, depth)
          [heading, ""]
        when "ul"
          element_children(node).flat_map { |child| render_list_item(child, depth, "-") } + [""]
        when "ol"
          element_children(node).each_with_index.flat_map do |child, index|
            render_list_item(child, depth, "#{index + 1}.")
          end + [""]
        when "li"
          ["- #{inline_children(node, depth)}"]
        when "strong", "b"
          "**#{inline_children(node, depth)}**"
        when "em", "i"
          "*#{inline_children(node, depth)}*"
        when "blockquote"
          quote = node.children.flat_map { |child| traverse(child, depth + 1) }.compact
          quote.map { |line| "> #{line}" } + [""]
        when "pre", "code"
          content = node.text
          ["```", content.rstrip, "```", ""]
        when "img"
          alt = node["alt"].to_s.strip
          src = node["src"].to_s.strip
          ["![#{alt}](#{src})", ""]
        else
          node.children.flat_map { |child| traverse(child, depth) }
        end
      end

      def inline_children(node, depth)
        node.children.flat_map { |child| traverse(child, depth) }.join(" ").squeeze(" ").strip
      end

      def render_list_item(node, depth, marker)
        text = inline_children(node, depth)
        return [] if text.empty?

        ["#{marker} #{text}"]
      end

      def document_node?(node)
        return false unless node

        (defined?(::Oga::XML::Document) && node.is_a?(::Oga::XML::Document)) ||
          (node.respond_to?(:document?) && node.document?) ||
          (node.respond_to?(:type) && node.type == :document)
      end

      def element_node?(node)
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

      def text_node?(node)
        return false unless node

        if node.respond_to?(:text?)
          node.text?
        elsif defined?(::Oga::XML::Text) && node.is_a?(::Oga::XML::Text)
          true
        elsif node.respond_to?(:type)
          node.type == :text
        else
          false
        end
      end

      def element_children(node)
        return [] unless node.respond_to?(:children)

        node.children.select { |child| element_node?(child) }
      end
    end
  end
end
