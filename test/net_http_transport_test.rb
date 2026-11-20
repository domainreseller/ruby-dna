# frozen_string_literal: true

require_relative 'test_helper'
require 'socket'

# The default transport against a tiny HTTP server on 127.0.0.1.
class NetHTTPTransportTest < Minitest::Test
  include DomainNameApi
  include DnaTest

  # Answers each connection with the next canned response (or stays silent
  # when the response is :hang) and records what it received.
  class LocalServer
    attr_reader :received, :port

    def initialize(*responses)
      @responses = responses
      @received = Queue.new
      @server = TCPServer.new('127.0.0.1', 0)
      @port = @server.addr[1]
      @thread = Thread.new { serve }
    end

    def url
      "http://127.0.0.1:#{port}"
    end

    def close
      @thread.kill
      @server.close
    rescue IOError
      nil
    end

    private

    def serve
      @responses.each do |response|
        socket = @server.accept
        @received << read_request(socket)
        if response == :hang
          sleep 5
        else
          socket.write(response)
        end
        socket.close
      end
    rescue IOError, SystemCallError
      nil
    end

    def read_request(socket)
      head = +''
      head << socket.readpartial(4096) until head.include?("\r\n\r\n")
      header, body = head.split("\r\n\r\n", 2)
      lines = header.split("\r\n")
      length = lines.grep(/\Acontent-length:/i).first.to_s.split(':', 2).last.to_i
      body << socket.readpartial(4096) while body.bytesize < length
      { request_line: lines.first, headers: lines.drop(1), body: body }
    end
  end

  def response(status, body, extra = [])
    reason = { 200 => 'OK', 302 => 'Found', 404 => 'Not Found' }.fetch(status, 'X')
    headers = ["HTTP/1.1 #{status} #{reason}", 'Content-Type: application/json', "Content-Length: #{body.bytesize}",
               'Connection: close', *extra]
    "#{headers.join("\r\n")}\r\n\r\n#{body}"
  end

  def client_for(server, **options)
    Client.new(reseller_id: RESELLER_ID, api_key: API_KEY, base_url: server.url, pacing: false, **options)
  end

  def test_request_and_response
    server = LocalServer.new(response(200, '{"success":true,"domainId":"d1"}', ['X-Correlation-Id: srv-1']))
    res = client_for(server).execute(DomainRenewRequest.new(domain_name: 'example.com', years: 1))
    got = server.received.pop
    assert_equal 'POST /api/v1/domains/renew HTTP/1.1', got[:request_line]
    headers = got[:headers].map { |h| h.split(': ', 2) }.to_h { |k, v| [k.downcase, v] }
    assert_equal RESELLER_ID, headers['__reseller']
    assert_equal API_KEY, headers['x-api-key']
    assert_equal 'application/json', headers['content-type']
    assert_includes headers['user-agent'], 'DomainNameAPI-Ruby/'
    assert_equal '{"domainName":"example.com","period":1}', got[:body]
    assert_equal 'd1', res.value.domain_id
    assert_equal 'srv-1', res.correlation_id
    assert_equal 'application/json', res.header('Content-Type')
  ensure
    server&.close
  end

  def test_redirects_are_not_followed
    server = LocalServer.new(response(302, '', ['Location: /Error/Suspend']))
    e = assert_raises(APIError) { client_for(server).account.get }
    assert_equal ErrorCode::INVALID_RESELLER, e.code
  ensure
    server&.close
  end

  def test_error_body
    body = '{"error":{"code":"Dna.DomainService:Domain:10007","message":"not found"}}'
    server = LocalServer.new(response(404, body))
    e = assert_raises(APIError) { client_for(server).domains.info('example.com') }
    assert e.not_found?
    assert_equal ErrorCode::DOMAIN_NOT_FOUND, e.code
  ensure
    server&.close
  end

  def test_timeout
    server = LocalServer.new(:hang)
    client = client_for(server, timeout: 0.3, retries: 0)
    e = assert_raises(NetworkError) { client.account.get }
    assert e.timeout?
    refute e.outcome_unknown?
  ensure
    server&.close
  end

  def test_connection_refused
    port = TCPServer.open('127.0.0.1', 0) { |s| s.addr[1] }
    client = Client.new(reseller_id: 'r', api_key: 'k', base_url: "http://127.0.0.1:#{port}", pacing: false,
                        retries: 0, open_timeout: 1)
    e = assert_raises(NetworkError) { client.account.get }
    # Linux refuses at once; Windows retries the connection until the open timeout.
    assert(e.original.is_a?(SystemCallError) || e.original.is_a?(Timeout::Error), e.original.inspect)
    assert_equal '/api/v1/deposit/accounts/me', e.path
  end
end
