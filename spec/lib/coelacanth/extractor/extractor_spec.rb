# frozen_string_literal: true

require "spec_helper"

RSpec.describe Coelacanth::Extractor do
  subject(:extractor) { described_class.new }

  describe "metadata extraction" do
    let(:html) do
      <<~HTML
        <html>
          <head>
            <title>Ignored title</title>
            <script type="application/ld+json">
              {
                "@context": "https://schema.org",
                "@type": "NewsArticle",
                "headline": "JSON-LD Title",
                "datePublished": "2024-03-01T10:00:00Z",
                "author": { "name": "Metadata Author" },
                "articleBody": "<p>Structured article body.</p>"
              }
            </script>
          </head>
          <body>
            <article><p>Fallback body</p></article>
          </body>
        </html>
      HTML
    end

    it "returns the jsonld payload" do
      result = extractor.call(html: html, url: "https://example.com/news")

      expect(result[:source]).to eq(:jsonld)
      expect(result[:title]).to eq("JSON-LD Title")
      expect(result[:byline]).to eq("Metadata Author")
      expect(result[:confidence]).to be >= 0.85
      expect(result[:body_markdown]).to include("Structured article body")
    end
  end

  describe "heuristic extraction" do
    let(:html) do
      <<~HTML
        <html>
          <head>
            <title>Sample article</title>
            <meta property="article:published_time" content="2024-03-03T12:00:00Z" />
            <meta name="author" content="Heuristic Author" />
          </head>
          <body>
            <header><nav>Navigation</nav></header>
            <div class="content">
              <h1>Heading</h1>
              <p>This is the first paragraph of the article body.</p>
              <p>This is the second paragraph containing additional information.</p>
              <p>Here is another sentence with more detail.</p>
            </div>
            <footer>Footer text</footer>
          </body>
        </html>
      HTML
    end

    it "scores the main block and renders markdown" do
      result = extractor.call(html: html, url: "https://example.com/heuristic")

      expect(result[:source]).to eq(:heuristic)
      expect(result[:title]).to eq("Sample article")
      expect(result[:byline]).to eq("Heuristic Author")
      expect(result[:body_markdown]).to include("This is the first paragraph")
      expect(result[:confidence]).to be >= 0.75
    end
  end

  describe "weak ml fallback" do
    let(:html) do
      <<~HTML
        <html>
          <head>
            <title>ML Article</title>
          </head>
          <body>
            <section id="post-body" class="post body">
              <p>Machine learning fallback body.</p>
              <p>Additional content to boost the score.</p>
            </section>
          </body>
        </html>
      HTML
    end

    it "uses the weak ML probe when heuristics are insufficient" do
      allow_any_instance_of(Coelacanth::Extractor::HeuristicProbe).to receive(:call).and_return(nil)

      result = extractor.call(html: html, url: "https://example.com/ml")

      expect(result[:source]).to eq(:ml)
      expect(result[:body_markdown]).to include("Machine learning fallback body")
      expect(result[:confidence]).to be >= 0.45
    end
  end
end
