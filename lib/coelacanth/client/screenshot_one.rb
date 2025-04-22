# frozen_string_literal: true

require "open-uri"
require "ferrum"

module Coelacanth::Client
  # Coelacanth::Client
  class ScreenshotOne < Coelacanth::Client::Base
    def get_response
      @origin_response = URI.open(@url)
      @status_code = @origin_response.status[0].to_i
      body = @origin_response.read
      body
    rescue OpenURI::HTTPError => e
      @status_code = e.io.status[0].to_i
      raise e
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

      response = Net::HTTP.get_response(uri)
      raise "Failed to fetch screenshot: #{response.code}" unless response.is_a?(Net::HTTPSuccess)

      response.body
    end
  end
end
