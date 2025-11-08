# frozen_string_literal: true

require "set"
require "strscan"

module Coelacanth
  class Extractor
    # Scores candidate morphemes extracted from article content. The
    # implementation follows a light-weight heuristic approach that approximates
    # the specification shared in the user instructions. It prioritises noun-ish
    # phrases for both Japanese and English text, applies positional boosts, and
    # returns the highest scoring terms.
    class MorphologicalAnalyzer
      TOKEN_PATTERN = /
        \p{Han}+ |                     # Kanji sequences
        \p{Hiragana}+ |                # Hiragana sequences
        [\p{Katakana}ー]+ |             # Katakana sequences including the choonpu
        [A-Za-z0-9]+(?:-[A-Za-z0-9]+)*  # Latin alphanumerics keeping inner hyphen
      /x.freeze

      MARKDOWN_CONTROL_PATTERN = /[`*_>#\[\]\(\)\{\}!\+=|~]/.freeze

      EN_STOPWORDS = %w[
        a an and are as at be but by for if in into is it its of on or such
        that the their then there these they this to was were will with
      ].freeze

      EN_GENERIC_TERMS = %w[
        page pages article articles category categories tag tags image images
        video videos click home link links read more author authors post posts
      ].freeze

      JA_GENERIC_TERMS = %w[カテゴリ カテゴリー 記事 画像 写真 まとめ サイト 投稿 ブログ 最新 人気 関連].freeze

      FULLWIDTH_ALPHA = "ＡＢＣＤＥＦＧＨＩＪＫＬＭＮＯＰＱＲＳＴＵＶＷＸＹＺａｂｃｄｅｆｇｈｉｊｋｌｍｎｏｐｑｒｓｔｕｖｗｘｙｚ".freeze
      HALF_WIDTH_ALPHA = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz".freeze
      FULLWIDTH_DIGITS = "０１２３４５６７８９".freeze
      HALF_WIDTH_DIGITS = "0123456789".freeze
      FULLWIDTH_HYPHENS = "－―ーｰ".freeze

      TOP_K = 8
      MAX_POSITION_BOOST = 3.0
      LENGTH_BONUS_FACTOR = 0.15
      MAX_LENGTH_BONUS = 1.6

      POSITION_WEIGHTS = {
        body: 1.0,
        title: 2.2,
        h1: 1.6,
        h2: 1.3,
        accent: 1.1
      }.freeze

      CATEGORY_ALIASES = {
        "kanji" => :kanji,
        "hiragana" => :hiragana,
        "katakana" => :katakana,
        "latin" => :latin
      }.freeze

      Term = Struct.new(:key, :token, :components, :language, keyword_init: true)

      def initialize(config: Coelacanth.config)
        @config = config
      end

      def call_text(text, title: nil)
        call(node: nil, title: title, markdown: text)
      end

      def call(node:, title:, markdown:)
        stats = Hash.new do |hash, key|
          hash[key] = {
            token: nil,
            components: 1,
            body_count: 0,
            pos_bonus: 0.0,
            language: nil
          }
        end

        body_terms = extract_terms(markdown)

        contexts = [
          [POSITION_WEIGHTS[:title], extract_terms(title)],
          [POSITION_WEIGHTS[:h1], extract_terms(text_for(node, "h1"))],
          [POSITION_WEIGHTS[:h2], extract_terms(text_for(node, "h2"))],
          [
            POSITION_WEIGHTS[:accent],
            extract_terms(
              [
                text_for(node, "a"),
                text_for(node, "strong"),
                text_for(node, "b"),
                text_for(node, "img", attribute: "alt")
              ].compact.join(" ")
            )
          ],
          [POSITION_WEIGHTS[:body], body_terms]
        ]

        contexts.each do |weight, terms|
          next if terms.empty?

          grouped = terms.group_by(&:key)
          grouped.each_value do |occurrences|
            representative = occurrences.max_by(&:components)
            entry = stats[representative.key]
            entry[:token] ||= representative.token
            entry[:components] = [entry[:components], representative.components].max
            entry[:language] ||= representative.language

            bonus = weight - 1.0
            entry[:pos_bonus] += bonus if bonus.positive?
          end
        end

        body_terms.each do |term|
          entry = stats[term.key]
          entry[:token] ||= term.token
          entry[:components] = [entry[:components], term.components].max
          entry[:language] ||= term.language
          entry[:body_count] += 1
        end

        scored = stats.values.map do |entry|
          next if entry[:body_count].zero?

          tf = Math.log(entry[:body_count] + 1.0)
          pos_boost = [1.0 + entry[:pos_bonus], MAX_POSITION_BOOST].min
          len_bonus = [1.0 + LENGTH_BONUS_FACTOR * (entry[:components] - 1), MAX_LENGTH_BONUS].min
          score = tf * pos_boost * len_bonus

          entry.merge(score: score)
        end.compact

        return [] if scored.empty?

        sorted = scored.sort_by { |entry| [-entry[:score], entry[:token]] }
        pruned = prune_inclusions(sorted)
        max_score = pruned.first[:score]
        threshold = max_score * 0.35

        selected = pruned.select { |entry| entry[:score] >= threshold }

        if selected.length < TOP_K
          pruned.each do |entry|
            next if selected.include?(entry)

            selected << entry
            break if selected.length >= TOP_K
          end
        end

        selected = selected.take(TOP_K)

        selected.map do |entry|
          {
            token: entry[:token],
            score: entry[:score],
            count: entry[:body_count]
          }
        end
      end

      private

      def extract_terms(text)
        sanitized = sanitize_text(text)
        return [] if sanitized.empty?

        tokens = tokenize(sanitized)
        build_terms(tokens)
      end

      def sanitize_text(text)
        sanitized = text.to_s
        return "" if sanitized.empty?

        sanitized = sanitized.gsub(MARKDOWN_CONTROL_PATTERN, " ")
        sanitized.gsub(/^[ \t]*[-+*]\s+/, " ")
      end

      def tokenize(text)
        scanner = StringScanner.new(text)
        tokens = []
        gap_buffer = String.new
        until scanner.eos?
          if (whitespace = scanner.scan(/\s+/))
            gap_buffer << whitespace
            next
          elsif (raw = scanner.scan(TOKEN_PATTERN))
            end_pos = scanner.pos
            start_pos = end_pos - raw.length
            category = detect_category(raw)
            normalized = normalize_token(raw, category)
            tokens << {
              raw: raw,
              normalized: normalized,
              category: category,
              start: start_pos,
              end: end_pos,
              gap: gap_buffer
            }
            gap_buffer = String.new
          else
            gap_buffer << scanner.getch
          end
        end

        tokens
      end

      def build_terms(tokens)
        terms = []
        index = 0

        while index < tokens.length
          token = tokens[index]

          case token[:category]
          when :latin
            sequences, index = consume_latin_sequences(tokens, index)
            sequences.each do |sequence|
              joined = join_latin_sequence(sequence)
              normalized = joined[:normalized]
              components = sequence.length

              next unless valid_english_term?(normalized)

              terms << Term.new(key: normalized, token: normalized, components: components, language: :en)
            end
          when :kanji, :katakana
            sequence, index = consume_japanese_sequence(tokens, index)
            next if sequence.empty?

            normalized = sequence.map { |component| component[:normalized] }.join
            components = sequence.length

            next unless valid_japanese_term?(normalized)

            terms << Term.new(key: normalized, token: normalized, components: components, language: :ja)
          else
            index += 1
          end
        end

        terms
      end

      def consume_latin_sequences(tokens, index)
        run = []
        pointer = index

        while pointer < tokens.length
          token = tokens[pointer]
          break unless token[:category] == :latin

          run << token
          pointer += 1

          break unless pointer < tokens.length

          next_token = tokens[pointer]
          break unless next_token[:category] == :latin && joinable_gap?(next_token[:gap], :latin)
        end

        sequences = split_latin_run(run)
        [sequences, pointer]
      end

      def split_latin_run(run)
        sequences = []
        current = []

        run.each do |token|
          if english_stopword?(token[:normalized])
            if current.any?
              sequences << current
              current = []
            end
          else
            current << token
          end
        end

        sequences << current if current.any?
        sequences
      end

      def consume_japanese_sequence(tokens, index)
        sequence = []
        pointer = index

        while pointer < tokens.length
          token = tokens[pointer]
          unless japanese_noun_token?(token) || (sequence.any? && hiragana_suffix?(sequence.last, token))
            break
          end

          sequence << token
          pointer += 1

          break unless pointer < tokens.length

          next_token = tokens[pointer]
          break unless japanese_sequence_continues?(token, next_token)
        end

        [sequence, pointer]
      end

      def japanese_sequence_continues?(current, following)
        return false if japanese_category_break?(current, following)

        return false unless japanese_noun_token?(following) ||
          (following[:category] == :latin && joinable_gap?(following[:gap], :latin)) ||
          hiragana_suffix?(current, following)

        gap = following[:gap]
        return true if gap.empty?

        gap.strip.empty?
      end

      def japanese_noun_token?(token)
        [:kanji, :katakana].include?(token[:category])
      end

      def hiragana_suffix?(current, following)
        return false unless current[:category] == :kanji
        return false unless following[:category] == :hiragana
        return false unless following[:gap].empty?

        suffixes = configured_hiragana_suffixes
        return true if suffixes.nil?

        suffixes.include?(following[:raw])
      end

      def whitespace_gap?(gap)
        gap.strip.empty?
      end

      def joinable_gap?(gap, category)
        return true if whitespace_gap?(gap)

        case category
        when :latin
          connector_gap?(gap)
        else
          false
        end
      end

      def connector_gap?(gap)
        return false if gap.nil?

        stripped = gap.delete("\s")
        return false if stripped.empty?

        stripped.chars.all? { |char| latin_joiners.include?(char) }
      end

      def normalize_token(token, category)
        normalized = token
          .tr(FULLWIDTH_ALPHA, HALF_WIDTH_ALPHA)
          .tr(FULLWIDTH_DIGITS, HALF_WIDTH_DIGITS)
          .tr(FULLWIDTH_HYPHENS, "-")
          .downcase

        normalized = lemmatize_latin(normalized) if category == :latin
        normalized
      end

      def detect_category(token)
        return :kanji if token.match?(/\A\p{Han}+\z/)
        return :hiragana if token.match?(/\A\p{Hiragana}+\z/)
        return :katakana if token.match?(/\A[\p{Katakana}ー]+\z/)

        :latin
      end

      def lemmatize_latin(token)
        return token if token.length <= 3
        return token if token.include?("-")
        return token if token.match?(/\d/)
        return token if token.end_with?("ss") || token.end_with?("us") || token.end_with?("is")

        if token.end_with?("ies") && token.length > 3
          token[0...-3] + "y"
        elsif token.end_with?("es") && !token.end_with?("ses") && token.length > 3
          token[0...-2]
        elsif token.end_with?("s")
          token[0...-1]
        else
          token
        end
      end

      def valid_english_term?(normalized)
        return false if normalized.empty?
        return false if normalized.match?(/\A\d+\z/)

        words = normalized.split(/\s+/)
        return false if words.length == 1 && words.first.length <= 2

        return false if EN_GENERIC_TERMS.include?(normalized)

        true
      end

      def english_stopword?(word)
        EN_STOPWORDS.include?(word)
      end

      def valid_japanese_term?(normalized)
        return false if normalized.empty?
        return false if normalized.length == 1
        return false if normalized.match?(/\A[ぁ-ゖゝゞー]+\z/)
        return false if normalized.match?(/\A\d+\z/)
        return false if JA_GENERIC_TERMS.include?(normalized)

        true
      end

      def prune_inclusions(entries)
        accepted = []

        entries.each do |entry|
          next if accepted.any? { |chosen| contains_term?(chosen, entry) }

          accepted << entry
        end

        accepted
      end

      def contains_term?(long_entry, short_entry)
        return false if long_entry.equal?(short_entry)
        return false if long_entry[:language] != short_entry[:language]
        return false if long_entry[:token] == short_entry[:token]

        case long_entry[:language]
        when :en
          long_words = long_entry[:token].split(/\s+/)
          short_words = short_entry[:token].split(/\s+/)
          return false if short_words.length > long_words.length

          long_words.each_cons(short_words.length) do |slice|
            return true if slice == short_words
          end

          false
        when :ja
          long_entry[:token].include?(short_entry[:token])
        else
          false
        end
      end

      def text_for(node, selector, attribute: nil)
        return "" unless node

        elements = node.css(selector)
        return "" if elements.empty?

        texts = elements.map do |element|
          if attribute
            element[attribute].to_s
          else
            element.text
          end
        end

        texts.join(" ")
      end

      def join_latin_sequence(sequence)
        token_builder = String.new
        normalized_builder = String.new

        sequence.each_with_index do |component, index|
          if index.zero?
            token_builder << component[:raw]
            normalized_builder << component[:normalized]
            next
          end

          gap = component[:gap]

          if connector_gap?(gap)
            token_builder << gap
            normalized_builder << gap_connector_representation(gap)
          else
            token_builder << " "
            normalized_builder << " "
          end

          token_builder << component[:raw]
          normalized_builder << component[:normalized]
        end

        { token: token_builder, normalized: normalized_builder }
      end

      def gap_connector_representation(gap)
        stripped = gap.delete("\s")
        return gap if stripped.empty?

        stripped + (gap.match?(/\s+$/) ? " " : "")
      end

      def latin_joiners
        @latin_joiners ||= Array(config_read("morphology.latin_joiners")).map(&:to_s)
      end

      def configured_hiragana_suffixes
        @configured_hiragana_suffixes ||= begin
          suffixes = config_read("morphology.japanese_hiragana_suffixes")
          suffixes&.map(&:to_s)
        end
      end

      def configured_japanese_category_breaks
        @configured_japanese_category_breaks ||= begin
          entries = Array(config_read("morphology.japanese_category_breaks"))
          entries.each_with_object(Set.new) do |entry, set|
            next unless entry

            from, to = entry.to_s.split(/_to_/, 2)
            from_category = CATEGORY_ALIASES[from]
            to_category = CATEGORY_ALIASES[to]

            set << [from_category, to_category] if from_category && to_category
          end
        end
      end

      def japanese_category_break?(current, following)
        breaks = configured_japanese_category_breaks
        return false if breaks.empty?

        breaks.include?([current[:category], following[:category]])
      end

      def config_read(key)
        return nil unless @config

        @config.read(key)
      rescue NoMethodError
        nil
      end
    end
  end
end
