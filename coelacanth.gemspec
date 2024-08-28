# frozen_string_literal: true

require_relative "lib/coelacanth/version"

Gem::Specification.new do |spec|
  spec.name          = "coelacanth"
  spec.version       = Coelacanth::VERSION
  spec.authors       = ["Yusuke"]
  spec.email         = ["yusuke@slidict.io"]

  spec.summary       = "A gem for analyzing and extracting statistics from web pages."
  spec.description   = <<~DESC
    coelacanth is a gem that allows you to easily parse and analyze web pages,
    extracting key statistics and information for further use in various projects."
  DESC
  spec.homepage      = "https://github.com/slidict/coelacanth"
  spec.license       = "MIT"
  spec.required_ruby_version = ">= 3.0"

  spec.metadata["homepage_uri"]      = spec.homepage
  spec.metadata["source_code_uri"]   = "https://github.com/slidict/coelacanth"
  spec.metadata["changelog_uri"]     = "https://github.com/slidict/coelacanth/releases"

  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (f == __FILE__) || f.match(%r{\A(?:(?:bin|test|spec|features)/|\.(?:git|circleci)|appveyor)})
    end
  end

  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Uncomment to register a new dependency of your gem
  # spec.add_dependency "nokogiri", "~> 1.12"
end
