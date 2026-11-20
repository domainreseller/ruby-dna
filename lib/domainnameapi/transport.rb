# frozen_string_literal: true

require 'json'
require 'net/http'
require 'openssl'
require 'uri'

module DomainNameApi
  # The exact HTTP request the client sends (see Client#prepare). It carries
  # your credentials in its headers; #inspect masks the API key.
  PreparedRequest = Struct.new(:http_method, :url, :headers, :body, :timeout, :open_timeout, keyword_init: true) do
    def inspect
      shown = headers.to_h.merge('X-API-KEY' => '[masked]')
      "#<DomainNameApi::PreparedRequest #{http_method} #{url} headers=#{shown.inspect} body=#{body.inspect}>"
    end
    alias_method :to_s, :inspect

    # The parsed JSON body, or nil.
    def json
      body.nil? ? nil : JSON.parse(body)
    end
  end

  # What a transport returns: the status, the headers (any case) and the body.
  HTTPResponse = Struct.new(:status, :headers, :body, keyword_init: true)

  # Soft-quota state after a request, from the X-Quota-* headers. The quota never
  # rejects requests: once +used+ exceeds +limit+, the API delays each response
  # (by +delay+ seconds, at most 5) until points decay by 20% per minute. Lookups
  # cost 1 point, everything else 10.
  Quota = Struct.new(:scope, :cost, :used, :limit, :delay, :reset, keyword_init: true) do
    # @api private
    def self.from_headers(headers)
      return nil if headers['x-quota-limit'].nil? && headers['x-quota-used'].nil?

      f = ->(name) { Util.to_float(headers[name]) || 0.0 }
      new(scope: headers['x-quota-scope'], cost: f.call('x-quota-cost'), used: f.call('x-quota-used'),
          limit: f.call('x-quota-limit'), delay: f.call('x-quota-delay'), reset: f.call('x-quota-reset'))
    end
  end

  # A completed exchange (see Client#execute).
  class Response
    # HTTP status of the final attempt.
    attr_reader :status
    # Response headers, with lower-case names.
    attr_reader :headers
    # The raw body.
    attr_reader :body
    # Identifies the request; quote it when contacting support.
    attr_reader :correlation_id
    # The Quota after the request, or nil.
    attr_reader :quota
    # Total time in seconds, including retries and pacing.
    attr_reader :duration
    # Number of HTTP attempts.
    attr_reader :attempts
    # The request that was sent.
    attr_reader :request
    # The decoded result (see BaseRequest#decode).
    attr_accessor :value

    def initialize(status:, headers:, body:, correlation_id:, quota:, duration:, attempts:, request:)
      @status = status
      @headers = headers
      @body = body.to_s
      @correlation_id = correlation_id
      @quota = quota
      @duration = duration
      @attempts = attempts
      @request = request
    end

    def success?
      status.between?(200, 299)
    end

    # A header by name, in any case.
    def header(name)
      headers[name.to_s.downcase]
    end

    # The parsed JSON body; nil when the body is empty or not JSON.
    def data
      return @data if defined?(@data)

      @data = begin
        parse
      rescue JSON::ParserError
        nil
      end
    end

    # The parsed JSON body; raises DecodeError when the body is not JSON.
    def data!
      parse
    rescue JSON::ParserError => e
      raise DecodeError.new("#{request.http_method} #{request.path}: the response is not valid JSON: #{e.message}", self)
    end

    def inspect
      "#<DomainNameApi::Response #{status} #{request&.http_method} #{request&.path} " \
        "correlation_id=#{correlation_id.inspect} attempts=#{attempts}>"
    end

    private

    def parse
      text = body.strip
      text.empty? ? nil : JSON.parse(text)
    end
  end

  # One step of a request, for logging and metrics (see the +on_trace:+ option).
  # It never contains the API key. +body+ is the request or response body,
  # truncated to 16 KiB: it can hold contact details and auth codes, so mask it
  # before storing it.
  TraceEvent = Struct.new(:kind, :http_method, :url, :safety, :correlation_id, :attempt, :status, :duration,
                          :wait, :body, :quota, :error, keyword_init: true) do
    # :request (an attempt is about to be sent), :response (an attempt finished,
    # with a status or an error) or :retry (the client waits and tries again).
    def request?
      kind == :request
    end

    def response?
      kind == :response
    end

    def retry?
      kind == :retry
    end
  end

  # The default transport: Net::HTTP from the standard library.
  #
  # Any object with a +call(prepared_request)+ method can replace it (the
  # +transport:+ option of Client), for a proxy, a connection pool or tests. It
  # gets a PreparedRequest and returns an HTTPResponse (or a Hash with :status,
  # :headers and :body, or a [status, headers, body] Array). Redirects must not
  # be followed: the API answers 302 for an unknown or suspended reseller ID.
  # Network failures are raised as exceptions; the client wraps them in
  # NetworkError.
  class NetHTTPTransport
    METHODS = {
      'GET' => Net::HTTP::Get, 'POST' => Net::HTTP::Post, 'PUT' => Net::HTTP::Put,
      'DELETE' => Net::HTTP::Delete, 'PATCH' => Net::HTTP::Patch
    }.freeze

    # +proxy+ is a URL such as "http://user:pass@proxy:8080". TLS verification is
    # on; +ca_file+ adds your own CA bundle (for a TLS-inspecting proxy).
    def initialize(proxy: nil, ca_file: nil, verify_mode: OpenSSL::SSL::VERIFY_PEER)
      @proxy = proxy && URI.parse(proxy)
      @ca_file = ca_file
      @verify_mode = verify_mode
    end

    def call(request)
      uri = URI.parse(request.url)
      http = if @proxy
               Net::HTTP.new(uri.host, uri.port, @proxy.host, @proxy.port, @proxy.user, @proxy.password)
             else
               Net::HTTP.new(uri.host, uri.port)
             end
      http.use_ssl = uri.scheme == 'https'
      if http.use_ssl?
        http.verify_mode = @verify_mode
        http.ca_file = @ca_file if @ca_file
      end
      http.open_timeout = request.open_timeout
      http.read_timeout = request.timeout
      http.write_timeout = request.timeout
      http.ssl_timeout = request.open_timeout if http.use_ssl?

      klass = METHODS.fetch(request.http_method) { raise ArgumentError, "unsupported HTTP method #{request.http_method}" }
      req = klass.new(uri.request_uri)
      request.headers.each { |k, v| req[k] = v }
      req.body = request.body unless request.body.nil?

      res = http.start { |h| h.request(req) }
      headers = {}
      res.each_header { |k, v| headers[k] = v }
      body = res.body.to_s.dup.force_encoding(Encoding::UTF_8)
      HTTPResponse.new(status: res.code.to_i, headers: headers, body: body)
    end
  end

  # Spaces requests per rate-limit class: 5 requests per second overall, 2 per
  # second for domain search and one DNS zone call per second. Domain info and
  # the TLD catalogue are not rate limited. Thread-safe. @api private
  class Pacer
    def initialize
      @mutex = Mutex.new
      @next = Hash.new(0.0)
    end

    # The class and minimum gap (seconds) of a path.
    def self.classify(path)
      p = path.to_s.downcase
      if p.start_with?('/api/v1/domains/zones') then ['zones', 1.0]
      elsif ['/api/v1/domains/search', '/api/v1/domains/bulk-search'].include?(p) then ['search', 0.5]
      elsif p == '/api/v1/domains/info' || p.start_with?('/api/v1/products/tlds') then [nil, 0.0]
      else ['general', 0.2]
      end
    end

    # Reserves a slot for a request to path and returns how many seconds to
    # wait before sending it.
    def reserve(path, now = Process.clock_gettime(Process::CLOCK_MONOTONIC))
      klass, gap = self.class.classify(path)
      return 0.0 if klass.nil?

      @mutex.synchronize do
        at = [@next[klass], now].max
        @next[klass] = at + gap
        # Searches also count against the overall budget.
        @next['general'] = [@next['general'], at + 0.2].max if klass == 'search'
        at - now
      end
    end
  end
end
