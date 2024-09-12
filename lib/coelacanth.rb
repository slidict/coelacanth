# frozen_string_literal: true

require "net/http"
require_relative "coelacanth/configure"
require_relative "coelacanth/client"
require_relative "coelacanth/dom"
require_relative "coelacanth/redirect"
require_relative "coelacanth/validator"
require_relative "coelacanth/version"

# Coelacanth
module Coelacanth
  class Error < StandardError; end
  class RedirectError < StandardError; end
  class DeepRedirectError < StandardError; end

  def self.analyze(url)
    @client = Client.new(url)
    regular_url = Redirect.new.resolve_redirect(url)
    {
      dom: Dom.new.oga(regular_url)
    }
  end

  def self.config
    @config ||= Configure.new
  end
end
