# frozen_string_literal: true

require "net/http"
require "open-uri"
require "timeout"

module Coelacanth
  class TimeoutError < StandardError; end unless const_defined?(:TimeoutError)

  module HTTP
    DEFAULT_OPEN_TIMEOUT = 5
    DEFAULT_READ_TIMEOUT = 10
    MAX_RETRIES = 2

    ErrorResponse = Struct.new(:status, :meta, :base_uri, :body, keyword_init: true) do
      def string
        body.to_s
      end

      alias to_s string
    end

    module_function

    def get_response(uri, open_timeout: DEFAULT_OPEN_TIMEOUT, read_timeout: DEFAULT_READ_TIMEOUT, retries: MAX_RETRIES)
      attempts = 0
      begin
        attempts += 1
        request = Net::HTTP::Get.new(uri)
        Net::HTTP.start(
          uri.host,
          uri.port,
          use_ssl: uri.scheme == "https",
          open_timeout: open_timeout,
          read_timeout: read_timeout
        ) do |http|
          return http.request(request)
        end
      rescue Net::OpenTimeout, Net::ReadTimeout, Timeout::Error => e
        retry if attempts <= retries

        raise Coelacanth::TimeoutError, "GET #{uri} timed out after #{attempts} attempts: #{e.message}"
      end
    end

    def raise_http_error(uri, response)
      message = format("%s %s for GET %s", response.code, response.message, uri)
      io = ErrorResponse.new(
        status: [response.code, response.message],
        meta: response.each_header.to_h,
        base_uri: uri,
        body: response.body
      )

      raise OpenURI::HTTPError.new(message, io)
    end
  end
end
