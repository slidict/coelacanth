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
      remote_client.network.wait_for_idle! # might raise an error
      body = remote_client.body
      body
    rescue => e
      raise "#{e.class}: #{e.message} RemoteClient: #{@remote_client.inspect}"
    end

    def get_screenshot
      tempfile = Tempfile.new
      remote_client.network.wait_for_idle! # まずJSの完了を待つ
      remote_client.screenshot(path: tempfile.path, format: "png")
      File.read(tempfile.path)
    rescue => e
      tempfile.close
      raise "#{e.class}: #{e.message} RemoteClient: #{@remote_client.inspect}"
    end

    private

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
