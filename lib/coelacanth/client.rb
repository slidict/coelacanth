# frozen_string_literal: true

require "ferrum"
require "oga"

module Coelacanth
  # Coelacanth::Client
  class Client
    def initialize(url = nil)
      @config = Coelacanth.config
      @validator = Validator.new
      @url = url if url && @validator.valid_url?(url)
    end

    def resolve_redirect(url = nil, limit = 10)
      @url = url if url && @validator.valid_url?(url)
      raise Coelacanth::DeepRedirectError, "Too many redirect" if limit.zero?
      raise Coelacanth::RedirectError, "Url or location is nil" if @url.nil?

      get_response(@url)
      handle_response(@origin_response, limit)
    end

    def get_response(url = nil)
      @url = url if url && @validator.valid_url?(url)
      if @config.read("use_remote_client")
        response_by_remote_client
      else
        response_by_net_http
      end
    end

    private

    def handle_response(response, limit)
      codes = Net::HTTPResponse::CODE_CLASS_TO_OBJ.invert
      case @status_code.to_s
      when /^#{codes[Net::HTTPSuccess]}\d\d$/
        @url
      when /^#{codes[Net::HTTPRedirection]}\d\d$/
        @url = response["location"]
        resolve_redirect(response["location"], limit - 1)
      else
        raise Coelacanth::RedirectError
      end
    end

    def response_by_remote_client
      remote_client.goto(@url)
      @status_code = remote_client.network.status
      @origin_response = remote_client
      remote_client.body
    end

    def response_by_net_http
      response = Net::HTTP.get_response(URI.parse(@url))
      @status_code = response.code
      @origin_response = response
      response.body
    end

    def remote_client
      if @remote_client.nil?
        headers = @config.read("remote_client.headers")
        @remote_client = Ferrum::Browser.new(
          ws_url: @config.read("remote_client.ws_url"),
          timeout: @config.read("remote_client.timeout")
        ).create_page
        @remote_client.headers.set(headers) unless headers.empty?
      end
      @remote_client
    end
  end
end
