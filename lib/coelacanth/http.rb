# frozen_string_literal: true

require "delegate"
require "net/http"
require "open-uri"
require "timeout"

require_relative "robots"

module Coelacanth
  class TimeoutError < StandardError; end unless const_defined?(:TimeoutError)

  module HTTP
    DEFAULT_OPEN_TIMEOUT = 5
    DEFAULT_READ_TIMEOUT = 10
    MAX_RETRIES = 2

    Response = Class.new(SimpleDelegator) do
      attr_reader :status_code, :headers, :final_uri

      def initialize(response, final_uri: nil)
        super(response)
        @status_code = response.respond_to?(:code) ? response.code.to_i : nil
        @headers = response.respond_to?(:each_header) ? response.each_header.to_h : {}
        @final_uri = (response.respond_to?(:uri) ? response.uri : nil) || final_uri
      end

      def final_url
        final_uri&.to_s
      end

      def is_a?(klass)
        super || __getobj__.is_a?(klass)
      end

      def kind_of?(klass)
        is_a?(klass)
      end
    end

    ErrorResponse = Struct.new(:status, :meta, :base_uri, :final_uri, :body, keyword_init: true) do
      def string
        body.to_s
      end

      alias to_s string
    end

    module_function

    def get_response(uri, open_timeout: DEFAULT_OPEN_TIMEOUT, read_timeout: DEFAULT_READ_TIMEOUT, retries: MAX_RETRIES)
      ensure_allowed!(uri)
      response = raw_get_response(uri, open_timeout: open_timeout, read_timeout: read_timeout, retries: retries)
      Response.new(response, final_uri: uri)
    end

    def raw_get_response(uri, open_timeout: DEFAULT_OPEN_TIMEOUT, read_timeout: DEFAULT_READ_TIMEOUT, retries: MAX_RETRIES)
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

    def ensure_allowed!(uri)
      return if Coelacanth::Robots.allowed?(uri)

      raise Coelacanth::RobotsDisallowedError,
            "Access to #{uri} is disallowed by robots.txt for user-agent '#{Coelacanth::Robots.user_agent}'"
    end

    def raise_http_error(uri, response)
      message = format("%s %s for GET %s", response.code, response.message, uri)
      io = ErrorResponse.new(
        status: [response.code, response.message],
        meta: response.each_header.to_h,
        base_uri: uri,
        final_uri: response.respond_to?(:uri) ? response.uri : uri,
        body: response.body
      )

      raise OpenURI::HTTPError.new(message, io)
    end
  end
end
