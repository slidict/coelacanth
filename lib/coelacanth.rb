# frozen_string_literal: true

require "net/http"
require_relative "coelacanth/configure"
require_relative "coelacanth/client/base"
require_relative "coelacanth/client/ferrum"
require_relative "coelacanth/client/screenshot_one"
require_relative "coelacanth/dom"
require_relative "coelacanth/extractor"
require_relative "coelacanth/http"
require_relative "coelacanth/redirect"
require_relative "coelacanth/validator"
require_relative "coelacanth/version"

# Coelacanth
module Coelacanth
  class Error < StandardError; end
  class RedirectError < StandardError; end
  class DeepRedirectError < StandardError; end
  class TimeoutError < StandardError; end
  class RobotsDisallowedError < StandardError; end

  def self.analyze(url)
    client_class = config.read("client") == "screenshot_one" ? Client::ScreenshotOne : Client::Ferrum
    @client = client_class.new(url)
    regular_url = Redirect.new.resolve_redirect(url)
    response = begin
      Coelacanth::HTTP.get_response(URI.parse(regular_url))
    rescue Coelacanth::TimeoutError
      nil
    end
    html = response&.body.to_s
    html = html.dup
    html = html.force_encoding(Encoding::UTF_8)
    html = html.encode(Encoding::UTF_8, invalid: :replace, undef: :replace)
    extractor_result = Extractor.new.call(html: html, url: regular_url)
    {
      dom: Dom.new.oga(regular_url, html: html),
      screenshot: @client.get_screenshot,
      extraction: extractor_result,
    }
  end

  def self.config
    @config ||= Configure.new
  end
end
