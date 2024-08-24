# frozen_string_literal: true

module Coelacanth
  # Coelacanth::Client
  class Client
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
      when Net::HTTPSuccess then URI.parse(url)
      when Net::HTTPRedirection then resolve_redirect(response["location"], limit - 1)
      else
        raise Coelacanth::RedirectError
      end
    end

    def get_response(url)
      if Configure.new.read("use_chrome_remote")
        @chrome_client.send_cmd "Network.enable"
        @chrome_client.send_cmd("Page.navigate", url:)
        @chrome_client.wait_for "Page.loadEventFired"
        request_id = @chrome_client.network_events["Network.requestWillBeSent"].last["requestId"]
        response = @chrome_client.send_cmd("Network.getResponseBody", requestId: request_id)
        response["body"]
      else
        Net::HTTP.get_response(URI.parse(url))
      end
    end

    private

    def chrome_client
      @chrome_client ||= ChromeRemote.client
    end
  end
end
