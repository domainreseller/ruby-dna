# frozen_string_literal: true

require_relative 'test_helper'

# HTTP layer and error mapping (DNARest::request()).
class HttpTest < Minitest::Test
  include DnaTestSupport

  def setup
    @transport = FakeTransport.new
    @client = new_client(@transport)
  end

  def test_constructor_trims_credentials_and_picks_live_url
    client = DomainNameApi::Client.new("  #{RESELLER} \n", "\t#{API_KEY} ", false, transport: @transport)
    client.set_error_reporting_enabled(false)
    @transport.push(200, '{"resellerId":"x"}')
    client.get_reseller_details
    headers = @transport.requests.last[:headers]
    assert_equal API_KEY, headers['X-API-KEY']
    assert_equal RESELLER, headers['__reseller']
    assert_equal DomainNameApi::Rest::URL_PROD, client.get_service_url
  end

  def test_test_mode_accepts_strings_like_filter_validate_boolean
    %w[true 1 on yes TRUE Yes].each do |value|
      assert_equal DomainNameApi::Rest::URL_OTE, DomainNameApi::Client.new('a', 'b', value).get_service_url, value
    end
    ['false', '0', 'off', 'no', '', 'nonsense'].each do |value|
      assert_equal DomainNameApi::Rest::URL_PROD, DomainNameApi::Client.new('a', 'b', value).get_service_url, value
    end
    assert_equal DomainNameApi::Rest::URL_OTE, DomainNameApi::Client.new('a', 'b', true).get_service_url
    assert_equal DomainNameApi::Rest::URL_PROD, DomainNameApi::Client.new('a', 'b', 0).get_service_url
  end

  def test_headers_and_user_agent
    @transport.push(200, '{}')
    @client.get_details('example.com')
    req = @transport.requests.last
    assert_equal 'application/json', req[:headers]['Content-Type']
    assert_equal 'application/json', req[:headers]['Accept']
    assert_equal 'DomainNameAPI-Ruby/1.0.0', req[:headers]['User-Agent']
    assert_equal 30, req[:timeout]
    assert_equal 10, req[:connect_timeout]
    assert_equal true, req[:verify_ssl]
    assert_nil req[:body]
  end

  def test_ssl_verification_can_be_switched_off
    @client.set_ssl_verification(false)
    @transport.push(200, '{}')
    @client.get_details('example.com')
    assert_equal false, @transport.requests.last[:verify_ssl]
  end

  def test_get_uses_php_query_string_and_post_uses_json
    @transport.push(200, '{"totalCount":0,"items":[]}')
    @client.get_list('DomainName' => 'a b', 'Flag' => true, 'Off' => false, 'Skip' => nil)
    url = @transport.requests.last[:url]
    assert_includes url, 'DomainName=a+b'
    assert_includes url, 'Flag=1'
    assert_includes url, 'Off=0'
    refute_includes url, '&Skip='

    @transport.push(200, '{}')
    @client.enable_theft_protection_lock('example.com')
    req = @transport.requests.last
    assert_equal 'POST', req[:method]
    assert_equal({ 'domainName' => 'example.com' }, JSON.parse(req[:body]))
  end

  def test_symbol_keys_are_accepted_for_hash_inputs
    @transport.push(200, '{"totalCount":0,"items":[]}')
    @client.get_list(PageSize: 10, PageNumber: 3)
    url = @transport.requests.last[:url]
    assert_includes url, 'MaxResultCount=10'
    assert_includes url, 'SkipCount=30'
  end

  def test_set_service_url
    @client.set_service_url('http://127.0.0.1:9/api/v1')
    @transport.push(200, '{}')
    @client.get_details('example.com')
    assert @transport.requests.last[:url].start_with?('http://127.0.0.1:9/api/v1/domains/info?')
  end

  def test_redirect_is_a_credentials_error
    @transport.push(301, '')
    result = @client.get_details('example.com')
    assert_equal 'ERROR', result['result']
    assert_equal 'API_301', result['error']['Code']
    assert_equal 'Invalid API credentials', result['error']['Message']
  end

  def test_message_falls_back_to_error_message_then_body
    @transport.push(400, '{"error":{"message":"Bad domain","details":"why"}}')
    result = @client.get_details('example.com')
    assert_equal({ 'Code' => 'API_400', 'Message' => 'Bad domain', 'Details' => 'why' }, result['error'])

    @transport.push(418, 'teapot')
    result = @client.get_details('example.com')
    assert_equal({ 'Code' => 'API_418', 'Message' => 'teapot', 'Details' => 'teapot' }, result['error'])
  end

  def test_empty_body_synthesises_message_from_status
    { 429 => 'Too Many Requests', 503 => 'Service Unavailable', 599 => 'Server Error', 499 => 'Client Error' }.each do |status, reason|
      @transport.push(status, '')
      result = @client.get_details('example.com')
      assert_equal "HTTP #{status} - #{reason}", result['error']['Message']
      assert_equal "HTTP #{status} - #{reason}", result['error']['Details']
    end
  end

  def test_abp_boilerplate_is_replaced_by_details
    @transport.push(403, '{"error":{"code":"Dna:1","message":"Exception of type \'Volo.Abp.BusinessException\' was thrown.","details":"Dna Host is linked"}}')
    assert_equal 'Host is linked', @client.get_details('example.com')['error']['Message']
  end

  def test_abp_boilerplate_without_details_is_synthesised
    @transport.push(403, '{"error":{"code":"Dna.DomainService:Dns:10024","message":"Dna.DomainService:Dns:10024","details":"Dna.DomainService:Dns:10024"}}')
    message = @client.get_details('example.com')['error']['Message']
    assert_equal 'The operation could not be completed by the registry (error: Dna.DomainService:Dns:10024). ' \
                 'Please try again or contact support.', message
  end

  def test_validation_errors_are_flattened
    body = {
      'error' => {
        'message' => 'Validation failed.',
        'validationErrors' => [
          { 'members' => ['$.administrativeContact.postalCode', '$.contacts[2].technicalContact.postalCode'],
            'message' => "'PostalCode' is required" },
          { 'members' => ['$.tldAttributes.TRABISCOUNTRYID'] },
          { 'message' => 'Plain message' },
          '  raw string  ',
          { 'members' => ['$.administrativeContact.postalCode', '$.contacts[2].technicalContact.postalCode'],
            'message' => "'PostalCode' is required" }
        ]
      }
    }
    @transport.push(400, JSON.generate(body))
    details = @client.get_details('example.com')['error']['Details']
    assert_equal "Admin PostalCode, Contacts Tech PostalCode - 'PostalCode' is required | " \
                 'TldAttributes TRABISCOUNTRYID | Plain message | raw string', details
  end

  def test_timeout_is_an_error_not_an_empty_success
    @transport.push(nil, nil)
    @transport.instance_variable_get(:@queue)[-1] = DomainNameApi::TransportError.new('Operation timed out', 28)
    result = @client.modify_name_server('example.com', ['ns1.example.com'])
    assert_equal 'ERROR', result['result']
    assert_equal 'CURL_28', result['error']['Code']
    refute result['error'].key?('GatewayCode')
    expected = 'Could not reach the DomainNameAPI service: the connection timed out. (Operation timed out)'
    assert_equal expected, result['error']['Message']
    assert_equal expected, result['error']['Details']
    assert_equal 'CURL_28', @client.get_parsed_response_data['Code']
  end

  def test_other_transport_errors
    @transport.instance_variable_get(:@queue) << DomainNameApi::TransportError.new('getaddrinfo failed', 6)
    result = @client.get_reseller_details
    assert_equal 'CURL_6', result['error']['Code']
    assert_equal 'Curl error during request: getaddrinfo failed', result['error']['Message']
    assert_equal 'CURL_6', @client.get_parsed_response_data['Code']
  end

  def test_unexpected_transport_exception_is_still_an_error_envelope
    @transport.instance_variable_get(:@queue) << RuntimeError.new('boom')
    result = @client.get_details('example.com')
    assert_equal 'ERROR', result['result']
    assert_equal 'Curl error during request: boom', result['error']['Message']
  end

  def test_diagnostics_are_recorded
    @transport.push(200, '{"resellerId":"r1","usdBalance":1}')
    @client.get_reseller_details
    assert_equal 'request:GET deposit/accounts/me', @client.get_last_function
    assert_equal 'GET', @client.get_request_data['method']
    assert_equal 'r1', @client.get_response_data['resellerId']
    assert_equal 'r1', @client.get_parsed_response_data['resellerId']
    assert_equal 200, @client.get_response_headers['http_code']

    @transport.push(500, '<html>oops</html>')
    @client.get_reseller_details
    assert_equal({ 'raw_response' => '<html>oops</html>' }, @client.get_response_data)
  end

  def test_last_function_strips_query_string
    @transport.push(200, '')
    @client.apply_resource_records('example.com')
    assert_equal 'request:POST domains/zones/apply', @client.get_last_function
    assert_equal '[]', @transport.requests.last[:body]
  end

  def test_zone_requests_are_paced
    client = DomainNameApi::Client.new(RESELLER, API_KEY, false, transport: @transport, zone_min_interval: 0.15)
    client.set_error_reporting_enabled(false)
    3.times { @transport.push(200, '[]') }
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    3.times { client.get_resource_records('example.com') }
    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
    assert_operator elapsed, :>=, 0.29

    # Non-zone calls are not paced.
    5.times { @transport.push(200, '{}') }
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    5.times { client.get_details('example.com') }
    assert_operator Process.clock_gettime(Process::CLOCK_MONOTONIC) - started, :<, 0.1
  end

  def test_transport_may_return_a_plain_hash
    client = new_client(->(_req) { { status: 200, body: '{"resellerId":"abc"}' } })
    assert_equal 'abc', client.get_reseller_details['id']
  end

  def test_transfer_never_sends_contacts
    assert_equal 3, @client.method(:transfer).arity
    assert_equal 3, @client.rest.method(:transfer).arity
    @transport.push(200, '{"domainName":"example.com"}')
    @client.transfer('example.com', 'EPP', 1)
    body = JSON.parse(@transport.requests.last[:body])
    assert_equal({ 'domainName' => 'example.com', 'authCode' => 'EPP', 'period' => 1, 'contacts' => [] }, body)
    assert_raises(ArgumentError) { @client.transfer('example.com', 'EPP', 1, 'Registrant' => {}) }
  end

  def test_gateway_success_false_is_an_error
    { register: 'REGISTER_DOMAIN', transfer: 'TRANSFER_DOMAIN', renew: 'RENEW_DOMAIN' }.each do |call, code|
      @transport.push(200, '{"success":false,"message":"Registry refused the order"}')
      result = case call
               when :register then @client.register_with_contact_info('example.com', 1, {})
               when :transfer then @client.transfer('example.com', 'EPP', 1)
               else @client.renew('example.com', 1)
               end
      assert_equal({ 'result' => 'ERROR',
                     'error' => { 'Code' => code, 'Message' => 'Registry refused the order',
                                  'Details' => 'Registry refused the order' } }, result)
    end
    @transport.push(200, '{"success":false}')
    assert_equal 'The registry did not accept the request.', @client.renew('example.com', 1)['error']['Message']
  end

  def test_gateway_code_is_kept_next_to_the_http_code
    @transport.push(404, '{"error":{"code":"Dna.DomainService:Domain:10007","message":"Domain not found"}}')
    error = @client.get_details('example.com')['error']
    assert_equal 'API_404', error['Code']
    assert_equal 'Dna.DomainService:Domain:10007', error['GatewayCode']

    @transport.push(500, '')
    refute @client.get_details('example.com')['error'].key?('GatewayCode')
  end

  def test_message_never_falls_back_to_the_raw_body
    @transport.push(400, '{"error":{"code":"Dna:42","message":"Dna:42"}}')
    message = @client.get_details('example.com')['error']['Message']
    assert_equal 'The operation could not be completed by the registry (error: Dna:42). Please try again or contact support.',
                 message
  end

  def test_privacy_status_parsing_and_no_reason_sent
    [[true, true], [false, false], [1, true], ['1', true], [' on ', true], ['true', true], ['yes', true],
     [0, false], ['0', false], ['off', false], [nil, false], ['nonsense', false]].each do |input, expected|
      @transport.push(200, '{}')
      result = @client.modify_privacy_protection_status('example.com', input, 'Because')
      body = JSON.parse(@transport.requests.last[:body])
      assert_equal({ 'domainName' => 'example.com', 'privacyStatus' => expected }, body, input.inspect)
      assert_equal expected, result['data']['PrivacyProtectionStatus']
    end
  end

  def test_balance_for_an_unreported_currency_fails
    @transport.push(200, '{"resellerId":"r","usdBalance":10,"tryBalance":20}')
    result = @client.get_current_balance('EUR')
    assert_equal 'BALANCE', result['ErrorCode']
    assert_equal 'FAILED', result['OperationResult']
    assert_equal 'No EUR balance is reported for this account. Available: USD, TRY.', result['OperationMessage']
  end

  def test_forwarding_not_set_versus_missing_domain
    @transport.push(404, '{"error":{"message":"Redirect information not found"}}')
    assert_equal({ 'result' => 'OK', 'data' => { 'Enabled' => false, 'RedirectAddress' => '', 'ForwardType' => '' } },
                 @client.get_forwarding('example.com'))
    @transport.push(404, '{"error":{"message":"Redirect information not found"}}')
    assert_equal({ 'result' => 'OK', 'data' => { 'DomainName' => 'example.com', 'Removed' => false } },
                 @client.delete_forwarding('example.com'))
    @transport.push(200, '')
    assert_equal true, @client.delete_forwarding('example.com')['data']['Removed']
    @transport.push(404, '{"error":{"message":"Domain not found"}}')
    assert_equal 'ERROR', @client.get_forwarding('missing.com')['result']
  end

  def test_zone_write_returns_the_apply_error
    @transport.push(200, '')
    @transport.push(429, '')
    result = @client.add_resource_record('example.com', 'www', 'a', '192.0.2.1', 999_999)
    assert_equal 'API_429', result['error']['Code']

    @transport.push(200, '')
    @transport.push(200, '')
    result = @client.add_resource_record('example.com', 'www', 'a', '192.0.2.1', 999_999)
    assert_equal({ 'Name' => 'www', 'Type' => 'A', 'TTL' => 86_400, 'Content' => '192.0.2.1' }, result['data'])
  end

  def test_get_contacts_types_are_case_insensitive_and_unknown_types_kept
    contacts = [{ 'contactType' => 'OWNER', 'handle' => 'R' }, { 'contactType' => 'admin', 'handle' => 'A' },
                { 'contactType' => 'Reseller', 'handle' => 'X' }, { 'contactType' => 'TECHNICAL', 'handle' => 'T' }]
    @transport.push(200, JSON.generate('contacts' => contacts))
    result = @client.get_contacts('example.com')['data']['contacts']
    assert_equal %w[Administrative Registrant Technical Reseller], result.keys
    assert_equal 'R', result['Registrant']['ID']
    assert_equal 'X', result['Reseller']['ID']
  end

  def test_availability_strips_only_the_trailing_tld
    @transport.push(200, '[{"domainName":"my.company.com","status":"available"}]')
    assert_equal 'my.company', @client.check_availability(['my.company'], ['com'], 1).first['DomainName']
  end

  def test_set_resource_record_set_requires_a_list
    assert_raises(TypeError) { @client.set_resource_record_set('example.com', 'www', 'A', '192.0.2.1') }
  end
end
