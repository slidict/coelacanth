# frozen_string_literal: true

require "net/http"
require_relative "coelacanth/configure"
require_relative "coelacanth/client/base"
require_relative "coelacanth/client/ferrum"
require_relative "coelacanth/client/gotenberg"
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
    client_class = client_class_for(config.read("client"))
    @client = client_class.new(url)
    regular_url = Redirect.new.resolve_redirect(url)
    response = begin
      Coelacanth::HTTP.get_response(URI.parse(regular_url))
    rescue Coelacanth::TimeoutError
      nil
    end
    response_metadata = {
      status_code: response&.status_code,
      headers: response&.headers || {},
      final_url: response&.final_url || regular_url
    }
    html = response&.body.to_s
    html = html.dup
    html = html.force_encoding(Encoding::UTF_8)
    html = html.encode(Encoding::UTF_8, invalid: :replace, undef: :replace)
    extractor_result = Extractor.new.call(html: html, url: regular_url, response_metadata: response_metadata)
    {
      dom: Dom.new.oga(regular_url, html: html),
      screenshot: @client.get_screenshot,
      extraction: extractor_result,
      response: response_metadata
    }
  end

  def self.client_class_for(client_name)
    case client_name
    when "screenshot_one"
      Client::ScreenshotOne
    when "gotenberg"
      Client::Gotenberg
    else
      Client::Ferrum
    end
  end

  def self.config
    @config ||= Configure.new
  end

  def self.morphological_analysis(text, title: nil)
    Extractor::MorphologicalAnalyzer
      .new(config: config)
      .call_text(text, title: title)
  end
end
