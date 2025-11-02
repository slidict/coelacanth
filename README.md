# coelacanth

[![Gem Version](https://badge.fury.io/rb/coelacanth.svg)](https://badge.fury.io/rb/coelacanth)
[![Build Status](https://github.com/slidict/coelacanth/actions/workflows/main.yml/badge.svg)](https://github.com/slidict/coelacanth/actions)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)

`coelacanth` is a gem that allows you to parse and analyze web pages, extracting key statistics and information for further use within your projects.

## Installation

`coelacanth` requires Ruby **3.4 or newer**.

Add this line to your application's Gemfile:


```ruby
gem 'coelacanth'
```

And then execute:

```bash
$ bundle install
```

Or install it yourself as:

```bash
$ gem install coelacanth
```

### Resolving UID Mismatch Between Docker and Host

To resolve issues related to the difference between Docker's UID and the host's UID, add the following line to your .bashrc or similar shell configuration file:

```bash
export UID=${UID}
```

This will ensure that the environment variable UID is correctly set in your Docker containers, matching your host system's user ID.

This explanation provides clear instructions on how to resolve the UID mismatch issue using the export command.

## Usage
To use coelacanth, first require it.

```ruby
require 'coelacanth'
```

Then, you can easily parse and extract information from a web page like this:

```ruby
url = "https://example.com"
stats = Coelacanth.analyze(url)
```

- rspec

```
$ bundle exec rspec
```

### Selector-free article extraction

For projects that need a resilient way to pull the main article content without
hand-maintained CSS selectors, `coelacanth` ships with a multi-stage
`Coelacanth::Extractor`. The extractor orchestrates a set of probes that work
from the cheapest, highest-signal sources toward more involved fallbacks:

1. **MetadataProbe** – looks for structured data such as `schema.org` JSON-LD,
   Open Graph and Twitter Card tags, and semantic containers like
   `<main>`/`<article>` elements. When these values are present they usually
   provide a near-perfect extraction at zero additional cost.
2. **HeuristicProbe** – walks block-level nodes and scores them using text
   length, link density, punctuation density, tag/attribute hints, DOM depth,
   and sibling variance to pick the most article-like node. Neighboring headers
   and media are greedily attached so the narrative context is preserved.
3. **WeakMlProbe** – optionally boosts accuracy with a lightweight classifier
   (e.g., logistic regression) that combines the heuristic features with class
   and id tokens such as `content`, `article-body`, or `post` to recover pages
   that the pure heuristics miss.
4. **FallbackProbe** – as a last resort it follows AMP or print links when
   available and can fall back to summarizing the whole document for stubborn
   layouts.

Each probe returns a confidence score, and the extractor stops at the first
result that clears its threshold (0.85 for metadata, 0.75 for heuristics, 0.70
for weak ML). The final payload includes:

```ruby
extractor = Coelacanth::Extractor.new
result = extractor.call(html: raw_html, url: "https://example.com/article")

result # => {
  title: "Article title",
  body_markdown: "...",
  body_markdown_list: ["..."],
  images: [ { src: "https://...", alt: "..." }, ... ],
  published_at: Time.parse("2023-11-24T12:00:00Z"),
  byline: "Author Name",
  source: :heuristic,
  confidence: 0.78,
  listings: [
    {
      heading: "Latest news",
      items: [
        { title: "Breaking: Major announcement", url: "https://example.com/news/1", snippet: "Company A unveils a new product" },
        { title: "Update: Market recap", url: "https://example.com/news/2", snippet: "Indexes closed higher across the board" }
      ]
    }
  ]
}
```

This multi-stage design keeps the extractor robust against layout drift, A/B
tests, and CMS redesigns without resorting to fragile, site-specific selectors.
In addition to the main article body, the extractor now returns the Markdown
text both as a single string and as an array of top-level blocks via
`body_markdown_list`, making it easy to feed paragraph-level content into other
systems. The extractor also runs a `ListingCollector` that scans the surrounding
layout for sidebar "latest news" or topic digests. When it detects a
sufficiently rich list, the collector returns an array of sections (each with an
optional heading plus link items) so that you can surface related headlines
alongside the primary content. The collector relies purely on markup
structure—unordered/ordered lists, definition lists (`<dl>` with `dt` / `dd>`
pairs as used on [digital.go.jp](https://www.digital.go.jp/)), and repeated
card-like `<div>` blocks—rather than keyword matching, so Japanese
government-style timelines and other non-English feeds are captured reliably.

## Features
- Get dom by oga
- Get screenshot
- Force-fetch HTML responses into UTF-8 before extraction so Japanese sources
  such as digital.go.jp parse correctly

## Commit Message Guidelines

To ensure consistency and facilitate automatic updates to the `CHANGELOG.md`, please follow the [Conventional Commits](https://www.conventionalcommits.org/) specification when creating commit messages. This helps maintain a clear and structured commit history.

When submitting a Pull Request (PR), make sure your commits adhere to these guidelines.

### Example of Conventional Commit Messages:

- `feat: add new feature for parsing web pages`
- `fix: resolve issue with URL redirection`
- `docs: update README with usage instructions`
- `chore: update dependencies`
- `build: update build configuration`
- `ci: update CI pipeline`
- `style: fix code style issues`
- `refactor: refactor code for better readability`
- `perf: improve performance of data processing`
- `test: add new tests for URL parsing module`

By following these guidelines, you help ensure that our project's commit history is easy to navigate and that versioning and release notes are generated correctly.

## Contributing
Bug reports and pull requests are welcome on GitHub at https://github.com/slidict/coelacanth. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the Contributor Covenant code of conduct.

## License
The gem is available as open-source under the terms of the MIT License.

## Acknowledgments
Special thanks to all the contributors and open-source projects that make this possible.
