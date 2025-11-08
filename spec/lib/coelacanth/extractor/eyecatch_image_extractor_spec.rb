# frozen_string_literal: true

require "spec_helper"
require "oga"
require "fileutils"

RSpec.describe Coelacanth::Extractor::EyecatchImageExtractor do
  subject(:extractor) { described_class.new }

  let(:document) { Oga.parse_html(html) }

  describe "metadata preference" do
    let(:html) do
      <<~HTML
        <html>
          <head>
            <meta property="og:image" content="https://example.com/images/og-image.png" />
            <meta name="twitter:image" content="https://example.com/images/twitter.png" />
          </head>
          <body>
            <article>
              <img src="https://example.com/images/body.png" alt="body" />
            </article>
          </body>
        </html>
      HTML
    end

    it "downloads the Open Graph image to a temporary directory" do
      stub_request(:get, "https://example.com/images/og-image.png").to_return(
        status: 200,
        body: "PNGDATA",
        headers: { "Content-Type" => "image/png" }
      )

      result = extractor.call(doc: document, base_url: "https://example.com/article")

      expect(result).to be_a(described_class::Result)
      expect(result.url).to eq("https://example.com/images/og-image.png")
      expect(File).to exist(result.path)
      expect(File.binread(result.path)).to eq("PNGDATA")
    ensure
      FileUtils.rm_rf(File.dirname(result.path)) if result&.path && File.exist?(result.path)
    end
  end

  describe "structured data fallback" do
    let(:html) do
      <<~HTML
        <html>
          <head>
            <script type="application/ld+json">
              {
                "@context": "https://schema.org",
                "@type": "NewsArticle",
                "image": {
                  "@type": "ImageObject",
                  "url": "https://example.net/assets/json-ld-image.jpg"
                }
              }
            </script>
          </head>
          <body>
            <article>
              <p>Content</p>
            </article>
          </body>
        </html>
      HTML
    end

    it "uses images referenced in JSON-LD when metadata is missing" do
      stub_request(:get, "https://example.net/assets/json-ld-image.jpg").to_return(
        status: 200,
        body: "JSONLDDATA",
        headers: { "Content-Type" => "image/jpeg" }
      )

      result = extractor.call(doc: document, base_url: "https://example.net/story")

      expect(result).to be_a(described_class::Result)
      expect(result.url).to eq("https://example.net/assets/json-ld-image.jpg")
      expect(File.extname(result.path)).to eq(".jpg")
      expect(File.binread(result.path)).to eq("JSONLDDATA")
    ensure
      FileUtils.rm_rf(File.dirname(result.path)) if result&.path && File.exist?(result.path)
    end
  end

  describe "document heuristics" do
    let(:html) do
      <<~HTML
        <html>
          <body>
            <header>
              <img class="site-logo" src="/images/logo.png" width="120" height="60" />
            </header>
            <article>
              <figure class="hero">
                <img
                  alt="Main story hero"
                  srcset="/images/hero-small.jpg 400w, /images/hero-large.jpg 1200w"
                  width="1200"
                  height="630"
                />
              </figure>
              <p>Body text</p>
              <img class="inline-photo" src="/images/inline.jpg" width="320" height="200" />
            </article>
          </body>
        </html>
      HTML
    end

    it "prefers large hero images over decorative assets" do
      stub_request(:get, "https://example.org/images/hero-large.jpg").to_return(
        status: 200,
        body: "HERODATA",
        headers: { "Content-Type" => "image/jpeg" }
      )

      result = extractor.call(doc: document, base_url: "https://example.org/posts/1")

      expect(result).to be_a(described_class::Result)
      expect(result.url).to eq("https://example.org/images/hero-large.jpg")
      expect(File.binread(result.path)).to eq("HERODATA")
    ensure
      FileUtils.rm_rf(File.dirname(result.path)) if result&.path && File.exist?(result.path)
    end
  end

  describe "when no candidates exist" do
    let(:html) do
      <<~HTML
        <html>
          <body>
            <p>No image metadata here</p>
          </body>
        </html>
      HTML
    end

    it "returns nil" do
      result = extractor.call(doc: document, base_url: "https://example.com/none")

      expect(result).to be_nil
    end
  end
end
