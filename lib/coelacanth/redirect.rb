# frozen_string_literal: true

require "ferrum"
require "oga"

module Coelacanth
  # Coelacanth::Redirect
  class Redirect
    def resolve_redirect(url, limit = 10)
      @url = url if url && Validator.new.valid_url?(url)
      raise Coelacanth::DeepRedirectError, "Too many redirect" if limit.zero?
      raise Coelacanth::RedirectError, "Url or location is nil" if @url.nil?

      response = Net::HTTP.get_response(URI.parse(@url))
      @status_code = response.code
      @origin_response = response

      handle_response(@origin_response, limit)
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
  end
end
