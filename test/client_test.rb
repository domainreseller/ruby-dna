# frozen_string_literal: true

require_relative 'test_helper'
require 'logger'
require 'stringio'

class ClientTest < Minitest::Test
  include DomainNameApi
  include DnaTest

  def test_new_client
    c = Client.new(reseller_id: " #{RESELLER_ID} ", api_key: " #{API_KEY}\n")
    assert_equal Client::PRODUCTION_URL, c.base_url
    assert_equal :production, c.environment
    assert_equal RESELLER_ID, c.reseller_id
    assert c.pacing?
    refute c.read_only?
    refute_includes c.inspect, API_KEY

    c = Client.new(reseller_id: 'r', api_key: 'k', environment: :ote)
    assert_equal Client::OTE_URL, c.base_url
    assert c.ote?
    c = Client.new(reseller_id: 'r', api_key: 'k', environment: 'test')
    assert_equal :ote, c.environment
    c = Client.new(reseller_id: 'r', api_key: 'k', base_url: 'http://localhost:8080/')
    assert_equal 'http://localhost:8080', c.base_url
    assert_equal :production, c.environment

    assert_raises(MissingCredentialsError) { Client.new(reseller_id: '', api_key: 'k') }
    assert_raises(MissingCredentialsError) { Client.new(reseller_id: 'r', api_key: ' ') }
    assert_raises(ConfigurationError) { Client.new(reseller_id: 'r', api_key: 'k', environment: :staging) }
    assert_raises(ConfigurationError) { Client.new(reseller_id: 'r', api_key: 'k', base_url: 'ftp://x') }
    assert_raises(ConfigurationError) { Client.new(reseller_id: 'r', api_key: 'k', base_url: 'not a url') }
    assert_raises(ArgumentError) { Client.new(reseller_id: 'r', api_key: 'k', colour: :blue) }
  end

  def test_parse_environment
    { 'production' => :production, 'prod' => :production, '' => :production, nil => :production,
      'false' => :production, '0' => :production, false => :production, 'ote' => :ote, 'TEST' => :ote,
      'sandbox' => :ote, 'true' => :ote, '1' => :ote, 'on' => :ote, 'yes' => :ote, true => :ote,
      :ote => :ote }.each do |input, want|
      assert_equal want, Client.parse_environment(input), input.inspect
    end
    assert_raises(ConfigurationError) { Client.parse_environment('staging') }
  end

  def test_from_env
    env = { 'DNA_RESELLER_ID' => 'r', 'DNA_API_KEY' => 'k', 'DNA_ENV' => 'ote' }
    c = Client.from_env(env)
    assert_equal :ote, c.environment
    assert_equal Client::OTE_URL, Client.from_env('DNA_RESELLER_ID' => 'r', 'DNA_API_KEY' => 'k',
                                                  'DNA_TEST_MODE' => 'true').base_url
    c = Client.from_env(env.merge('DNA_BASE_URL' => 'http://127.0.0.1:9'), read_only: true)
    assert_equal 'http://127.0.0.1:9', c.base_url
    assert c.read_only?
    assert_equal :production, Client.from_env(env, environment: :production).environment
    error = assert_raises(MissingCredentialsError) { Client.from_env('DNA_API_KEY' => 'k') }
    assert_includes error.message, 'DNA_RESELLER_ID'
    assert_raises(ConfigurationError) { Client.from_env(env.merge('DNA_ENV' => 'staging')) }
  end

  def test_request_headers_and_body
    client, api = fake_client(ok('{"domainName":"example.com","authCode":"X"}'), user_agent: 'my-panel/1.4')
    assert_equal 'X', client.domains.update_auth_code(' example.com ')
    req = api.last
    assert_equal 'PUT', req.http_method
    assert_equal 'https://api.domainresellerapi.com/api/v1/domains/auth', req.url
    assert_equal API_KEY, req.headers['X-API-KEY']
    assert_equal RESELLER_ID, req.headers['__reseller']
    assert_equal 'application/json', req.headers['Accept']
    assert_equal 'application/json', req.headers['Content-Type']
    assert_equal "my-panel/1.4 #{USER_AGENT}", req.headers['User-Agent']
    assert_match(/\A\h{32}\z/, req.headers['X-Correlation-ID'])
    assert_equal({ 'domainName' => 'example.com' }, api.json)
    assert_equal 60, req.timeout
    assert_equal 10, req.open_timeout

    client.domains.info('example.com')
    assert_nil api.last.body
    refute api.last.headers.key?('Content-Type')
  end

  def test_validation_stops_the_request
    client, api = fake_client(ok)
    e = assert_raises(InputError) { client.domains.renew('', years: 0) }
    assert_equal 'DomainRenewRequest', e.request
    assert_equal %w[domain_name years], e.fields.map(&:field)
    assert_equal :invalid_input, e.kind
    assert_empty api.requests
    assert_raises(ArgumentError) { client.call(nil) }
    assert_raises(ArgumentError) { client.call('GET /x') }
  end

  def test_read_only
    client, api = fake_client(ok('{"resellerId":"r"}'), read_only: true)
    client.account.get
    e = assert_raises(ReadOnlyError) { client.domains.renew('example.com', years: 1) }
    assert_equal :billable, e.safety
    assert_equal 'POST', e.http_method
    assert_equal :read_only, e.kind
    assert_raises(ReadOnlyError) { client.dns.delete('example.com', name: 'www', type: :a, value: '192.0.2.1') }
    client.domains.search('example.com') rescue nil # a POST that is a read
    assert_equal 2, api.requests.size
  end

  def test_rate_limit_is_retried_even_for_billable_requests
    client, api = fake_client(status(429, '', 'Retry-After' => '0'),
                              ok('{"success":true,"domainId":"d1","status":"Active"}'))
    res = client.domains.renew('example.com', years: 1)
    assert_equal 'd1', res.domain_id
    assert_equal 2, api.requests.size
    assert_in_delta 0.05, client.sleeps.first, 0.001
  end

  def test_rate_limit_after_retries
    client, api = fake_client(status(429, '', 'Retry-After' => '0'), retries: 1)
    e = assert_raises(APIError) { client.account.get }
    assert e.rate_limited?
    assert_equal 2, api.requests.size
  end

  def test_long_retry_after_is_not_waited_for
    client, api = fake_client(status(429, '', 'Retry-After' => '120'))
    assert_raises(APIError) { client.account.get }
    assert_equal 1, api.requests.size
    assert_empty client.sleeps
  end

  def test_server_errors_are_retried_only_when_safe
    client, api = fake_client(status(503), ok('{"resellerId":"r"}'))
    assert_equal 'r', client.account.get.reseller_id
    assert_equal 2, api.requests.size

    client, api = fake_client(status(503), ok)
    client.domains.lock('example.com') # an idempotent write
    assert_equal 2, api.requests.size

    client, api = fake_client(status(503), ok('{"success":true}'))
    e = assert_raises(APIError) { client.domains.renew('example.com', years: 1) }
    assert_equal :server, e.kind
    assert_equal 1, api.requests.size

    client, api = fake_client(status(500), ok)
    assert_raises(APIError) { client.account.get } # 500 is not retried
    assert_equal 1, api.requests.size
  end

  def test_network_errors
    client, api = fake_client(Errno::ECONNRESET.new, ok('{"resellerId":"r"}'))
    assert_equal 'r', client.account.get.reseller_id
    assert_equal 2, api.requests.size
    assert_operator client.sleeps.first, :>=, 0.5

    client, api = fake_client(Net::ReadTimeout.new)
    e = assert_raises(NetworkError) { client.domains.renew('example.com', years: 1) }
    assert_equal 1, api.requests.size, 'a billable request is never resent after a network error'
    assert e.timeout?
    assert e.outcome_unknown?
    assert_equal :network, e.kind
    assert_equal '/api/v1/domains/renew', e.path

    client, api = fake_client(SocketError.new('getaddrinfo'), retries: 2)
    e = assert_raises(NetworkError) { client.account.get }
    assert_equal 3, api.requests.size
    refute e.outcome_unknown?

    client, api = fake_client(OpenSSL::SSL::SSLError.new('certificate verify failed'))
    assert_raises(NetworkError) { client.account.get }
    assert_equal 1, api.requests.size, 'TLS errors are not retried'
  end

  def test_redirect_is_an_auth_error
    client, = fake_client(status(302, '', 'Location' => '/Error/Suspend'))
    e = assert_raises(APIError) { client.account.get }
    assert e.auth?
    assert_equal ErrorCode::INVALID_RESELLER, e.code
    refute_nil e.hint
  end

  def test_correlation_id
    client, api = fake_client(ok('{}'))
    client.account.get
    first = api.last.headers['X-Correlation-ID']
    client.account.get
    refute_equal first, api.last.headers['X-Correlation-ID']

    DomainNameApi.with_correlation_id('job-42') { client.account.get }
    assert_equal 'job-42', api.last.headers['X-Correlation-ID']
    client.with_correlation_id('job-43') { client.account.get }
    assert_equal 'job-43', api.last.headers['X-Correlation-ID']
    client.call(AccountGetRequest.new, correlation_id: 'job-44')
    assert_equal 'job-44', api.last.headers['X-Correlation-ID']
    client.account.get
    refute_includes %w[job-42 job-43 job-44], api.last.headers['X-Correlation-ID']

    client, = fake_client(api_error(500, 'X', 'boom'))
    e = DomainNameApi.with_correlation_id('job-45') { assert_raises(APIError) { client.account.get } }
    assert_equal 'job-45', e.correlation_id

    client, = fake_client({ status: 404, body: '{}', headers: { 'X-Correlation-Id' => 'server-1' } })
    assert_equal 'server-1', assert_raises(APIError) { client.account.get }.correlation_id
  end

  def test_trace_and_logger
    events = []
    out = StringIO.new
    logger = Logger.new(out)
    logger.level = Logger::DEBUG
    client, = fake_client(status(503), ok('{"resellerId":"r"}'), on_trace: ->(e) { events << e }, logger: logger)
    client.account.get
    assert_equal %i[request response retry request response], events.map(&:kind)
    assert_equal [1, 1, 1, 2, 2], events.map(&:attempt)
    assert_equal 503, events[1].status
    assert events[2].retry?
    assert_equal '{"resellerId":"r"}', events[4].body
    assert(events.all? { |e| e.safety == :read && e.url.end_with?('/api/v1/deposit/accounts/me') })
    log = out.string
    assert_includes log, 'retrying'
    assert_includes log, 'status=503'
    refute_includes log, API_KEY
    refute(events.any? { |e| e.to_h.values.any? { |v| v.to_s.include?(API_KEY) } })
  end

  class ExpiryRequest < DomainNameApi::BaseRequest
    endpoint :get, '/api/v1/domains/info', safety: :read
    attribute :domain_name

    def query
      { 'DomainName' => domain_name }
    end

    def validate
      required :domain_name
    end
  end

  class Expiry < DomainNameApi::Model
    field :expiration_date, :time
  end

  class TypedExpiryRequest < ExpiryRequest
    returns Expiry
  end

  def test_own_requests
    client, api = fake_client(ok('{"expirationDate":"2027-03-15T10:20:30","authCode":"X"}'))
    data = client.call(ExpiryRequest.new(domain_name: 'example.com'))
    assert_equal '2027-03-15T10:20:30', data['expirationDate']
    assert_equal [%w[DomainName example.com]], api.query

    expiry = client.call(TypedExpiryRequest.new(domain_name: 'example.com'))
    assert_equal Time.utc(2027, 3, 15, 10, 20, 30), expiry.expiration_date
    assert_equal 'X', expiry.raw['authCode']

    response = client.execute(TypedExpiryRequest.new(domain_name: 'example.com'))
    assert_equal 200, response.status
    assert_equal 1, response.attempts
    assert_kind_of Expiry, response.value
    assert response.success?

    assert_raises(InputError) { client.call(ExpiryRequest.new) }
  end

  def test_prepare_does_not_send
    client, api = fake_client
    prepared = client.prepare(DomainRenewRequest.new(domain_name: 'example.com', years: 2))
    assert_empty api.requests
    assert_equal 'POST', prepared.http_method
    assert_equal({ 'domainName' => 'example.com', 'period' => 2 }, prepared.json)
    refute_includes prepared.inspect, API_KEY
    assert_raises(InputError) { client.prepare(DomainRenewRequest.new(domain_name: 'example.com')) }
  end

  def test_quota_headers
    client, api = fake_client({ status: 200, body: '{}',
                                headers: { 'X-Quota-Scope' => 'domain', 'X-Quota-Cost' => '10', 'X-Quota-Used' => '210',
                                           'X-Quota-Limit' => '200', 'X-Quota-Delay' => '0.5',
                                           'X-Quota-Reset' => '30' } })
    response = client.execute(AccountGetRequest.new)
    assert_equal 'domain', response.quota.scope
    assert_equal 210.0, response.quota.used
    assert_equal 0.5, response.quota.delay
    assert_equal '0.5', response.header('X-QUOTA-DELAY')
    assert_equal 1, api.requests.size

    client, = fake_client(ok('{}'))
    assert_nil client.execute(AccountGetRequest.new).quota
  end

  def test_decode_error
    client, = fake_client(ok('not json'))
    e = assert_raises(DecodeError) { client.account.get }
    assert_includes e.message, 'not valid JSON'
    assert_equal 'not json', e.response.body

    client, = fake_client(ok('OK'))
    assert_nil client.domains.lock('example.com') # no decoding without a declared result
  end

  def test_empty_body_decodes_to_an_empty_model
    client, = fake_client(ok(''))
    account = client.account.get
    assert_kind_of Account, account
    assert_nil account.reseller_id
  end

  def test_pacing
    pacer = Pacer.new
    assert_equal 0.0, pacer.reserve('/api/v1/domains/renew', 100.0)
    assert_in_delta 0.2, pacer.reserve('/api/v1/domains/renew', 100.0), 1e-9
    assert_in_delta 0.4, pacer.reserve('/api/v1/contacts', 100.0), 1e-9
    assert_equal 0.0, pacer.reserve('/api/v1/domains/info', 100.0), 'domain info is not rate limited'
    assert_equal 0.0, pacer.reserve('/api/v1/products/tlds', 100.0)
    assert_equal 0.0, pacer.reserve('/api/v1/domains/zones', 100.0)
    assert_in_delta 1.0, pacer.reserve('/api/v1/domains/zones/apply', 100.0), 1e-9
    assert_equal 0.0, pacer.reserve('/api/v1/domains/search', 100.0)
    assert_in_delta 0.5, pacer.reserve('/api/v1/domains/bulk-search', 100.0), 1e-9
    assert_in_delta 0.7, pacer.reserve('/api/v1/domains/renew', 100.0), 1e-9, 'searches count against the overall budget'
    assert_equal 0.0, pacer.reserve('/api/v1/domains/renew', 200.0)

    client, = fake_client(ok('{}'), ok('{}'), pacing: true)
    client.account.get
    client.account.get
    assert_equal 2, client.sleeps.size
    assert_operator client.sleeps.last, :>, 0.1
  end

  def test_retry_after_formats
    client, = fake_client
    assert_in_delta 1.55, client.send(:retry_after, { 'retry-after' => '1.5' }, 1), 0.001
    future = (Time.now + 3).httpdate
    assert_in_delta 3, client.send(:retry_after, { 'retry-after' => future }, 1), 1.1
    assert_operator client.send(:retry_after, {}, 2), :>=, 1.0
    assert_operator client.send(:retry_after, { 'retry-after' => 'soon' }, 1), :>=, 0.5
  end

  def test_transport_shapes
    client, = fake_client
    assert_equal [204, { 'x-a' => '1, 2' }, ''], client.send(:unpack, [204, { 'X-A' => %w[1 2] }, nil])
    assert_equal [200, {}, 'x'], client.send(:unpack, { status: '200', body: 'x' })
    assert_equal [201, {}, 'y'], client.send(:unpack, { 'status' => 201, 'body' => 'y' })
  end
end
