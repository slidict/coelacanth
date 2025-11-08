# frozen_string_literal: true

require_relative "extractor/preprocessor"
require_relative "extractor/normalizer"
require_relative "extractor/metadata_probe"
require_relative "extractor/heuristic_probe"
require_relative "extractor/weak_ml_probe"
require_relative "extractor/fallback_probe"
require_relative "extractor/markdown_renderer"
require_relative "extractor/image_collector"
require_relative "extractor/markdown_listing_collector"
require_relative "extractor/eyecatch_image_extractor"
require_relative "extractor/morphological_analyzer"
require_relative "extractor/utilities"

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
      preprocessed_html = Preprocessor.new.call(html: html, url: url)
      document = Normalizer.new.call(html: preprocessed_html, base_url: url)

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
      body_morphemes = MorphologicalAnalyzer.new(config: Coelacanth.config).call(
        node: node,
        title: result.title,
        markdown: body_markdown
      )

      site_name = extract_site_name(document)
      body_text = extract_body_text(node)

      {
        title: result.title,
        body_markdown: body_markdown,
        body_markdown_list: body_markdown_list,
        body_morphemes: body_morphemes,
        images: ImageCollector.new.call(node),
        eyecatch_image: EyecatchImageExtractor.new.call(doc: document, base_url: url),
        published_at: result.published_at,
        byline: result.byline,
        source: result.source_tag,
        confidence: result.confidence,
        listings: MarkdownListingCollector.new.call(markdown: body_markdown, base_url: url),
        site_name: site_name,
        body_text: body_text,
        response_metadata: response_metadata || {}
      }
    end

    def extract_site_name(document)
      Utilities.meta_content(
        document,
        "meta[property='og:site_name']",
        "meta[name='application-name']",
        "meta[name='apple-mobile-web-app-title']",
        "meta[name='twitter:site']"
      ) || document.at_css("title")&.text&.strip
    end

    def extract_body_text(node)
      return if node.nil?

      node.text.to_s.gsub(/\s+/, " ").strip
    end
  end
end
