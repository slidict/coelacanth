# frozen_string_literal: true

require "uri"

module Coelacanth
  module Robots
    DEFAULT_USER_AGENT = "CoelacanthBot"
    RULE_STRUCT = Struct.new(:type, :pattern, :regex, :length, keyword_init: true)

    module_function

    def allowed?(uri, user_agent: user_agent())
      rules = rules_for(uri)
      return true if rules.empty?

      agent_key = normalize_agent(user_agent)
      agent_rules = rules[agent_key]
      agent_rules = rules["*"] if agent_rules.nil? || agent_rules.empty?

      return true if agent_rules.nil? || agent_rules.empty?

      evaluate(agent_rules, normalize_path(uri))
    end

    def user_agent
      ENV.fetch("COELACANTH_HTTP_USER_AGENT", DEFAULT_USER_AGENT)
    end

    def rules_for(uri)
      robots_cache[cache_key(uri)] ||= fetch_rules(uri)
    end

    def clear_cache!
      robots_cache.clear
    end

    def robots_cache
      @robots_cache ||= {}
    end

    def fetch_rules(uri)
      response = Coelacanth::HTTP.raw_get_response(robots_uri_for(uri))
      return {} unless response.is_a?(Net::HTTPSuccess)

      parse_robots(response.body.to_s)
    rescue Coelacanth::TimeoutError, StandardError
      {}
    end

    def robots_uri_for(uri)
      klass = uri.scheme == "https" ? URI::HTTPS : URI::HTTP
      port = uri.port
      port = nil if port == default_port_for(uri.scheme)

      klass.build(host: uri.host, path: "/robots.txt", port: port)
    end

    def parse_robots(body)
      rules = Hash.new { |hash, key| hash[key] = [] }
      current_agents = []
      last_directive = nil

      body.each_line do |line|
        sanitized = sanitize_line(line)
        if sanitized.empty?
          current_agents = []
          last_directive = nil
          next
        end

        field, value = sanitized.split(":", 2)
        next if value.nil?

        field = field.strip.downcase
        value = value.strip

        case field
        when "user-agent"
          current_agents = [] unless last_directive == :user_agent
          agent = normalize_agent(value)
          current_agents << agent unless current_agents.include?(agent)
          last_directive = :user_agent
        when "allow", "disallow"
          last_directive = field.to_sym
          next if value.empty?

          current_agents = ["*"] if current_agents.empty?
          rule = build_rule(type: last_directive, value: value)
          current_agents.each do |agent|
            rules[agent] << rule
          end
        else
          last_directive = field.to_sym
        end
      end

      rules
    end

    def sanitize_line(line)
      line.split("#", 2).first.to_s.strip
    end

    def build_rule(type:, value:)
      pattern = value.start_with?("/") ? value : "/#{value}"
      escaped = Regexp.escape(pattern)
      escaped = escaped.gsub("\\*", ".*")
      escaped = escaped.gsub("\\$", "\\z")
      regex = Regexp.new("\\A" + escaped)
      RULE_STRUCT.new(type: type, pattern: pattern, regex: regex, length: pattern.length)
    end

    def evaluate(rules, path)
      matches = rules.select { |rule| rule.regex.match?(path) }
      return true if matches.empty?

      longest_allow = matches.select { |rule| rule.type == :allow }.max_by(&:length)
      longest_disallow = matches.select { |rule| rule.type == :disallow }.max_by(&:length)

      return true if longest_disallow.nil?
      return true if longest_allow && longest_allow.length >= longest_disallow.length

      false
    end

    def normalize_path(uri)
      path = uri.path
      path = "/" if path.nil? || path.empty?
      path
    end

    def normalize_agent(agent)
      agent.to_s.strip.downcase
    end

    def cache_key(uri)
      port = uri.port
      default_port = default_port_for(uri.scheme)
      port_part = port && port != default_port ? ":#{port}" : ""
      "#{uri.scheme}://#{uri.host}#{port_part}"
    end

    def default_port_for(scheme)
      scheme == "https" ? URI::HTTPS.default_port : URI::HTTP.default_port
    end
  end
end
