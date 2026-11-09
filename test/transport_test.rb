# frozen_string_literal: true

require_relative 'test_helper'
require 'socket'

# NetHttpTransport against a throwaway local socket server (no real network).
class TransportTest < Minitest::Test
  def with_server(handler)
    server = TCPServer.new('127.0.0.1', 0)
    port = server.addr[1]
    thread = Thread.new do
      loop do
        sock = server.accept
        Thread.new(sock) do |s|
          begin
            handler.call(s)
          rescue StandardError
            nil
          ensure
            s.close unless s.closed?
          end
        end
      end
    rescue IOError
      nil
    end
    yield port
  ensure
    server&.close
    thread&.kill
  end

  def read_request(sock)
    head = +''
    head << sock.readpartial(4096) until head.include?("\r\n\r\n")
    header_text, body = head.split("\r\n\r\n", 2)
    length = header_text[/content-length:\s*(\d+)/i, 1].to_i
    body << sock.readpartial(4096) while body.bytesize < length
    [header_text, body]
  end

  def test_round_trip
    seen = Queue.new
    handler = lambda do |s|
      seen << read_request(s)
      payload = '{"ok":true}'
      s.write("HTTP/1.1 201 Created\r\nContent-Type: application/json\r\nContent-Length: #{payload.bytesize}\r\nConnection: close\r\n\r\n#{payload}")
    end
    with_server(handler) do |port|
      response = DomainNameApi::NetHttpTransport.new.call(
        method: 'POST', url: "http://127.0.0.1:#{port}/api/v1/domains/lock?x=1",
        headers: { 'X-API-KEY' => 'k', 'User-Agent' => 'DomainNameAPI-Ruby/1.0.0', 'Content-Type' => 'application/json' },
        body: '{"domainName":"example.com"}', timeout: 5, connect_timeout: 2, verify_ssl: true
      )
      assert_equal 201, response.status
      assert_equal '{"ok":true}', response.body
      head, body = seen.pop
      assert_match %r{\APOST /api/v1/domains/lock\?x=1 HTTP/1.1}, head
      assert_match(/^x-api-key: k/i, head)
      assert_match(%r{^user-agent: DomainNameAPI-Ruby/1.0.0}i, head)
      assert_equal '{"domainName":"example.com"}', body
    end
  end

  def test_timeout_raises_transport_error_28
    handler = ->(s) { sleep 3; s.write("HTTP/1.1 200 OK\r\n\r\n") }
    with_server(handler) do |port|
      error = assert_raises(DomainNameApi::TransportError) do
        DomainNameApi::NetHttpTransport.new.call(method: 'GET', url: "http://127.0.0.1:#{port}/", headers: {},
                                                 body: nil, timeout: 0.3, connect_timeout: 0.3, verify_ssl: true)
      end
      assert_equal 28, error.code
      assert error.timeout?
    end
  end

  def test_connection_refused
    port = TCPServer.open('127.0.0.1', 0) { |s| s.addr[1] }
    error = assert_raises(DomainNameApi::TransportError) do
      DomainNameApi::NetHttpTransport.new.call(method: 'GET', url: "http://127.0.0.1:#{port}/", headers: {},
                                               body: nil, timeout: 1, connect_timeout: 1, verify_ssl: true)
    end
    assert_equal 7, error.code
  end

  def test_client_maps_a_real_timeout_to_the_error_envelope
    handler = ->(s) { sleep 3; s.write("HTTP/1.1 200 OK\r\n\r\n") }
    with_server(handler) do |port|
      short = DomainNameApi::NetHttpTransport.new
      def short.call(request)
        super(request.merge(timeout: 0.3, connect_timeout: 0.3))
      end
      client = DomainNameApi::Client.new('r', 'k', false, transport: short)
      client.set_error_reporting_enabled(false)
      client.set_service_url("http://127.0.0.1:#{port}/api/v1")
      result = client.enable_theft_protection_lock('example.com')
      assert_equal 'ERROR', result['result']
      assert_equal 'API_28', result['error']['Code']
      assert_match(/\ACould not reach the DomainNameAPI service: the connection timed out\./, result['error']['Message'])
    end
  end
end
