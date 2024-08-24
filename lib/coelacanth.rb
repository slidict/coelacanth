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

  def self.analyze(_url)
    {
      todo: "implement me"
    }
  end
end
