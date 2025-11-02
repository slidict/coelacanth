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
        case node.type
        when :document
          node.children.flat_map { |child| traverse(child, depth) }
        when :element
          render_element(node, depth)
        when :text
          text = node.text.strip
          text.empty? ? nil : text
        else
          nil
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
          node.children.select(&:element?).flat_map { |child| render_list_item(child, depth, "-") } + [""]
        when "ol"
          node.children.select(&:element?).each_with_index.flat_map do |child, index|
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
    end
  end
end
