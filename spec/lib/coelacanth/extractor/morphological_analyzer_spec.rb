# frozen_string_literal: true

require "spec_helper"

RSpec.describe Coelacanth::Extractor::MorphologicalAnalyzer do
  subject(:analyzer) { described_class.new(config: config) }

  let(:config) { instance_double(Coelacanth::Configure, read: nil) }

  it "extracts frequency-sorted morphemes from mixed text" do
    markdown = <<~MARKDOWN
      # 見出し

      これはテストです。これはサンプルです。

      Testing the analyzer, testing morphological analysis!
    MARKDOWN

    result = analyzer.call(node: nil, title: nil, markdown: markdown)

    expect(result).to all(include(:token, :score, :count))
    expect(result.first[:token]).to eq("testing morphological analysis")
    expect(result.map { |entry| entry[:token] }).to include("見出し", "サンプル", "テスト")
    scores = result.map { |entry| entry[:score] }
    expect(scores).to eq(scores.sort.reverse)
  end

  it "returns an empty array when the markdown is blank" do
    expect(analyzer.call(node: nil, title: nil, markdown: "")).to eq([])
  end

  context "with default configuration" do
    let(:config) { Coelacanth.config }

    it "keeps numeric commas and splits mixed Japanese sequences" do
      markdown = <<~MARKDOWN
        7,000 Cameras in Japan Compromised, Security Firm Finds
        京都にタワマン住民ら違法性訴え
      MARKDOWN

      tokens = analyzer.call(node: nil, title: nil, markdown: markdown).map { |entry| entry[:token] }

      expect(tokens).to include("7,000 camera")
      expect(tokens).to include("京都", "タワマン", "住民ら違法性訴え")
      expect(tokens).not_to include("京都にタワマン住民ら違法性訴え")
    end
  end

  context "with configurable segmentation" do
    let(:config) { instance_double(Coelacanth::Configure) }

    before do
      allow(config).to receive(:read) do |key|
        {
          "morphology.latin_joiners" => [","],
          "morphology.japanese_hiragana_suffixes" => %w[ら の え],
          "morphology.japanese_category_breaks" => ["katakana_to_kanji"]
        }[key]
      end
    end

    it "honours latin joiners when assembling tokens" do
      markdown = "7,000 Cameras in Japan Compromised, Security Firm Finds"

      tokens = analyzer.call(node: nil, title: nil, markdown: markdown).map { |entry| entry[:token] }

      expect(tokens).to include("7,000 camera")
      expect(tokens).to include(a_string_including("security firm"))
    end

    it "restricts japanese sequences to the configured hiragana suffixes" do
      markdown = "京都にタワマン住民ら違法性訴え"

      tokens = analyzer.call(node: nil, title: nil, markdown: markdown).map { |entry| entry[:token] }

      expect(tokens).to include("京都", "タワマン", "住民ら違法性訴え")
      expect(tokens).not_to include("京都にタワマン住民ら違法性訴え")
    end
  end
end
