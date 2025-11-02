# frozen_string_literal: true

require_relative "extractor/normalizer"
require_relative "extractor/metadata_probe"
require_relative "extractor/heuristic_probe"
require_relative "extractor/weak_ml_probe"
require_relative "extractor/fallback_probe"
require_relative "extractor/markdown_renderer"
require_relative "extractor/image_collector"

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

    def call(html:, url: nil)
      document = Normalizer.new.call(html: html, base_url: url)

      [
        [MetadataProbe.new, 0.85],
        [HeuristicProbe.new, 0.75],
        [WeakMlProbe.new, 0.70],
        [FallbackProbe.new, 0.0]
      ].each do |probe, threshold|
        result = probe.call(doc: document, url: url)
        next unless result

        return build_response(result) if result.confidence.to_f >= threshold
      end

      build_response(PipelineResult.new(node: document, source_tag: :none, confidence: 0.0))
    end

    private

    def build_response(result)
      node = result.node
      {
        title: result.title,
        body_markdown: MarkdownRenderer.render(node),
        images: ImageCollector.new.call(node),
        published_at: result.published_at,
        byline: result.byline,
        source: result.source_tag,
        confidence: result.confidence
      }
    end
  end
end
