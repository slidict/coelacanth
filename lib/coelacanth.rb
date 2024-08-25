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
    Client.get_response(url)
    {
      todo: "implement me"
    }
  end
end
