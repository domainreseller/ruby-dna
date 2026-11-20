# frozen_string_literal: true

require_relative 'test_helper'

class ErrorsTest < Minitest::Test
  include DomainNameApi

  def from(status, body = '', headers = {})
    APIError.from_response(http_method: 'GET', path: '/api/v1/x', status: status, headers: headers, body: body)
  end

  CASES = [
    ['abp envelope', 404,
     '{"error":{"code":"Dna.DomainService:Domain:10007","message":"The domain name you requested could not be found.",' \
     '"details":"The domain could not be found.","data":[],"validationErrors":null}}',
     ErrorCode::DOMAIN_NOT_FOUND, 'The domain name you requested could not be found.', :not_found],
    ['flat object', 409, '{"code":"X:1","message":"busy"}', 'X:1', 'busy', :conflict],
    ['validation without code', 400,
     '{"error":{"code":null,"message":"Validation failed.","details":"...","validationErrors":' \
     '[{"message":"The DomainName field is required.","members":["$.domainName"]}]}}',
     'HTTP_400', 'Validation failed.', :validation],
    ['plain-text missing key', 401, 'Unauthorized! API Key is missing.', ErrorCode::MISSING_API_KEY,
     'Unauthorized! API Key is missing.', :auth],
    ['plain-text missing reseller', 401, 'Unauthorized! ResellerId is missing.', ErrorCode::MISSING_RESELLER_ID, nil,
     :auth],
    ['plain-text invalid key', 401, 'Unauthorized! Invalid API Key.', ErrorCode::INVALID_API_KEY, nil, :auth],
    ['sub-reseller', 401, 'Unauthorized! You do not have authorisation for this operation.',
     ErrorCode::SUBRESELLER_NOT_ALLOWED, nil, :auth],
    ['empty 401', 401, '', ErrorCode::UNAUTHORIZED, 'unauthorized', :auth],
    ['redirect', 302, '', ErrorCode::INVALID_RESELLER, nil, :auth],
    ['empty 500', 500, '', 'HTTP_500', 'internal server error', :server],
    ['html 502', 502, '<html><body>Bad gateway</body></html>', 'HTTP_502', 'bad gateway', :server],
    ['boilerplate replaced by details', 400,
     '{"error":{"code":"Dna.DomainService:Dns:10024","message":"Exception of type \'Volo.Abp.BusinessException\' ' \
     'was thrown.","details":"Dna Record already exists."}}',
     'Dna.DomainService:Dns:10024', 'Record already exists.', :validation],
    ['code echo without details', 400,
     '{"error":{"code":"Dna.DomainService:Dns:10030","message":"Dna.DomainService:Dns:10030","details":null}}',
     'Dna.DomainService:Dns:10030', 'the operation could not be completed', :validation],
    ['business rule', 403, '{"error":{"code":"","message":"Hosting already exists"}}', 'HTTP_403',
     'Hosting already exists', :rejected],
    ['payment required', 402,
     '{"error":{"code":"Dna.DomainService:Deposit:10001","message":"Insufficient balance",' \
     '"data":{"usdBalance":1.5,"requiredAmount":11.99}}}',
     'Dna.DomainService:Deposit:10001', 'Insufficient balance', :rejected],
    ['teapot', 418, '', 'HTTP_418', "i'm a teapot", :unknown],
    ['not json', 400, '{broken', 'HTTP_400', '{broken', :validation]
  ].freeze

  def test_normalisation
    CASES.each do |name, status, body, code, message, kind|
      e = from(status, body)
      assert_equal code, e.code, "#{name}: code"
      assert_equal message, e.api_message, "#{name}: message" if message
      refute_empty e.api_message.to_s, "#{name}: message is empty"
      assert_equal kind, e.kind, "#{name}: kind"
      assert_kind_of Error, e
    end
  end

  def test_rate_limit
    e = from(429, '', 'retry-after' => '2')
    assert_equal ErrorCode::RATE_LIMITED, e.code
    assert_equal 'rate limit exceeded (retry after 2s)', e.api_message
    assert_equal 2.0, e.retry_after
    assert e.rate_limited?
    assert e.retryable?
    refute_nil e.hint
  end

  def test_details_fields_and_message
    e = APIError.from_response(
      http_method: 'POST', path: '/api/v1/domains/search', status: 400, headers: { 'x-correlation-id' => 'c-1' },
      body: '{"error":{"message":"Validation failed.","validationErrors":[{"message":"The DomainName field is ' \
            'required.","members":["$.domainName"]},{"message":"Bad.","members":["Registrant.Country","Admin.Country"]}]}}'
    )
    assert_equal ['domainName', 'Registrant.Country,Admin.Country'], e.fields.map(&:field)
    assert_equal 'c-1', e.correlation_id
    assert_equal 'POST /api/v1/domains/search: 400 HTTP_400: Validation failed.; domainName: The DomainName field ' \
                 'is required.; Registrant.Country,Admin.Country: Bad.', e.message

    e = from(402, '{"error":{"code":"Dna.DomainService:Deposit:10001","message":"x","data":{"usdBalance":1.5}}}')
    assert_equal 1.5, e.data['usdBalance']
    assert e.insufficient_balance?
    e = from(400, '{"error":{"code":"Dna.DepositService:Deposit:10002","message":"Insufficient balance."}}')
    assert e.insufficient_balance?
    assert e.code?('Dna.DepositService:Deposit:10002')
    refute e.code?('other')
  end

  def test_outcome_unknown
    ErrorCode::OUTCOME_UNKNOWN.each do |code|
      e = APIError.new(status: 500, code: code, api_message: 'x')
      assert e.outcome_unknown?, code
      refute e.retryable?, code
      assert_includes e.hint, 'already', code
    end
    refute APIError.new(status: 404, code: ErrorCode::DOMAIN_NOT_FOUND, api_message: 'x').outcome_unknown?

    timeout = Timeout::Error.new('execution expired')
    billable = NetworkError.new(http_method: 'POST', path: '/x', original: timeout, safety: :billable)
    assert billable.outcome_unknown?
    assert billable.timeout?
    refute billable.retryable?
    read = NetworkError.new(http_method: 'GET', path: '/x', original: timeout, safety: :read)
    refute read.outcome_unknown?
    assert read.retryable?
    refute NetworkError.new(http_method: 'GET', path: '/x', original: SocketError.new('dns')).timeout?
  end

  def test_kinds_and_predicates
    assert_equal :invalid_input, InputError.new('DomainRenewRequest', [FieldError.new('years', 'bad')]).kind
    assert_equal 'invalid DomainRenewRequest: years: bad', InputError.new('DomainRenewRequest',
                                                                         [FieldError.new('years', 'bad')]).message
    assert_equal :read_only, ReadOnlyError.new('DomainRenewRequest', 'POST', '/x', :billable).kind
    assert_equal :rejected, OperationError.new(http_method: 'POST', path: '/x', api_message: 'taken').kind
    assert_equal :network, NetworkError.new(http_method: 'GET', path: '/x', original: IOError.new).kind
    assert_equal :auth, MissingCredentialsError.new.kind
    assert from(404).not_found?
    assert from(401).auth?
    refute from(500).not_found?
    assert_equal :unknown, Error.new('x').kind
    assert_equal ErrorKind::ALL.size, ErrorKind::ALL.uniq.size
  end

  def test_operation_error_message
    e = OperationError.new(http_method: 'POST', path: '/api/v1/domains/register', code: ' X ', api_message: ' taken ')
    assert_equal 'POST /api/v1/domains/register: X: taken', e.message
    assert_equal 'taken', e.api_message
    assert e.code?('X')
    assert_equal 'POST /x: the API reported that the operation failed',
                 OperationError.new(http_method: 'POST', path: '/x').message
  end

  def test_hints
    assert_includes from(302).hint, 'reseller ID'
    assert_includes from(401, 'Unauthorized! Invalid API Key.').hint, 'different API keys'
    assert_includes from(404).hint, 'production and OTE'
    assert_nil from(500).hint
    assert_includes from(500, '', 'x-correlation-id' => 'c-9').hint, 'c-9'
    assert_nil from(409).hint
  end
end
