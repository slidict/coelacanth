# frozen_string_literal: true

require "spec_helper"
require "json"

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
      expect(result[:body_markdown_list]).to eq(["Structured article body."])
      expect(result[:listings]).to eq([])
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
      expect(result[:body_markdown_list]).to include("# Heading")
      expect(result[:body_markdown_list]).to include("This is the first paragraph of the article body.")
      expect(result[:confidence]).to be >= 0.75
      expect(result[:listings]).to eq([])
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
      expect(result[:body_markdown_list]).to include("Machine learning fallback body.")
      expect(result[:confidence]).to be >= 0.45
      expect(result[:listings]).to eq([])
    end
  end

  describe "YouTube preprocessing" do
    let(:youtube_html) do
      <<~HTML
        <html>
          <body>
            <article>
              <p>Original YouTube body.</p>
            </article>
          </body>
        </html>
      HTML
    end

    let(:youtube_url) { "https://www.youtube.com/watch?v=example123" }
    let(:config_double) { instance_double(Coelacanth::Configure) }

    before do
      allow(Coelacanth).to receive(:config).and_return(config_double)
    end

    it "replaces the document with YouTube API data when configured" do
      api_response_body = {
        "items" => [
          {
            "snippet" => {
              "title" => "Sample Video",
              "description" => "First paragraph.\n\nSecond line one\nSecond line two.",
              "publishedAt" => "2024-04-05T09:30:00Z",
              "thumbnails" => {
                "high" => { "url" => "https://img.youtube.com/sample/high.jpg" }
              }
            }
          }
        ]
      }.to_json

      response = instance_double(Net::HTTPOK, body: api_response_body)
      allow(response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)

      allow(config_double).to receive(:read).with("youtube.api_key").and_return("test_api_key")
      allow(Coelacanth::HTTP).to receive(:raw_get_response).and_return(response)

      result = extractor.call(html: youtube_html, url: youtube_url)

      expect(result[:title]).to eq("Sample Video")
      expect(result[:published_at]).to eq(Time.utc(2024, 4, 5, 9, 30, 0))
      expect(result[:source]).to eq(:jsonld)
      expect(result[:body_markdown]).to include("First paragraph.")
      expect(result[:body_markdown]).to include("Second line one")
      expect(result[:images]).to include(include(src: "https://img.youtube.com/sample/high.jpg"))
    end

    it "falls back to the original HTML when the API key is missing" do
      allow(config_double).to receive(:read).with("youtube.api_key").and_return("")
      expect(Coelacanth::HTTP).not_to receive(:raw_get_response)

      result = extractor.call(html: youtube_html, url: youtube_url)

      expect(result[:body_markdown]).to include("Original YouTube body.")
    end
  end

  describe "listing extraction" do
    it "extracts listings from body markdown" do
      html = <<~HTML
        <html>
          <body>
            <article>
              <h1>Primary headline</h1>
              <p>Article body paragraph one.</p>
              <p>Article body paragraph two.</p>
              <h2>Latest news</h2>
              <ul>
                <li><a href="/news/1">Breaking: Major announcement</a> – Company A unveils a new product</li>
                <li><a href="/news/2">Update: Market recap</a> – Indexes closed higher across the board</li>
                <li><a href="/news/3">New: Technology spotlight</a> – Analysts unpack the latest AI research</li>
              </ul>
            </article>
          </body>
        </html>
      HTML

      result = extractor.call(html: html, url: "https://example.com/articles/1")

      expect(result[:listings]).to contain_exactly(
        {
          heading: "Latest news",
          items: [
            {
              title: "Breaking: Major announcement",
              url: "https://example.com/news/1",
              snippet: "Company A unveils a new product"
            },
            {
              title: "Update: Market recap",
              url: "https://example.com/news/2",
              snippet: "Indexes closed higher across the board"
            },
            {
              title: "New: Technology spotlight",
              url: "https://example.com/news/3",
              snippet: "Analysts unpack the latest AI research"
            }
          ]
        }
      )
    end

    it "ignores lists with fewer than three items" do
      html = <<~HTML
        <html>
          <body>
            <article>
              <h1>デジタル庁テスト</h1>
              <p>本文です。</p>
              <h2>関連リンク</h2>
              <ul>
                <li><a href="/news/10">デジタル庁の最新発表</a></li>
                <li><a href="/news/11">マイナンバー関連の更新</a></li>
              </ul>
            </article>
          </body>
        </html>
      HTML

      result = extractor.call(html: html, url: "https://www.digital.go.jp/")

      expect(result[:listings]).to eq([])
    end
  end
end
