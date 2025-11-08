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
      text.gsub!(/\[([^\]]+)\]\(([^)]+)\)/, '\1')
      text.gsub!(/^\s*(?:[-+*>]|\d+\.)\s+/, "")
      text.gsub!(/[\*_`]/, "")
      text.gsub!(/^#+\s*/, "")
      text.strip
    end
  end
end
