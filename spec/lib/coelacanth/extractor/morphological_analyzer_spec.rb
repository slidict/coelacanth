# frozen_string_literal: true

require "spec_helper"

RSpec.describe Coelacanth::Extractor::MorphologicalAnalyzer do
  subject(:analyzer) { described_class.new }

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
end
