# frozen_string_literal: true

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

    ResponseMetadata = Struct.new(
      :status_code,
      :status_message,
      :headers,
      :final_url,
      keyword_init: true
    )

    module ResponseMetadataAccessor
      attr_accessor :coelacanth_metadata
    end

    ErrorResponse = Struct.new(:status, :meta, :base_uri, :body, keyword_init: true) do
      include ResponseMetadataAccessor

      def string
        body.to_s
      end

      alias to_s string
    end

    module_function

    def get_response(uri, open_timeout: DEFAULT_OPEN_TIMEOUT, read_timeout: DEFAULT_READ_TIMEOUT, retries: MAX_RETRIES)
      ensure_allowed!(uri)
      response = raw_get_response(
        uri,
        open_timeout: open_timeout,
        read_timeout: read_timeout,
        retries: retries
      )
      attach_metadata(response, uri)
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
      metadata = build_metadata(response, uri)
      message = format("%s %s for GET %s", response.code, response.message, uri)
      io = ErrorResponse.new(
        status: [response.code, response.message],
        meta: response.each_header.to_h,
        base_uri: uri,
        body: response.body
      )
      attach_metadata(io, uri, metadata: metadata)

      raise OpenURI::HTTPError.new(message, io)
    end

    def build_metadata(response, uri)
      return unless response

      headers = if response.respond_to?(:each_header)
                  response.each_header.to_h
                elsif response.respond_to?(:meta)
                  response.meta
                else
                  {}
                end

      final_uri = if response.respond_to?(:uri) && response.uri
                    response.uri
                  elsif response.respond_to?(:base_uri) && response.base_uri
                    response.base_uri
                  else
                    uri
                  end

      ResponseMetadata.new(
        status_code: response.code.to_i,
        status_message: response.message,
        headers: headers,
        final_url: final_uri.to_s
      )
    end

    def attach_metadata(response, uri, metadata: nil)
      return unless response

      metadata ||= build_metadata(response, uri)
      return response unless metadata

      response.extend(ResponseMetadataAccessor) unless response.respond_to?(:coelacanth_metadata=)
      response.coelacanth_metadata = metadata
      response
    end
  end
end
