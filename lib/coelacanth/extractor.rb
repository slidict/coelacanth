# frozen_string_literal: true

require_relative "extractor/normalizer"
require_relative "extractor/metadata_probe"
require_relative "extractor/heuristic_probe"
require_relative "extractor/weak_ml_probe"
require_relative "extractor/fallback_probe"
require_relative "extractor/markdown_renderer"
require_relative "extractor/image_collector"
require_relative "extractor/markdown_listing_collector"

module Coelacanth
  # High-level API for extracting articles without site-specific selectors.
  class Extractor
    PipelineResult = Struct.new(
      :title,
      :node,
      :published_at,
      :byline,
      :source_tag,
      :confidence,
      keyword_init: true
    )

    def call(html:, url: nil, response_metadata: nil)
      document = Normalizer.new.call(html: html, base_url: url)

      [
        [MetadataProbe.new, 0.85],
        [HeuristicProbe.new, 0.75],
        [WeakMlProbe.new, 0.70],
        [FallbackProbe.new, 0.0]
      ].each do |probe, threshold|
        result = probe.call(doc: document, url: url)
        next unless result

        return build_response(result, document:, url:, response_metadata: response_metadata) if result.confidence.to_f >= threshold
      end

      build_response(
        PipelineResult.new(node: document, source_tag: :none, confidence: 0.0),
        document: document,
        url: url,
        response_metadata: response_metadata
      )
    end

    private

    def build_response(result, document:, url:, response_metadata:)
      node = result.node
      body_markdown = MarkdownRenderer.render(node)
      body_markdown_list = body_markdown.to_s.split(/\n{2,}/).map { |segment| segment.strip }.reject(&:empty?)
      body_text = derive_body_text(body_markdown, body_markdown_list)

      {
        title: result.title,
        body_markdown: body_markdown,
        body_markdown_list: body_markdown_list,
        images: ImageCollector.new.call(node),
        published_at: result.published_at,
        byline: result.byline,
        source: result.source_tag,
        confidence: result.confidence,
        listings: MarkdownListingCollector.new.call(markdown: body_markdown, base_url: url),
        site_name: extract_site_name(document),
        body_text: body_text,
        response: response_metadata
      }
    end

    def extract_site_name(document)
      return unless document

      title = document.at_css("title")&.text&.strip
      title unless title.nil? || title.empty?
    end

    def derive_body_text(body_markdown, body_markdown_list)
      return "" if body_markdown.to_s.strip.empty?

      segments = if body_markdown_list.empty?
                   body_markdown.to_s.split(/\n+/)
                 else
                   body_markdown_list
                 end

      segments
        .map { |segment| sanitize_markdown_segment(segment) }
        .reject(&:empty?)
        .join("\n\n")
    end

    def sanitize_markdown_segment(segment)
      text = segment.to_s.dup
      text.gsub!(/```.*?```/m, "")
      text = strip_markdown_links(text)
      text.gsub!(/^\s*(?:[-+*>]|\d+\.)\s+/, "")
      text.gsub!(/[\*_`]/, "")
      text.gsub!(/^#+\s*/, "")
      text.strip
    end

    def strip_markdown_links(text)
      result = +""
      index = 0

      while index < text.length
        open_bracket = text.index('[', index)

        break unless open_bracket

        result << text[index...open_bracket]
        close_bracket = find_closing_delimiter(text, open_bracket + 1, '[', ']')

        unless close_bracket
          result << text[open_bracket..]
          return result
        end

        label = text[(open_bracket + 1)...close_bracket]
        next_index = close_bracket + 1

        if text[next_index] == '('
          close_paren = find_closing_delimiter(text, next_index + 1, '(', ')')

          if close_paren
            result << decode_markdown_escapes(label)
            index = close_paren + 1
            next
          end
        end

        result << text[open_bracket...next_index]
        index = next_index
      end

      result << text[index..] if index < text.length
      result
    end

    def find_closing_delimiter(text, index, opener, closer)
      depth = 1
      escape = false

      while index < text.length
        char = text[index]

        if escape
          escape = false
        elsif char == '\\'
          escape = true
        elsif char == opener
          depth += 1
        elsif char == closer
          depth -= 1
          return index if depth.zero?
        end

        index += 1
      end

      nil
    end

    def decode_markdown_escapes(text)
      result = +""
      escape = false

      text.each_char do |char|
        if escape
          result << char
          escape = false
        elsif char == '\\'
          escape = true
        else
          result << char
        end
      end

      result << '\\' if escape
      result
    end
  end
end
