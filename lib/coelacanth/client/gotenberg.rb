# frozen_string_literal: true

require "json"
require "net/http"
require "uri"

require_relative "../http"

module Coelacanth::Client
  # Client for capturing screenshots through a Gotenberg Chromium service.
  class Gotenberg < Coelacanth::Client::Base
    SCREENSHOT_URL_PATH = "/forms/chromium/screenshot/url"

    def get_response
      uri = URI.parse(@url)
      response = Coelacanth::HTTP.get_response(
        uri,
        open_timeout: Coelacanth::HTTP::DEFAULT_OPEN_TIMEOUT,
        read_timeout: Coelacanth::HTTP::DEFAULT_READ_TIMEOUT
      )
      @origin_response = response
      @status_code = response.code.to_i

      return response.body if response.is_a?(Net::HTTPSuccess)

      Coelacanth::HTTP.raise_http_error(uri, response)
    end

    def get_screenshot
      response = Net::HTTP.start(
        endpoint_uri.host,
        endpoint_uri.port,
        use_ssl: endpoint_uri.scheme == "https",
        open_timeout: open_timeout,
        read_timeout: read_timeout
      ) do |http|
        http.request(screenshot_request)
      end

      return response.body if response.is_a?(Net::HTTPSuccess)

      raise "Failed to fetch screenshot from Gotenberg: #{response.code} #{response.message}"
    rescue Net::OpenTimeout, Net::ReadTimeout, Timeout::Error => e
      raise Coelacanth::TimeoutError, "Gotenberg screenshot request timed out: #{e.message}"
    end

    private

    def screenshot_request
      request = Net::HTTP::Post.new(endpoint_uri)
      request.set_form(gotenberg_form_fields, "multipart/form-data")
      request
    end

    def gotenberg_form_fields
      fields = [["url", @url]]
      wait_delay = @config.read("gotenberg.wait_delay")
      user_agent = @config.read("gotenberg.user_agent")
      extra_http_headers = @config.read("gotenberg.extra_http_headers")

      fields << ["waitDelay", wait_delay] if present?(wait_delay)
      fields << ["userAgent", user_agent] if present?(user_agent)
      if extra_http_headers && extra_http_headers.any?
        fields << ["extraHttpHeaders", extra_http_headers.to_json]
      end
      fields
    end

    def endpoint_uri
      @endpoint_uri ||= URI.join(base_url, SCREENSHOT_URL_PATH)
    end

    def base_url
      @config.read("gotenberg.url") || "http://localhost:3000"
    end

    def open_timeout
      @config.read("gotenberg.open_timeout") || Coelacanth::HTTP::DEFAULT_OPEN_TIMEOUT
    end

    def read_timeout
      @config.read("gotenberg.read_timeout") || 30
    end

    def present?(value)
      !value.nil? && value.to_s.strip != ""
    end
  end
end
