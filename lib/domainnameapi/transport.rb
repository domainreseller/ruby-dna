# frozen_string_literal: true

require 'net/http'
require 'openssl'
require 'timeout'
require 'uri'

module DomainNameApi
  # Raised by a transport when the request never produced an HTTP response
  # (timeout, DNS failure, TLS error, connection reset). `code` follows the
  # curl error numbers php-dna reports (28 = timeout, 6 = DNS, 7 = connect,
  # 35/60 = TLS, 52 = empty reply, 56 = receive failure).
  class TransportError < StandardError
    attr_reader :code

    def initialize(message, code = 56)
      super(message)
      @code = code
    end

    def timeout?
      code == 28
    end
  end

  # An HTTP response as seen by the client.
  Response = Struct.new(:status, :body, :headers, keyword_init: true)

  # Default transport: Net::HTTP from the standard library.
  #
  # Any object responding to `call(request)` can replace it (see
  # Client#set_transport). `request` is a Hash with :method, :url, :headers,
  # :body (String or nil), :timeout, :connect_timeout and :verify_ssl; the
  # result must be a Response (or a Hash with :status, :body, :headers), or
  # the transport raises TransportError.
  class NetHttpTransport
    def call(request)
      uri = URI.parse(request[:url])
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == 'https'
      http.verify_mode = request[:verify_ssl] == false ? OpenSSL::SSL::VERIFY_NONE : OpenSSL::SSL::VERIFY_PEER
      http.open_timeout = request[:connect_timeout]
      http.read_timeout = request[:timeout]
      http.write_timeout = request[:timeout] if http.respond_to?(:write_timeout=)
      http.ssl_timeout = request[:connect_timeout] if http.use_ssl?

      req = build_request(request[:method], uri, request[:headers], request[:body])
      res = with_deadline(request[:timeout]) { http.start { |h| h.request(req) } }

      headers = {}
      res.each_header { |k, v| headers[k] = v }
      Response.new(status: res.code.to_i, body: res.body.to_s.dup.force_encoding(Encoding::UTF_8), headers: headers)
    rescue TransportError
      raise
    rescue Net::OpenTimeout, Net::ReadTimeout, Net::WriteTimeout, Timeout::Error => e
      raise TransportError.new(e.message, 28)
    rescue SocketError => e
      raise TransportError.new(e.message, 6)
    rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH, Errno::ENETUNREACH => e
      raise TransportError.new(e.message, 7)
    rescue OpenSSL::SSL::SSLError => e
      raise TransportError.new(e.message, e.message =~ /certificate/i ? 60 : 35)
    rescue EOFError => e
      raise TransportError.new(e.message, 52)
    rescue IOError, SystemCallError => e
      raise TransportError.new(e.message, 56)
    end

    private

    def build_request(method, uri, headers, body)
      klass = {
        'GET' => Net::HTTP::Get, 'POST' => Net::HTTP::Post,
        'PUT' => Net::HTTP::Put, 'DELETE' => Net::HTTP::Delete
      }.fetch(method) { raise ArgumentError, "unsupported HTTP method #{method}" }
      req = klass.new(uri.request_uri)
      headers.each { |k, v| req[k] = v }
      req.body = body unless body.nil?
      req
    end

    # Total-time limit (curl CURLOPT_TIMEOUT) on top of the per-phase ones.
    def with_deadline(seconds, &block)
      return yield if seconds.nil? || seconds.to_f <= 0

      Timeout.timeout(seconds.to_f, &block)
    end
  end
end
