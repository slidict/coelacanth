# frozen_string_literal: true

require "ferrum"
require_relative "ferrum"
require_relative "../http"

module Coelacanth::Client
  # Coelacanth::Client
  class ScreenshotOne < Coelacanth::Client::Base
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
    rescue Coelacanth::TimeoutError
      fallback_response = fallback_client.get_response
      @status_code = fallback_client.instance_variable_get(:@status_code)
      fallback_response
    end

    def get_screenshot
      api_key = @config.read("screenshot_one.key")
      uri = URI("https://api.screenshotone.com/take")
      params = {
        access_key: api_key,
        url: @url,
        format: "jpg",
        block_ads: true,
        block_cookie_banners: true,
        block_banners_by_heuristics: false,
        block_trackers: true,
        delay: 0,
        timeout: 60,
        response_type: "by_format",
        image_quality: 80
      }
      uri.query = URI.encode_www_form(params)

      response = Coelacanth::HTTP.get_response(
        uri,
        open_timeout: Coelacanth::HTTP::DEFAULT_OPEN_TIMEOUT,
        read_timeout: 30
      )
      raise "Failed to fetch screenshot: #{response.code}" unless response.is_a?(Net::HTTPSuccess)

      response.body
    rescue Coelacanth::TimeoutError
      fallback_client.get_screenshot
    end

    private

    def fallback_client
      @fallback_client ||= Coelacanth::Client::Ferrum.new(@url, @config)
    end
  end
end
