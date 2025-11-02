# frozen_string_literal: true

module Coelacanth
  # Converts a DOM node into a lightweight Markdown representation.
  class ExtractorMarkdownRenderer
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
        if node.is_a?(Oga::XML::Document)
          node.children.flat_map { |child| traverse(child, depth) }
        elsif node.is_a?(Oga::XML::Element)
          render_element(node, depth)
        elsif node.is_a?(Oga::XML::Text)
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
          node.children.select { |child| child.is_a?(Oga::XML::Element) }.flat_map { |child| render_list_item(child, depth, "-") } + [""]
        when "ol"
          node.children.select { |child| child.is_a?(Oga::XML::Element) }.each_with_index.flat_map do |child, index|
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
