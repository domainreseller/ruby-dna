# frozen_string_literal: true

require_relative 'test_helper'

class TelemetryTest < Minitest::Test
  include DnaTestSupport

  DSN = 'https://publickey@sentry.example.test/42'

  def setup
    @transport = FakeTransport.new
    @sender = CapturingSender.new
    @client = DomainNameApi::Client.new(RESELLER, API_KEY, false, transport: @transport, sentry_dsn: DSN,
                                                                  zone_min_interval: 0)
    @client.set_telemetry_sender(@sender)
  end

  def error_events
    @sender.events.select { |e| e[:payload]['level'] == 'error' }
  end

  def test_default_dsn_is_empty_and_telemetry_is_a_no_op
    assert_equal '', DomainNameApi::Telemetry::DEFAULT_SENTRY_DSN
    client = DomainNameApi::Client.new(RESELLER, API_KEY, false, transport: @transport)
    client.set_telemetry_sender(@sender)
    @transport.push(500, '{"error":{"message":"Server exploded"}}')
    client.get_details('example.com')
    assert_empty @sender.events
  end

  def test_error_event_payload
    @transport.push(500, '{"error":{"code":"X","message":"Server exploded at 10.1.2.3 for \'example.com\' code 12345"}}')
    @client.get_details('example.com')
    assert_equal 1, error_events.size
    event = error_events.first
    payload = event[:payload]
    assert_equal 'https://sentry.example.test/api/42/store/', event[:url]
    assert_equal 'X-Sentry-Auth: Sentry sentry_version=7, sentry_client=ruby-dna/1.0.0, sentry_key=publickey', event[:auth]
    assert_equal true, event[:resolve_ip]
    assert_equal 'DomainNameAPI-Ruby', payload['tags']['application']
    assert_equal '1.0.0', payload['tags']['library_version']
    assert_equal '1.0.0', payload['release']
    assert_equal 'production', payload['environment']
    assert_equal RESELLER, payload['tags']['reseller']
    assert_equal 'request:GET domains/info', payload['tags']['operation']
    assert_equal 'API_500', payload['tags']['api_code']
    assert_equal '500', payload['tags']['status_code']
    assert_equal '10.1.2.3', payload['tags']['ip_value']
    assert_equal 'API_500: Server exploded at {ip} for {v} code {n}', payload['message']['formatted']
    assert_equal ['dna', 'DomainNameAPI-Ruby', 'request:GET domains/info', payload['message']['formatted']],
                 payload['fingerprint']
    assert_equal 'Server exploded at 10.1.2.3 for \'example.com\' code 12345', payload['extra']['original_message']
    assert_equal({ 'DomainName' => 'example.com' }, payload['extra']['request_data']['payload'])
    refute_empty payload['exception']['values'][0]['stacktrace']['frames']
  end

  def test_domain_tag_and_credentials_are_masked
    @transport.push(400, '{"message":"Auth code is not valid.","authCode":"SECRET-EPP"}')
    @client.check_transfer('example.com', 'SECRET-EPP')
    payload = error_events.first[:payload]
    assert_equal 'example.com', payload['tags']['domain']
    assert_equal '***', payload['extra']['request_data']['payload']['authCode']
    assert_equal '***', payload['extra']['response_data']['authCode']
    refute_includes JSON.generate(payload), 'SECRET-EPP'
    refute_includes JSON.generate(payload), API_KEY
  end

  def test_mask_function
    rest = @client.rest
    masked = rest.send(:telemetry_mask, {
                         'authCode' => 'a', 'eppCode' => 'b', 'password' => 'c', 'X-API-KEY' => 'd', 'apiKey' => 'e',
                         'token' => 'f', 'secretThing' => 'g', 'empty_token' => '', 'null_auth' => nil,
                         'nested' => [{ 'Password' => 'h', 'name' => 'keep' }], 'domainName' => 'example.com'
                       })
    assert_equal({
                   'authCode' => '***', 'eppCode' => '***', 'password' => '***', 'X-API-KEY' => '***', 'apiKey' => '***',
                   'token' => '***', 'secretThing' => '***', 'empty_token' => '', 'null_auth' => nil,
                   'nested' => [{ 'Password' => '***', 'name' => 'keep' }], 'domainName' => 'example.com'
                 }, masked)
  end

  def test_ignored_errors_are_not_sent
    @transport.push(404, '{"error":{"message":"The domain name you requested could not be found"}}')
    @client.get_details('missing.com')
    @transport.push(302, '')
    @client.get_details('example.com')
    assert_empty error_events
  end

  def test_disabled_reporting_sends_nothing
    @client.set_error_reporting_enabled(false)
    @transport.push(500, '{"error":{"message":"Server exploded"}}')
    @client.get_details('example.com')
    assert_empty @sender.events
  end

  def test_minimal_mode
    @client.set_telemetry_minimal(true)
    @transport.push(500, '{"error":{"message":"Server exploded"}}')
    @client.get_details('example.com')
    event = error_events.first
    payload = event[:payload]
    assert_equal false, event[:resolve_ip]
    refute payload['tags'].key?('domain')
    refute payload['tags'].key?('ip_address')
    refute payload['tags'].key?('vhost_user')
    refute payload['tags'].key?('url')
    assert_equal({ 'method' => 'GET', 'endpoint' => '/api/v1/domains/info' }, payload['extra']['request_data'])
    assert_equal({ 'http_code' => 500 }, payload['extra']['response_data'])
    assert_equal RESELLER, payload['tags']['reseller']
  end

  def test_ote_environment
    client = DomainNameApi::Client.new(RESELLER, API_KEY, true, transport: @transport, sentry_dsn: DSN)
    client.set_telemetry_sender(@sender)
    @transport.push(500, '{"error":{"message":"Server exploded"}}')
    client.get_details('example.com')
    assert_equal 'ote', error_events.first[:payload]['environment']
  end

  def test_empty_message_uses_api_code
    @transport.push(500, '')
    @client.get_details('example.com')
    assert_equal 'API_500: HTTP {n} - Internal Server Error', error_events.first[:payload]['message']['formatted']
  end

  def test_transport_errors_are_reported
    @transport.instance_variable_get(:@queue) << DomainNameApi::TransportError.new('timed out', 28)
    @client.get_details('example.com')
    payload = error_events.first[:payload]
    assert_equal 'API_28', payload['tags']['api_code']
    assert_includes payload['extra']['original_message'], 'connection timed out'
  end

  def test_slow_successful_calls_send_a_transaction
    slow = lambda do |_req|
      sleep 1.05
      DomainNameApi::Response.new(status: 200, body: '{"resellerId":"r"}', headers: {})
    end
    @client.set_transport(slow)
    @client.get_reseller_details
    txn = @sender.events.find { |e| e[:payload]['type'] == 'transaction' }
    refute_nil txn
    payload = txn[:payload]
    assert_equal 'API.request:GET deposit/accounts/me', payload['transaction']
    assert_equal 'ok', payload['contexts']['trace']['status']
    assert_equal 'GET https://api.domainresellerapi.com', payload['spans'][0]['description']
    assert_equal 200, payload['spans'][0]['data']['http.response.status_code']
    assert_operator payload['measurements']['duration']['value'], :>, 1000
  end

  def test_failed_calls_send_no_transaction
    @transport.push(500, '{"error":{"message":"Server exploded"}}')
    @client.get_details('example.com')
    assert(@sender.events.none? { |e| e[:payload]['type'] == 'transaction' })
  end

  def test_sender_failure_never_reaches_the_caller
    @client.set_telemetry_sender(->(*) { raise 'sentry is down' })
    @transport.push(500, '{"error":{"message":"Server exploded"}}')
    assert_equal 'ERROR', @client.get_details('example.com')['result']
  end

  def test_trace_status_mapping
    rest = @client.rest
    {
      'API_401' => 'unauthenticated', 'API_403' => 'permission_denied', 'API_404' => 'not_found',
      'API_504' => 'deadline_exceeded', 'API_-1' => 'unavailable', 'API_500' => 'internal_error',
      'API_422' => 'invalid_argument', 'API_2302' => 'unknown', 'nothing' => 'unknown'
    }.each do |code, status|
      assert_equal status, rest.send(:map_trace_status, false, code), code
    end
    assert_equal 'ok', rest.send(:map_trace_status, true, nil)
  end

  def test_parse_dsn
    assert_nil DomainNameApi::Telemetry.parse_dsn('')
    assert_nil DomainNameApi::Telemetry.parse_dsn('https://sentry.example.test/1')
    parsed = DomainNameApi::Telemetry.parse_dsn('https://pub:sec@sentry.example.test/7')
    assert_equal({ host: 'sentry.example.test', project_id: '7', public_key: 'pub', secret_key: 'sec' }, parsed)
  end
end
