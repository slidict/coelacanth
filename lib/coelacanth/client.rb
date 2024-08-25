# frozen_string_literal: true

require "ferrum"

module Coelacanth
  # Coelacanth::Client
  class Client
    def initialize
      @config = Configure.new
    end

    def valid_url?(url)
      uri = URI.parse(url)
      uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)
    rescue URI::InvalidURIError
      false
    end

    def resolve_redirect(url, limit = 10)
      raise Coelacanth::DeepRedirectError, "Too many redirect" if limit.zero?
      raise Coelacanth::RedirectError, "Url or location is nil" if url.nil?

      response = get_response(url)

      case response
      when Net::HTTPSuccess then url
      when Net::HTTPRedirection then resolve_redirect(response["location"], limit - 1)
      else
        raise Coelacanth::RedirectError
      end
    end

    def get_response(url)
      if @config.read("use_remote_client")
        remote_client.goto(url)
        remote_client.body
      else
        Net::HTTP.get_response(url)
      end
    end

    private

    def remote_client
      @remote_client ||= Ferrum::Browser.new(
        ws_url: @config.read("remote_client.ws_url"),
        timeout: @config.read("remote_client.timeout")
      ).create_page
    end
  end
end
