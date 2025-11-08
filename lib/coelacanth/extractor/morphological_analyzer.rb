# frozen_string_literal: true

module Coelacanth
  class Extractor
    # Lightweight morphological analyzer that approximates tokenization for
    # Japanese and Latin text without relying on third-party native
    # dependencies. The implementation aims to support downstream tagging
    # scenarios by returning frequency-sorted tokens extracted from the
    # Markdown body.
    class MorphologicalAnalyzer
      TOKEN_PATTERN = /
        \p{Han}+ |           # Kanji sequences
        \p{Hiragana}+ |      # Hiragana sequences
        [\p{Katakana}ー]+ |  # Katakana sequences including the choonpu
        [A-Za-z0-9]+         # Latin alphanumerics
      /x.freeze

      MARKDOWN_CONTROL_PATTERN = /[`*_>#\[\]\(\)\{\}!\+\-=|~]/.freeze

      STOPWORDS = %w[
        a an and are as at be but by for if in into is it its of on or such
        that the their then there these they this to was were will with
      ].freeze

      FULLWIDTH_ALPHA = "ＡＢＣＤＥＦＧＨＩＪＫＬＭＮＯＰＱＲＳＴＵＶＷＸＹＺａｂｃｄｅｆｇｈｉｊｋｌｍｎｏｐｑｒｓｔｕｖｗｘｙｚ".freeze
      HALF_WIDTH_ALPHA = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz".freeze
      FULLWIDTH_DIGITS = "０１２３４５６７８９".freeze
      HALF_WIDTH_DIGITS = "0123456789".freeze

      def call(markdown:)
        text = markdown.to_s
        return [] if text.empty?

        sanitized = text.gsub(MARKDOWN_CONTROL_PATTERN, " ")
        tokens = merge_japanese_tokens(sanitized.scan(TOKEN_PATTERN))

        counts = Hash.new(0)

        tokens.each do |raw_token|
          token = normalize(raw_token)
          next unless relevant?(token)

          counts[token] += 1
        end

        counts
          .map { |token, count| { token:, count: } }
          .sort_by { |entry| [-entry[:count], entry[:token]] }
      end

      private

      def normalize(token)
        token
          .tr(FULLWIDTH_ALPHA, HALF_WIDTH_ALPHA)
          .tr(FULLWIDTH_DIGITS, HALF_WIDTH_DIGITS)
          .downcase
      end

      def merge_japanese_tokens(tokens)
        merged = []

        tokens.each do |token|
          if merged.any? && kanji_token?(merged.last) && hiragana_token?(token)
            merged[-1] = merged.last + token
          else
            merged << token
          end
        end

        merged
      end

      def kanji_token?(token)
        token.match?(/\A\p{Han}+\z/)
      end

      def hiragana_token?(token)
        token.match?(/\A\p{Hiragana}+\z/)
      end

      def relevant?(token)
        return false if token.empty?
        return false if STOPWORDS.include?(token)
        return false if token.match?(/\A\d+\z/)
        return false if token.length == 1 && token.match?(/\A[a-z]\z/)

        true
      end
    end
  end
end
