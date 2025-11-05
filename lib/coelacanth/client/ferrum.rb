# frozen_string_literal: true

require "ferrum"

module Coelacanth::Client
  # Coelacanth::Client
  class Ferrum < Coelacanth::Client::Base
    def initialize(url)
      super(url)
      remote_client.goto(url)
    end

    def get_response(url = nil)
      @status_code = remote_client.network.status
      wait_for_network_idle
      body = remote_client.body
      body
    rescue => e
      raise sanitized_remote_client_error(e)
    end

    def get_screenshot
      tempfile = Tempfile.new
      wait_for_network_idle
      remote_client.screenshot(path: tempfile.path, format: "png")
      File.read(tempfile.path)
    rescue => e
      tempfile.close
      raise sanitized_remote_client_error(e)
    end

    private

    def sanitized_remote_client_error(error)
      "#{error.class}: #{error.message} RemoteClient: #{sanitized_remote_client_identifier}"
    end

    def sanitized_remote_client_identifier
      return "nil" unless @remote_client

      "#{@remote_client.class.name}(object_id=#{@remote_client.object_id})"
    end

    def wait_for_network_idle
      timeout = wait_for_idle_timeout

      if timeout
        remote_client.network.wait_for_idle!(timeout: timeout)
      else
        remote_client.network.wait_for_idle!
      end
    rescue ::Ferrum::TimeoutError
      nil
    end

    def wait_for_idle_timeout
      timeout = @config.read("remote_client.wait_for_idle_timeout")
      return timeout if timeout

      DEFAULT_WAIT_FOR_IDLE_TIMEOUT
    end

    DEFAULT_WAIT_FOR_IDLE_TIMEOUT = 5

    def remote_client
      return @remote_client if @remote_client

      headers = @config.read("remote_client.headers")

      @remote_client = ::Ferrum::Browser.new(
        ws_url: @config.read("remote_client.ws_url"),
        timeout: @config.read("remote_client.timeout")
      )

      @remote_client.page.headers.set(headers) if headers && headers.any?

      @remote_client
    end
  end
end
