# frozen_string_literal: true

require "json"
require "set"
require "tmpdir"
require "uri"

require_relative "utilities"
require_relative "../http"

module Coelacanth
  class Extractor
    # Finds and downloads the representative image for a document.
    class EyecatchImageExtractor
      Result = Struct.new(:url, :path, keyword_init: true)

      POSITIVE_KEYWORDS = %w[eyecatch hero main featured cover headline banner article primary lead].freeze
      NEGATIVE_KEYWORDS = %w[avatar icon logo emoji badge button profile author comment footer nav thumbnail thumb ad sponsor].freeze

      METADATA_SOURCES = [
        { selector: "meta[property='og:image:secure_url']", attribute: "content", score: 140 },
        { selector: "meta[property='og:image:url']", attribute: "content", score: 135 },
        { selector: "meta[property='og:image']", attribute: "content", score: 130 },
        { selector: "meta[name='twitter:image:src']", attribute: "content", score: 125 },
        { selector: "meta[name='twitter:image']", attribute: "content", score: 120 },
        { selector: "meta[itemprop='image']", attribute: "content", score: 110 },
        { selector: "meta[name='thumbnail']", attribute: "content", score: 100 },
        { selector: "link[rel='image_src']", attribute: "href", score: 95 }
      ].freeze

      JSON_LD_IMAGE_KEYS = %w[image imageUrl imageURL thumbnail thumbnailUrl thumbnailURL contentUrl contentURL].freeze

      LAZY_SOURCE_ATTRIBUTES = %w[data-src data-original data-lazy-src data-lazy data-url data-image data-preview src].freeze

      def initialize(http_client: Coelacanth::HTTP)
        @http_client = http_client
      end

      def call(doc:, base_url: nil)
        return unless doc

        image_url = locate_image_url(doc, base_url)
        return unless image_url

        download(image_url)
      end

      private

      attr_reader :http_client

      def locate_image_url(doc, base_url)
        candidates = []

        candidates.concat(metadata_candidates(doc, base_url))
        candidates.concat(structured_data_candidates(doc, base_url))
        candidates.concat(document_image_candidates(doc, base_url))

        best_candidate(candidates)&.dig(:url)
      end

      def metadata_candidates(doc, base_url)
        METADATA_SOURCES.flat_map do |source|
          doc.css(source[:selector]).filter_map do |node|
            value = node[source[:attribute]].to_s.strip
            next if value.empty?

            url = absolutize(base_url, value)
            next unless url

            {
              url: url,
              score: source[:score],
              origin: :metadata
            }
          end
        end
      end

      def structured_data_candidates(doc, base_url)
        doc.css("script[type='application/ld+json']").flat_map do |script|
          parse_structured_data(script).flat_map do |value|
            url = absolutize(base_url, value)
            next unless url

            {
              url: url,
              score: 105,
              origin: :structured_data
            }
          end
        end
      end

      def parse_structured_data(script)
        payload = script.text.to_s.strip
        return [] if payload.empty?

        Array(extract_images_from_jsonld(JSON.parse(payload)))
      rescue JSON::ParserError
        []
      end

      def extract_images_from_jsonld(data)
        case data
        when String
          return [] unless valid_image_url?(data)

          [data]
        when Array
          data.flat_map { |value| extract_images_from_jsonld(value) }
        when Hash
          urls = []

          JSON_LD_IMAGE_KEYS.each do |key|
            next unless data.key?(key)

            urls.concat(Array(extract_images_from_jsonld(data[key])))
          end

          if data["@type"].to_s.casecmp("ImageObject").zero? && data["url"].to_s.strip != ""
            urls << data["url"]
          end

          data.each_value do |value|
            next unless value.is_a?(Array) || value.is_a?(Hash)

            urls.concat(Array(extract_images_from_jsonld(value)))
          end

          urls
        else
          []
        end
      end

      def document_image_candidates(doc, base_url)
        doc.css("img").flat_map do |node|
          sources_for(node).filter_map do |source|
            url = absolutize(base_url, source[:url])
            next unless url

            score = 60
            score += descriptor_bonus(source[:weight])
            score += score_for_image_node(node, url)

            {
              url: url,
              score: score,
              origin: :document
            }
          end
        end
      end

      def sources_for(node)
        seen = Set.new
        entries = []

        LAZY_SOURCE_ATTRIBUTES.each do |attribute|
          value = node[attribute]
          next unless valid_image_url?(value)
          next if seen.include?(value)

          seen << value
          entries << { url: value, weight: nil }
        end

        [node["srcset"], node["data-srcset"]].compact.each do |srcset|
          parse_srcset(srcset).each do |entry|
            next if seen.include?(entry[:url])

            seen << entry[:url]
            entries << entry
          end
        end

        if node.parent&.name == "picture"
          node.parent.css("source").each do |source|
            [source["src"], source["data-src"]].compact.each do |value|
              next unless valid_image_url?(value)
              next if seen.include?(value)

              seen << value
              entries << { url: value, weight: nil }
            end

            [source["srcset"], source["data-srcset"]].compact.each do |srcset|
              parse_srcset(srcset).each do |entry|
                next if seen.include?(entry[:url])

                seen << entry[:url]
                entries << entry
              end
            end
          end
        end

        entries
      end

      def parse_srcset(srcset)
        return [] if srcset.to_s.strip.empty?

        srcset.split(",").filter_map do |candidate|
          parts = candidate.strip.split
          url = parts[0].to_s.strip
          next unless valid_image_url?(url)

          descriptor = parts[1]
          { url: url, weight: descriptor_weight(descriptor) }
        end
      end

      def descriptor_weight(descriptor)
        return nil if descriptor.to_s.empty?

        if descriptor.end_with?("w")
          descriptor.to_i
        elsif descriptor.end_with?("x")
          (descriptor.to_f * 1000).to_i
        elsif descriptor.end_with?("h")
          descriptor.to_i
        else
          descriptor.to_i
        end
      end

      def descriptor_bonus(weight)
        return 0 unless weight

        case weight
        when 0..399 then 0
        when 400..799 then 8
        when 800..1199 then 15
        else
          22
        end
      end

      def score_for_image_node(node, url)
        score = 0

        tokens = Utilities.class_id_tokens(node).map(&:downcase)
        score += tokens.count { |token| POSITIVE_KEYWORDS.include?(token) } * 25
        score -= tokens.count { |token| NEGATIVE_KEYWORDS.include?(token) } * 30

        alt_text = node["alt"].to_s.downcase
        score += keyword_score(alt_text, 12)
        score -= keyword_score(alt_text, 18, NEGATIVE_KEYWORDS)

        src_score_text = url.downcase
        score += keyword_score(src_score_text, 8)
        score -= keyword_score(src_score_text, 16, NEGATIVE_KEYWORDS)

        width = dimension_from(node["width"], node["data-width"]) || descriptor_dimension(node["srcset"]) || descriptor_dimension(node["data-srcset"])
        height = dimension_from(node["height"], node["data-height"]) || width

        score += 18 if width && width >= 700
        score += 12 if height && height >= 400
        score -= 20 if width && width <= 64
        score -= 20 if height && height <= 64

        ancestors = Utilities.ancestors(node)
        score += 12 if ancestors.any? { |ancestor| ancestor.respond_to?(:name) && ancestor.name == "figure" }
        score += 8 if ancestors.any? { |ancestor| ancestor.respond_to?(:name) && ancestor.name == "article" }
        score -= 18 if ancestors.any? { |ancestor| ancestor.respond_to?(:name) && %w[footer aside nav].include?(ancestor.name) }

        score
      end

      def keyword_score(text, value, keywords = POSITIVE_KEYWORDS)
        return 0 if text.empty?

        keywords.count { |keyword| text.include?(keyword) } * value
      end

      def dimension_from(*values)
        values.compact.each do |value|
          digits = value.to_s.scan(/[0-9]+/).first
          return digits.to_i if digits
        end
        nil
      end

      def descriptor_dimension(srcset)
        candidate = parse_srcset(srcset).max_by { |entry| entry[:weight].to_i }
        candidate && candidate[:weight]
      end

      def valid_image_url?(value)
        value = value.to_s.strip
        return false if value.empty?
        return false if value.match?(/\A(?:data|javascript):/i)

        true
      end

      def best_candidate(candidates)
        deduped = {}
        candidates.each do |candidate|
          next unless candidate[:url]

          key = candidate[:url]
          existing = deduped[key]
          if !existing || candidate[:score] > existing[:score]
            deduped[key] = candidate
          end
        end

        deduped.values.max_by { |candidate| candidate[:score] }
      end

      def absolutize(base_url, value)
        return if value.nil? || value.empty?

        if base_url
          Utilities.absolute_url(base_url, value)
        else
          value
        end
      rescue URI::Error
        value
      end

      def download(url)
        response = http_client.get_response(URI.parse(url))
        return unless http_success?(response)

        body = response.body.to_s
        return if body.empty?

        directory = Dir.mktmpdir("coelacanth-eyecatch-")
        file_path = File.join(directory, filename_for(url, response))
        File.binwrite(file_path, body)

        Result.new(url: url, path: file_path)
      rescue StandardError
        nil
      end

      def http_success?(response)
        return false unless response.respond_to?(:code)

        response.code.to_i.between?(200, 299)
      end

      def filename_for(url, response)
        uri = URI.parse(url)
        candidate = File.basename(uri.path.to_s)
        candidate = nil if candidate.nil? or candidate.empty? or candidate == "."
        extension = File.extname(candidate.to_s)

        if extension.empty?
          extension = extension_for_content_type(response)
          candidate = ["eyecatch", extension.delete_prefix(".")].compact.join(".")
        end

        candidate || "eyecatch#{extension_for_content_type(response)}"
      rescue URI::Error
        "eyecatch#{extension_for_content_type(response)}"
      end

      def extension_for_content_type(response)
        content_type = if response.respond_to?(:content_type)
                         response.content_type
                       elsif response.respond_to?(:[])
                         response["content-type"]
                       end
        content_type = content_type.to_s.split(";").first

        case content_type
        when "image/jpeg", "image/jpg" then ".jpg"
        when "image/png" then ".png"
        when "image/gif" then ".gif"
        when "image/webp" then ".webp"
        when "image/svg+xml" then ".svg"
        else
          ".bin"
        end
      end
    end
  end
end
