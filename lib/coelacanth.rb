# frozen_string_literal: true

require "net/http"
require_relative "coelacanth/version"
require_relative "coelacanth/configure"
require_relative "coelacanth/client"

# Coelacanth
module Coelacanth
  class Error < StandardError; end
  class RedirectError < StandardError; end
  class DeepRedirectError < StandardError; end

  def self.analyze(url)
    @client = Client.new(url)
    @client.resolve_redirect
    {
      remote_client: @config.read("use_remote_client"),
      oga: @client.oga
    }
  end

  def self.config
    @config ||= Configure.new
  end
end
