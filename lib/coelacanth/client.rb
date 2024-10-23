# frozen_string_literal: true

require "ferrum"

module Coelacanth
  # Coelacanth::Client
  class Client
    def initialize(url)
      @validator = Validator.new
      raise URI::InvalidURIError unless @validator.valid_url?(url)
      @config = Coelacanth.config
      remote_client.goto(url)
    end

    def get_response(url = nil)
      @status_code = remote_client.network.status
      @origin_response = remote_client
      body = remote_client.body
      remote_client.network.wait_for_idle! # might raise an error
      body
    end

    def get_screenshot
      tempfile = Tempfile.new
      remote_client.screenshot(path: tempfile.path, format: "png")
      remote_client.network.wait_for_idle! # might raise an error
      File.read(tempfile.path)
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
