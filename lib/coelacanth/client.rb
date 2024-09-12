# frozen_string_literal: true

require "ferrum"

module Coelacanth
  # Coelacanth::Client
  class Client
    def initialize(url = nil)
      @config = Coelacanth.config
      @validator = Validator.new
      @url = url if url && @validator.valid_url?(url)
    end

    def get_response(url = nil)
      @url = url if url && @validator.valid_url?(url)
      remote_client.goto(@url)
      @status_code = remote_client.network.status
      @origin_response = remote_client
      remote_client.body
    end

    private

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
