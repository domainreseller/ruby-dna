# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path('../lib', __dir__)
require 'domainnameapi'
require 'minitest/autorun'
require 'json'
require 'uri'

module DnaTestSupport
  RESELLER = '00000000-0000-4000-8000-000000000001'
  API_KEY = 'conformance-api-key'

  # Transport double: serves queued responses in order and records requests.
  class FakeTransport
    attr_reader :requests

    def initialize(responses = [])
      @queue = responses.dup
      @requests = []
    end

    def push(status, body, headers = {})
      @queue << { status: status, body: body, headers: headers }
      self
    end

    def call(request)
      @requests << request
      raise Minitest::Assertion, "unexpected request #{request[:method]} #{request[:url]}" if @queue.empty?

      item = @queue.shift
      raise item if item.is_a?(Exception)

      DomainNameApi::Response.new(status: item[:status] || item['status'], body: item[:body] || item['body'],
                                  headers: item[:headers] || {})
    end

    def remaining
      @queue.size
    end
  end

  # Telemetry sender double: keeps every event instead of posting it.
  class CapturingSender
    attr_reader :events

    def initialize
      @events = []
    end

    def call(url, payload, auth_header, resolve_ip)
      @events << { url: url, payload: payload, auth: auth_header, resolve_ip: resolve_ip }
      nil
    end
  end

  def new_client(transport, **opts)
    client = DomainNameApi::Client.new(RESELLER, API_KEY, false, transport: transport, zone_min_interval: 0, **opts)
    client.set_error_reporting_enabled(false)
    client
  end

  # PHP parse_str() of a query string into a (possibly nested) Hash.
  def parse_query(query)
    out = {}
    return out if query.nil? || query.empty?

    query.split('&').each do |pair|
      next if pair.empty?

      k, v = pair.split('=', 2)
      key = URI.decode_www_form_component(k.to_s)
      val = URI.decode_www_form_component(v.to_s)
      base, *rest = key.scan(/\A[^\[]+|\[[^\]]*\]/)
      keys = [base] + rest.map { |r| r[1...-1] }
      node = out
      keys[0...-1].each_with_index do |part, i|
        part = node.size.to_s if part.empty?
        node[part] = {} unless node[part].is_a?(Hash)
        node = node[part]
        keys[i + 1] = node.size.to_s if keys[i + 1].empty? && i + 1 == keys.size - 1
      end
      node[keys.last] = val
    end
    out
  end
end
