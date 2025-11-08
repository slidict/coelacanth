# Coelacanth

[![Gem Version](https://badge.fury.io/rb/coelacanth.svg)](https://badge.fury.io/rb/coelacanth)
[![Build Status](https://github.com/slidict/coelacanth/actions/workflows/main.yml/badge.svg)](https://github.com/slidict/coelacanth/actions)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)

Coelacanth is a Ruby gem for extracting high-quality article content, metadata, and screenshots from arbitrary web pages. It is
built to power content ingestion pipelines that have to withstand layout experiments, CMS redesigns, and inconsistent markup
while remaining easy to extend.

It is the successor to [`web_stat`](https://rubygems.org/gems/web_stat) and continues the same goal of reliable article
extraction under the `slidict` umbrella. Compared to [`web_stat`](https://github.com/slidict/web_stat/) the gem has been
re-architected with a modern extractor pipeline, built-in screenshot capture, and a clearer configuration story so you can drop
it into contemporary ingestion stacks without bespoke glue code.

## Table of contents
- [Features](#features)
- [Requirements](#requirements)
- [Installation](#installation)
- [Quick start](#quick-start)
- [Extractor pipeline](#extractor-pipeline)
- [Configuration](#configuration)
- [Development workflow](#development-workflow)
- [Testing](#testing)
- [Contributing](#contributing)
- [License](#license)

## Features
- **Layout-resilient extraction** – Multi-stage extractor falls back from structured metadata to heuristics and lightweight
  machine learning so you continue to get clean article bodies even when markup drifts.
- **UTF-8 normalization** – HTML responses are normalized into UTF-8 before parsing to play nicely with Japanese and other
  multi-byte sources.
- **Screenshot capture** – Fetches full-page PNGs via a configurable browser client so you can archive visual context alongside
  the extracted text.
- **Redirect resolution** – Follows HTTP redirects and long redirect chains to guarantee the extractor works on the final
  landing page.
- **Configurable HTTP headers** – Inject custom headers (user agent, authorization, etc.) into the remote browser session for
  authenticated or geo-targeted crawling.

### What's new compared to web_stat?

- **Multi-stage pipeline** – `web_stat` relied on a single-pass heuristic extractor, whereas Coelacanth layers metadata,
  heuristic, and optional ML probes that graduate based on confidence thresholds.
- **First-class screenshots** – Capture full-page PNGs alongside the extracted text without writing a separate headless browser
  integration.
- **Environment-aware configuration** – Manage remote browser credentials, HTTP headers, and client selection through
  `config/coelacanth.yml` instead of hand-tuned initializer code.
- **Markdown-first output** – Get both Markdown and raw DOM representations from `Coelacanth.analyze` so you can publish the
  same payload to static-site builders, CMS importers, or downstream summarizers.

## Requirements
- Ruby **3.4 or newer**
- [Bundler](https://bundler.io/) for dependency management
- A remote Chrome-compatible WebSocket endpoint when using the default Ferrum client (see [Configuration](#configuration))

## Installation
Add the gem to your application:

```ruby
gem "coelacanth"
```

Install the dependencies:

```bash
bundle install
```

Or install the gem directly:

```bash
gem install coelacanth
```

## Quick start
```ruby
require "coelacanth"

result = Coelacanth.analyze("https://example.com/article")

result[:extraction] # => article metadata and body markdown
result[:dom]        # => Oga DOM representation for downstream processing
result[:screenshot] # => PNG screenshot as a binary string
result[:response]   # => HTTP status, headers, and final URL
```

The returned hash includes:

- `:extraction` – output from `Coelacanth::Extractor`, including title, Markdown body (`body_markdown`,
  `body_markdown_list`, and scored morphemes in `body_morphemes`), the normalized plain-text body (`body_text`),
  images, listings, published date, detected site name, and the probe source and confidence score. The extractor also echoes the
  HTTP metadata it received via `response_metadata` for downstream consumers that only operate on the extraction payload.
- `:dom` – a parsed Oga DOM if you need to traverse the document manually.
- `:screenshot` – raw PNG data that you can persist or feed to other systems.
- `:response` – HTTP metadata captured during the initial fetch.

### Response and extraction metadata

The `:response` key exposes a hash with the following keys:

- `:status_code` – Numeric HTTP status (e.g., `200`).
- `:headers` – A lowercase header hash as returned by `Net::HTTP#each_header`.
- `:final_url` – The URL that was ultimately fetched after resolving redirects.

Within the extraction payload (`result[:extraction]`), the following additional metadata is available:

- `:site_name` – Site or application name inferred from Open Graph/Twitter meta tags or the document `<title>`.
- `:body_text` – Plain-text body with collapsed whitespace, suitable for search indexing or summarization.
- `:response_metadata` – Mirrors the top-level `:response` hash so downstream processing can access HTTP metadata without
  carrying the entire analysis result.

## Extractor pipeline
Coelacanth ships with a multi-stage extractor that tries increasingly involved probes until one meets its confidence target:

1. **MetadataProbe** (threshold `0.85`) pulls `schema.org` JSON-LD, Open Graph, Twitter Cards, or semantic containers such as
   `<main>`/`<article>` when available.
2. **HeuristicProbe** (threshold `0.75`) scores block-level nodes using text length, link density, punctuation density, DOM
   depth, and sibling variance, then greedily attaches surrounding headers and media.
3. **WeakMlProbe** (threshold `0.70`) optionally boosts accuracy with a lightweight classifier that combines heuristic features
   with class and id tokens (e.g., `article-body`, `post`, `content`).
4. **FallbackProbe** acts as a safety net by following AMP/print links or summarizing the whole document when the previous
   probes fail.

Markdown-based listings are generated from the extracted body so lists such as "Latest news" blocks can be stored alongside the
article without scanning the rest of the page layout.

## Configuration
Runtime configuration is stored in `config/coelacanth.yml`. Environments inherit from the `development` section by default.

```yaml
development:
  client: "ferrum" # Options: "ferrum", "screenshot_one"
  remote_client:
    ws_url: "ws://chrome:3000/chrome"
    timeout: 10
    wait_for_idle_timeout: 5
    headers:
<% if (auth = ENV["COELACANTH_REMOTE_CLIENT_AUTHORIZATION"]).to_s.strip != "" %>
      Authorization: "<%= auth %>"
<% end %>
      User-Agent: "<%= ENV.fetch("COELACANTH_REMOTE_CLIENT_USER_AGENT", "Coelacanth Chrome Extension") %>"
  screenshot_one:
    key: "<%= ENV.fetch("COELACANTH_SCREENSHOT_ONE_API_KEY", "your_screenshot_one_api_key_here") %>"
  youtube:
    api_key: "<%= ENV.fetch("COELACANTH_YOUTUBE_API_KEY", "") %>"
```

- **Ferrum client** – Requires a running Chrome instance that exposes the DevTools protocol via WebSocket. Configure the URL,
  timeout, the network idle timeout, and any headers to inject.
- **ScreenshotOne client** – Supply an API key to offload screenshot capture to [ScreenshotOne](https://screenshotone.com/).
- **Eyecatch image extraction** – Representative images are discovered automatically by checking Open Graph/Twitter metadata,
  Schema.org JSON-LD payloads, and high-signal `<img>` elements (hero/cover images, large dimensions, etc.). No manual XPath
  maintenance is required.
- **YouTube Data API** – Set an API key to turn YouTube watch URLs into structured articles using the video description and
  thumbnail for downstream processing.
- Configuration is environment-aware: set `RAILS_ENV`/`RACK_ENV` or use Rails' built-in environment handling when the gem is
  used inside a Rails project.

Representative images are downloaded into a temporary directory using the built-in HTTP client. The extractor returns both the
resolved URL and the local file path via `extraction[:eyecatch_image]`. Remember to move or delete the file once you have
persisted it—temporary directories are not automatically cleaned up for long-running processes.

### Environment variables

Configuration values that would otherwise contain credentials are loaded from environment variables. Set the following
variables in your shell (or `dotenv` file) before running the gem:

```bash
# Optional: only set when the remote browser requires authentication.
export COELACANTH_REMOTE_CLIENT_AUTHORIZATION="Bearer <token>"

export COELACANTH_REMOTE_CLIENT_USER_AGENT="Coelacanth Chrome Extension"
export COELACANTH_SCREENSHOT_ONE_API_KEY="your_screenshot_one_api_key_here"
export COELACANTH_YOUTUBE_API_KEY="your_youtube_data_api_key"
```

If `COELACANTH_REMOTE_CLIENT_AUTHORIZATION` is omitted or left blank, the `Authorization` header is not injected into the
remote browser session.

### YouTube Data API integration

With `COELACANTH_YOUTUBE_API_KEY` configured (or `youtube.api_key` populated directly in `config/coelacanth.yml`),
`Coelacanth::Extractor` runs a preprocessor that recognizes standard YouTube watch URLs (`youtube.com`, `youtu.be`,
`m.youtube.com`, etc.). The preprocessor fetches the video snippet from the YouTube Data API and builds an article-like HTML
document that contains:

- The video title and publish timestamp as structured metadata (JSON-LD and Open Graph).
- The full description rendered as Markdown-friendly paragraphs.
- The highest available thumbnail, passed to the eye-catch/image collector pipeline.

If the API key is missing or the API request fails, the extractor falls back to the original HTML that was fetched from
YouTube, so non-video pages continue to behave as before.

When using Docker Compose, you can create a `.env` file or export the variables in your environment so the `app` service picks
them up automatically.

If you are working inside Docker, make sure the `UID` environment variable matches your host user by exporting it in your shell
startup file:

```bash
export UID=${UID}
```

## Development workflow
Clone the repository and install dependencies:

```bash
git clone https://github.com/slidict/coelacanth.git
cd coelacanth
bundle install
```

You can open an interactive console with the gem loaded via:

```bash
bin/console
```

## Testing
Run the test suite with RSpec:

```bash
bundle exec rspec
```

## Contributing
Bug reports and pull requests are welcome on GitHub at
[https://github.com/slidict/coelacanth](https://github.com/slidict/coelacanth). Please follow the
[Conventional Commits](https://www.conventionalcommits.org/) specification so we can keep the changelog automation healthy.

By participating in this project you agree to abide by the [Contributor Covenant](CODE_OF_CONDUCT.md).

## License
Coelacanth is available as open source under the terms of the [MIT License](LICENSE.txt).
