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

    result = analyzer.call(markdown: markdown)

    expect(result).to eq([
      { token: "testing", count: 2 },
      { token: "これは", count: 2 },
      { token: "です", count: 2 },
      { token: "analysis", count: 1 },
      { token: "analyzer", count: 1 },
      { token: "morphological", count: 1 },
      { token: "サンプル", count: 1 },
      { token: "テスト", count: 1 },
      { token: "見出し", count: 1 }
    ])
  end

  it "returns an empty array when the markdown is blank" do
    expect(analyzer.call(markdown: "")).to eq([])
  end
end
