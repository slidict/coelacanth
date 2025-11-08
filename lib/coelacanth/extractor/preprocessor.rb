# frozen_string_literal: true

require "cgi"
require "json"
require "net/http"
require "uri"

require_relative "../http"

module Coelacanth
  class Extractor
    # Applies pre-processing steps before running the main extraction pipeline.
    class Preprocessor
      def initialize(preprocessors: default_preprocessors)
        @preprocessors = preprocessors
      end

      def call(html:, url: nil)
        return html if url.nil?

        @preprocessors.each do |preprocessor|
          processed = preprocessor.call(html: html, url: url)
          return processed if processed
        end

        html
      end

      private

      def default_preprocessors
        [Preprocessors::YouTube.new]
      end

      module Preprocessors
        # Converts YouTube video pages into structured article-like HTML using the
        # YouTube Data API. This allows the downstream extractor to consume the
        # video description and thumbnail as if it were a standard article.
        class YouTube
          API_ENDPOINT = "https://www.googleapis.com/youtube/v3/videos"
          WATCH_HOSTS = %w[youtube.com www.youtube.com youtu.be m.youtube.com music.youtube.com].freeze

          def call(html:, url:)
            video_id = extract_video_id(url)
            return unless video_id

            api_key = youtube_api_key
            return if api_key.nil? || api_key.empty?

            snippet = fetch_snippet(video_id, api_key)
            return unless snippet

            build_document(snippet)
          end

          private

          def extract_video_id(url)
            uri = URI.parse(url)
            return unless WATCH_HOSTS.include?(uri.host)

            if uri.host == "youtu.be"
              uri.path.split("/").reject(&:empty?).first
            else
              params = URI.decode_www_form(uri.query.to_s).to_h
              params["v"].to_s.strip
            end
          rescue URI::InvalidURIError
            nil
          end

          def youtube_api_key
            Coelacanth.config.read("youtube.api_key").to_s.strip
          rescue StandardError
            ""
          end

          def fetch_snippet(video_id, api_key)
            uri = URI(API_ENDPOINT)
            uri.query = URI.encode_www_form(part: "snippet", id: video_id, key: api_key)

            response = Coelacanth::HTTP.raw_get_response(uri)
            return unless response.is_a?(Net::HTTPSuccess)

            payload = JSON.parse(response.body.to_s)
            payload.fetch("items", []).first&.fetch("snippet", nil)
          rescue Coelacanth::TimeoutError, JSON::ParserError, StandardError
            nil
          end

          def build_document(snippet)
            title = snippet["title"].to_s.strip
            description = snippet["description"].to_s
            published_at = snippet["publishedAt"].to_s.strip
            thumbnail_url = preferred_thumbnail(snippet["thumbnails"])

            body_html = render_description(description)
            thumbnail_markup = render_thumbnail(thumbnail_url, title)
            article_html = "#{thumbnail_markup}#{body_html}"

            jsonld = {
              "@context" => "https://schema.org",
              "@type" => "Article",
              "headline" => title,
              "datePublished" => published_at,
              "articleBody" => article_html
            }.to_json

            <<~HTML
              <html data-preprocessor="youtube">
                <head>
                  <title>#{escape_html(title)}</title>
                  <meta property="article:published_time" content="#{escape_html(published_at)}" />
                  <meta property="og:image" content="#{escape_html(thumbnail_url)}" />
                  <script type="application/ld+json">#{jsonld}</script>
                </head>
                <body>
                  <article>
                    <h1>#{escape_html(title)}</h1>
                    #{article_html}
                  </article>
                </body>
              </html>
            HTML
          end

          def render_description(description)
            blocks = description.split(/\r?\n{2,}/).map(&:strip).reject(&:empty?)
            return "<p></p>" if blocks.empty?

            blocks.map do |block|
              lines = block.split(/\r?\n/).map { |line| escape_html(line) }
              "<p>#{lines.join('<br />')}</p>"
            end.join
          end

          def render_thumbnail(thumbnail_url, title)
            return "" if thumbnail_url.to_s.strip.empty?

            <<~HTML
              <figure>
                <img src="#{escape_html(thumbnail_url)}" alt="#{escape_html(title)} thumbnail" />
              </figure>
            HTML
          end

          def preferred_thumbnail(thumbnails)
            return "" unless thumbnails.is_a?(Hash)

            %w[maxres standard high medium default].each do |size|
              url = thumbnails.dig(size, "url").to_s.strip
              return url unless url.empty?
            end

            ""
          end

          def escape_html(value)
            CGI.escapeHTML(value.to_s)
          end
        end
      end
    end
  end
end

