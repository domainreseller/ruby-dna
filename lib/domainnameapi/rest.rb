# frozen_string_literal: true

require 'time'

module DomainNameApi
  # Raised inside the client when the gateway answers with an error status or
  # the request fails in transport. Never escapes a public method: every
  # method catches it and returns the error envelope. `code` is the HTTP
  # status (or the curl-style transport error number).
  class ApiError < StandardError
    attr_reader :code

    def initialize(message, code = 0)
      super(message)
      @code = code
    end
  end

  # Port of php-dna's DNARest: one method per gateway operation, each
  # returning php-dna's result structure (Hashes with String keys).
  #
  # Use DomainNameApi::Client, the public facade; Rest is its engine.
  class Rest
    include Telemetry

    URL_PROD = 'https://api.domainresellerapi.com/api/v1'
    URL_OTE = 'https://ote.domainresellerapi.com/api/v1'
    USER_AGENT = "DomainNameAPI-Ruby/#{VERSION}"

    RESULT_OK = 'OK'
    RESULT_ERROR = 'ERROR'
    RESULT_SUCCESS = 'SUCCESS'

    DEFAULT_TIMEOUT = 30
    DEFAULT_CONNECT_TIMEOUT = 10
    DEFAULT_REASON = 'Owner request'
    DEFAULT_NAMESERVERS = ['ns1.domainnameapi.com', 'ns2.domainnameapi.com'].freeze

    # Minimum gap between two /domains/zones calls, in seconds.
    ZONE_MIN_INTERVAL = 1.0

    DEFAULT_ERRORS = {
      'DOMAIN_DETAILS' => ['Invalid domain details! Details format is not valid',
                           'The provided domain details are not in the expected format'],
      'CREDENTIALS' => ['Invalid reseller ID or API key', 'The provided API credentials are invalid'],
      'DOMAIN_LIST' => ['The domain list is invalid or contains multiple entries!',
                        'The domain list response format is incorrect or unexpected'],
      'TLD_LIST' => ['TLD info is not a valid array or more than one TLD info has returned!',
                     'The TLD list response is not in the expected format'],
      'RESPONSE' => ['Invalid response received from server! Response is empty.', 'The API response is empty or null'],
      'RESPONSE_FORMAT' => ['Invalid response received from server! Response format is not valid.',
                            'The API response format is not in the expected structure'],
      'RESPONSE_COUNT' => ['Invalid parameters passed to function! Response data contains more than one result!',
                           'The API response contains multiple results when only one was expected'],
      'RESPONSE_CODE' => ['Invalid parameters passed to function! Operation result or Error code not received from server',
                          'The API response is missing required operation result or error code fields'],
      'RESPONSE_REST' => ['Invalid parameters passed to function! REST return is not a valid array!',
                          'The REST response is not in a valid array format'],
      'CONTACT_INFO' => ['Invalid response received from server! Contact info is not a valid array or more than one contact info has returned!',
                         'The contact information response is not in the expected format'],
      'CONTACT_SAVE' => ['Invalid response received from server! Contact info could not be saved!',
                         'The contact information could not be saved on the server'],
      'DOMAIN_TRANSFER_REQUEST' => ['Invalid response received from server! Domain transfer request could not be completed!',
                                    'The domain transfer request failed to complete'],
      'DOMAIN_RENEW' => ['Invalid response received from server! Domain renew request could not be completed!',
                         'The domain renewal request failed to complete'],
      'DOMAIN_REGISTER' => ['Invalid response received from server! Domain register request could not be completed!',
                            'The domain registration request failed to complete'],
      'DOMAIN_SYNC' => ['Invalid response received from server! Domain sync request could not be completed!',
                        'The domain synchronization request failed to complete']
    }.freeze

    # Gateway DomainStatus enum -> label.
    DOMAIN_STATUS_MAP = {
      0 => 'Active', 1 => 'WaitingForRegistration', 2 => 'WaitingForDocument',
      3 => 'WaitingForIncomingTransfer', 4 => 'TransferredOut', 7 => 'PendingDelete',
      8 => 'Deleted', 9 => 'ConfirmationEmailSend', 11 => 'WaitingForOutgoingTransfer',
      12 => 'PendingHold', 15 => 'ModificationPending', 18 => 'InCase', 19 => 'PendingRestore'
    }.freeze

    # Zone record types the gateway accepts (probed against the live gateway).
    ZONE_RECORD_TYPES = %w[A AAAA ALIAS CAA CNAME DS MX NAPTR PTR SRV TLSA TXT].freeze

    # Redirect types accepted by /domains/forwards.
    FORWARD_TYPES = %w[Standard Frame].freeze

    HTTP_REASONS = {
      400 => 'Bad Request', 401 => 'Unauthorized', 402 => 'Payment Required', 403 => 'Forbidden',
      404 => 'Not Found', 405 => 'Method Not Allowed', 408 => 'Request Timeout', 409 => 'Conflict',
      422 => 'Unprocessable Entity', 429 => 'Too Many Requests', 500 => 'Internal Server Error',
      502 => 'Bad Gateway', 503 => 'Service Unavailable', 504 => 'Gateway Timeout'
    }.freeze

    BOILERPLATE_RE = /Exception of type '[^']*' was thrown/i.freeze

    attr_accessor :zone_min_interval

    # @param reseller_id [String] Reseller ID (UUID)
    # @param api_key [String] API key
    # @param test_mode [Boolean] use the OTE (test) gateway
    # @param transport [#call, nil] HTTP transport (see NetHttpTransport)
    # @param sentry_dsn [String, nil] Sentry DSN override ('' disables)
    # @param zone_min_interval [Float, nil] pacing between /domains/zones calls
    def initialize(reseller_id, api_key, test_mode = false, transport: nil, sentry_dsn: nil, zone_min_interval: nil)
      @service_url = test_mode ? URL_OTE : URL_PROD
      @reseller_id = reseller_id
      @token = api_key
      @transport = transport || NetHttpTransport.new
      @ssl_verify = true
      @error_reporting_enabled = true
      @telemetry_minimal = false
      @sentry_dsn = sentry_dsn.nil? ? DEFAULT_SENTRY_DSN : sentry_dsn.to_s
      @telemetry_sender = nil
      @zone_min_interval = zone_min_interval.nil? ? ZONE_MIN_INTERVAL : zone_min_interval.to_f
      @last_zone_request_at = 0.0
      @last_request = {}
      @last_response = {}
      @last_response_headers = {}
      @last_parsed_response = {}
      @last_function = ''
      @start_at = monotonic
      @start_wall = Time.now
    end

    # --- settings and diagnostics -----------------------------------------

    def set_ssl_verification(enabled)
      @ssl_verify = enabled ? true : false
      nil
    end

    def set_transport(transport)
      @transport = transport
      nil
    end

    def get_request_data
      @last_request
    end

    def set_request_data(request)
      @last_request = request
      self
    end

    def get_response_data
      @last_response
    end

    def set_response_data(response)
      @last_response = response
      self
    end

    def get_response_headers
      @last_response_headers
    end

    def set_response_headers(headers)
      @last_response_headers = headers
      self
    end

    def get_parsed_response_data
      @last_parsed_response
    end

    def set_parsed_response_data(response)
      @last_parsed_response = response
      self
    end

    def get_last_function
      @last_function
    end

    def set_last_function(function)
      @last_function = function
      self
    end

    def get_service_url
      @service_url
    end

    def set_service_url(url)
      @service_url = url
      nil
    end

    # --- account -------------------------------------------------------------

    def get_reseller_details
      response = request('GET', 'deposit/accounts/me')
      resp = {}
      if Php.isset?(response, 'resellerId')
        resp['result'] = RESULT_OK
        resp['id'] = response['resellerId']
        resp['active'] = true
        resp['name'] = Php.get(response, 'resellerName') || ''
        usd = Php.number_format(Php.get(response, 'usdBalance') || 0, 2)
        resp['balance'] = usd
        resp['currency'] = 'USD'
        resp['symbol'] = '$'
        resp['balances'] = [
          { 'balance' => usd, 'currency' => 'USD', 'symbol' => '$' },
          { 'balance' => Php.number_format(Php.get(response, 'tryBalance') || 0, 2), 'currency' => 'TL', 'symbol' => 'TL' }
        ]
      else
        resp['result'] = RESULT_ERROR
        resp['error'] = set_error('CREDENTIALS', 'Invalid response format', 'Response does not contain required fields')
      end
      resp
    rescue ApiError => e
      error_envelope(e, 'RESELLER_DETAILS')
    end

    CURRENCY_MAP = {
      'USD' => { 'id' => 2, 'name' => 'USD', 'symbol' => '$' },
      'TRY' => { 'id' => 1, 'name' => 'TL', 'symbol' => 'TL' },
      'EUR' => { 'id' => 3, 'name' => 'EUR', 'symbol' => '€' },
      'GBP' => { 'id' => 4, 'name' => 'GBP', 'symbol' => '£' }
    }.freeze

    def get_current_balance(currency_id = 'USD')
      currency_name = Php.upper(currency_id)
      mapped = CURRENCY_MAP[currency_name] || { 'id' => 0, 'name' => currency_name, 'symbol' => '' }
      begin
        response = request('GET', 'deposit/accounts/me', { 'currency' => currency_name })
        balance_key = "#{Php.lower(currency_id)}Balance"
        unless response.is_a?(Hash) && response.key?(balance_key)
          # The account only reports USD and TRY balances.
          return {
            'ErrorCode' => 'BALANCE',
            'OperationMessage' => "No #{currency_name} balance is reported for this account. Available: USD, TRY.",
            'OperationResult' => 'FAILED',
            'Balance' => '0.00',
            'CurrencyId' => mapped['id'],
            'CurrencyInfo' => nil,
            'CurrencyName' => mapped['name'],
            'CurrencySymbol' => mapped['symbol']
          }
        end
        {
          'ErrorCode' => 0,
          'OperationMessage' => 'Command completed succesfully.',
          'OperationResult' => 'SUCCESS',
          'Balance' => Php.number_format(Php.get(response, balance_key) || 0, 2),
          'CurrencyId' => mapped['id'],
          'CurrencyInfo' => nil,
          'CurrencyName' => mapped['name'],
          'CurrencySymbol' => mapped['symbol']
        }
      rescue ApiError => e
        {
          'ErrorCode' => format_error_code(e.code),
          'OperationMessage' => e.message,
          'OperationResult' => 'FAILED',
          'Balance' => '0.00',
          'CurrencyId' => mapped['id'],
          'CurrencyInfo' => nil,
          'CurrencyName' => mapped['name'],
          'CurrencySymbol' => mapped['symbol']
        }
      end
    end

    # --- search and lists ------------------------------------------------------

    def check_availability(domains, extensions, period, command = 'create')
      queries = []
      Php.values(domains).each do |domain|
        Php.values(extensions).each do |tld|
          queries << { 'domainName' => "#{Php.to_s(domain)}.#{Php.ltrim(tld, '.')}" }
        end
      end

      if queries.empty?
        return {
          'result' => RESULT_ERROR,
          'error' => set_error('AVAILABILITY', 'Domain names not found.', 'No domain names provided for availability check')
        }
      end

      response = request('POST', 'domains/bulk-search', queries)

      data = []
      items = Php.get(response, 'infos')
      items = response if items.nil?
      if Php.array?(items)
        Php.values(items).each do |item|
          next unless Php.array?(item)

          raw_tld = Php.get(item, 'tld')
          if raw_tld.nil?
            name = Php.to_s(Php.get(item, 'domainName') || '')
            dot = name.rindex('.')
            raw_tld = dot ? name[(dot + 1)..] : ''
          end
          tld = Php.lower(raw_tld)
          domain_raw = Php.get(item, 'domainName') || ''
          lower = Php.lower(domain_raw)
          suffix = ".#{tld}"
          domain_name = tld != '' && lower.end_with?(suffix) ? lower[0, lower.length - suffix.length] : lower
          status = Php.lower(Php.get(item, 'status') || '')
          available = %w[available 1 true].include?(status)
          price = Php.get(item, 'price')
          period_out = Php.get(item, 'period')
          is_fee = Php.get(item, 'isPremium')

          data << {
            'TLD' => tld,
            'DomainName' => domain_name,
            'Status' => available ? 'available' : 'notavailable',
            'Command' => command,
            'Period' => period_out.nil? ? period : period_out,
            'IsFee' => is_fee.nil? ? false : is_fee,
            'Price' => price.nil? ? nil : Php.number_format(price, 4),
            'Currency' => Php.get(item, 'currency'),
            'Reason' => Php.get(item, 'reason')
          }
        end
      end
      data
    rescue ApiError => e
      error_envelope(e, 'AVAILABILITY')
    end

    def get_list(extra_parameters = {})
      params = Php.to_hash(extra_parameters)
      params['MaxResultCount'] = Php.to_i(params['PageSize']) unless params['PageSize'].nil?
      unless params['PageNumber'].nil?
        page_size = Php.to_i(params['PageSize'].nil? ? 200 : params['PageSize'])
        params['SkipCount'] = Php.to_i(params['PageNumber']) * page_size
      end
      unless params['OrderColumn'].nil?
        direction = Php.upper(params['OrderDirection'].nil? ? 'ASC' : params['OrderDirection']) == 'DESC' ? 'DESC' : 'ASC'
        params['Sorting'] = "#{Php.to_s(params['OrderColumn'])} #{direction}"
      end
      %w[PageNumber PageSize OrderColumn OrderDirection].each { |k| params.delete(k) }

      merged = { 'MaxResultCount' => 200, 'SkipCount' => 0 }.merge(params)
      response = request('GET', 'domains', merged)

      items = Php.get(response, 'items')
      domains = if items.nil?
                  []
                else
                  php_map(items) { |item| list_item(item) }
                end

      {
        'data' => { 'Domains' => domains },
        'result' => RESULT_OK,
        'TotalCount' => Php.to_i(Php.get(response, 'totalCount') || 0)
      }
    rescue ApiError => e
      error_envelope(e, 'DOMAIN_LIST')
    end

    PRICE_TYPES = {
      'register' => 'registration', 'renew' => 'renew', 'transfer' => 'transfer',
      'restore' => 'restore', 'refund' => 'refund', 'backorder' => 'backorder'
    }.freeze

    def get_tld_list(count = 20)
      response = request('GET', 'products/tlds', { 'MaxResultCount' => count, 'SkipCount' => 0 })

      tld_data = []
      id_counter = 1
      items = Php.get(response, 'items')
      if Php.array?(items)
        Php.values(items).each do |tld|
          pricing = {}
          currencies = {}
          first_price = Php.get(tld, 'prices', 0)
          if Php.array?(first_price)
            PRICE_TYPES.each do |api_type, out_type|
              api_value = Php.get(first_price, api_type)
              next if api_value.nil?

              if Php.array?(api_value) && Php.isset?(api_value, 0)
                Php.values(api_value).each do |info|
                  next unless Php.array?(info)

                  add_price(pricing, currencies, out_type, info)
                end
              elsif Php.array?(api_value)
                add_price(pricing, currencies, out_type, api_value)
              end
            end
          end

          pricing.each_key do |type|
            pricing[type] = pricing[type].sort_by { |k, _| k }.to_h { |k, v| [k.to_s, v] }
          end

          max_char = Php.get(tld, 'constraints', 'maxLenght')
          max_period = Php.get(tld, 'maxRegistrationPeriod')
          min_char = Php.get(tld, 'constraints', 'minLength')
          min_period = Php.get(tld, 'minRegistrationPeriod')
          status = Php.get(tld, 'status')
          tld_data << {
            'id' => id_counter,
            'status' => status.nil? ? 'Active' : status,
            'maxchar' => max_char.nil? ? 63 : max_char,
            'maxperiod' => max_period.nil? ? 10 : max_period,
            'minchar' => min_char.nil? ? 1 : min_char,
            'minperiod' => min_period.nil? ? 1 : min_period,
            'tld' => Php.get(tld, 'name'),
            'pricing' => pricing,
            'currencies' => currencies
          }
          id_counter += 1
        end
      end

      { 'data' => tld_data, 'result' => RESULT_OK }
    rescue ApiError => e
      error_envelope(e, 'TLD_LIST')
    end

    # --- domain ----------------------------------------------------------------

    def get_details(domain_name)
      response = request('GET', 'domains/info', { 'DomainName' => domain_name })
      parse_domain_info(response)
    rescue ApiError => e
      error_envelope(e, 'DOMAIN_DETAILS')
    end

    def sync_from_registry(domain_name)
      get_details(domain_name)
    end

    def modify_name_server(domain_name, name_servers)
      payload = { 'domainName' => domain_name, 'nameServers' => normalize_host_name_list(name_servers) }
      response = request('PUT', 'domains/dns/name-server', payload)
      ns = Php.get(response, 'nameServers')
      { 'result' => RESULT_OK, 'data' => { 'NameServers' => ns.nil? ? payload['nameServers'] : ns } }
    rescue ApiError => e
      error_envelope(e, 'MODIFY_NS')
    end

    def enable_theft_protection_lock(domain_name)
      request('POST', 'domains/lock', { 'domainName' => domain_name })
      { 'result' => RESULT_OK, 'data' => { 'LockStatus' => true } }
    rescue ApiError => e
      error_envelope(e, 'ENABLE_LOCK')
    end

    def disable_theft_protection_lock(domain_name)
      request('POST', 'domains/unlock', { 'domainName' => domain_name })
      { 'result' => RESULT_OK, 'data' => { 'LockStatus' => false } }
    rescue ApiError => e
      error_envelope(e, 'DISABLE_LOCK')
    end

    # `reason` is kept for signature compatibility only: the gateway's
    # DomainPrivacyInput has no reason field, so it is not sent.
    def modify_privacy_protection_status(domain_name, status, _reason = DEFAULT_REASON)
      enabled = if status == true || status == false
                  status
                elsif Php.array?(status)
                  false
                else
                  Php.filter_bool(status)
                end
      request('POST', 'domains/privacy', { 'domainName' => domain_name, 'privacyStatus' => enabled })
      { 'data' => { 'PrivacyProtectionStatus' => enabled }, 'result' => RESULT_OK }
    rescue ApiError => e
      error_envelope(e, 'MODIFY_PRIVACY')
    end

    def renew(domain_name, period)
      response = request('POST', 'domains/renew', { 'domainName' => domain_name, 'period' => period })
      failed = operation_failure(response, 'RENEW_DOMAIN')
      return failed if failed

      expiration = Php.get(response, 'expirationDate')
      if Php.truthy?(expiration)
        { 'result' => RESULT_OK, 'data' => { 'ExpirationDate' => format_api_date(expiration) } }
      else
        send_error_to_sentry_async(ApiError.new("[DOMAIN_RENEW] #{DEFAULT_ERRORS['DOMAIN_RENEW'][1]}", 0))
        { 'result' => RESULT_ERROR, 'error' => set_error('DOMAIN_RENEW') }
      end
    rescue ApiError => e
      error_envelope(e, 'RENEW_DOMAIN')
    end

    def register_with_contact_info(domain_name, period, contacts, name_servers = [], epp_lock = true,
                                   privacy_lock = false, additional_attributes = {})
      payload_contacts = Php.pairs(Php.stringify_keys(contacts)).map do |type, details|
        parse_contact(details, Php.ucfirst(Php.lower(type)))
      end

      ns = normalize_host_name_list(name_servers)
      ns = DEFAULT_NAMESERVERS.dup if ns.empty?

      attrs = Php.to_hash(Php.to_array(Php.stringify_keys(additional_attributes)))
      attrs = normalize_tr_attributes(attrs) if Php.lower(domain_name).end_with?('.tr')
      attrs = stringify_attributes(attrs)

      payload = {
        'domainName' => domain_name,
        'period' => period,
        'nameServers' => ns,
        'isLocked' => epp_lock,
        'privacyEnabled' => privacy_lock,
        'contacts' => payload_contacts,
        'tldAttributes' => attrs
      }
      response = request('POST', 'domains/register-with-contacts', payload)
      failed = operation_failure(response, 'REGISTER_DOMAIN')
      return failed if failed

      parse_domain_info(response)
    rescue ApiError => e
      error_envelope(e, 'REGISTER_DOMAIN')
    end

    # --- contacts --------------------------------------------------------------

    CONTACT_TYPE_IN = { 'Admin' => 'Administrative', 'Billing' => 'Billing', 'Tech' => 'Technical',
                        'Registrant' => 'Registrant' }.freeze
    # get_contacts: matched case-insensitively, long and short spellings.
    CONTACT_TYPE_LOOKUP = {
      'admin' => 'Administrative', 'administrative' => 'Administrative', 'billing' => 'Billing',
      'tech' => 'Technical', 'technical' => 'Technical', 'registrant' => 'Registrant', 'owner' => 'Registrant'
    }.freeze
    CONTACT_TYPE_OUT = { 'Administrative' => 'Admin', 'Technical' => 'Tech', 'Billing' => 'Billing',
                         'Registrant' => 'Registrant' }.freeze

    def get_contacts(domain_name)
      info = request('GET', 'domains/info', { 'DomainName' => domain_name })
      contacts = {}
      list = Php.get(info, 'contacts')
      if Php.array?(list)
        Php.values(list).each do |item|
          next unless Php.array?(item)

          api_type = Php.trim(Php.to_s(first_set(Php.get(item, 'contactType'), '')))
          key = CONTACT_TYPE_LOOKUP[Php.lower(api_type)] || Php.ucfirst(Php.lower(api_type))
          next if key == ''

          merged = Php.to_hash(item).merge('type' => key)
          contacts[key] = parse_contact_info(merged)
        end
      end

      ordered = {}
      %w[Administrative Billing Registrant Technical].each do |key|
        ordered[key] = contacts.delete(key) unless contacts[key].nil?
      end
      contacts.each { |key, contact| ordered[key] = contact }
      { 'data' => { 'contacts' => ordered }, 'result' => RESULT_OK }
    rescue ApiError => e
      error_envelope(e, 'GET_CONTACTS')
    end

    def save_contacts(domain_name, contacts)
      payload_contacts = Php.pairs(Php.stringify_keys(contacts)).map do |type, details|
        parse_contact(details, Php.ucfirst(Php.lower(type)))
      end
      response = request('PUT', 'domains/contacts/update', { 'domainName' => domain_name, 'contacts' => payload_contacts })

      parsed = {}
      list = Php.get(response, 'contacts')
      if Php.array?(list)
        Php.values(list).each do |contact|
          parsed[Php.ucfirst(Php.lower(Php.get(contact, 'type')))] = parse_contact_info(contact)
        end
      end
      { 'result' => RESULT_OK, 'data' => { 'contacts' => parsed } }
    rescue ApiError => e
      error_envelope(e, 'SAVE_CONTACTS')
    end

    # --- child nameservers -----------------------------------------------------

    def add_child_name_server(domain_name, name_server, ip_address)
      payload = {
        'domainName' => domain_name,
        'hostName' => normalize_host_name(name_server),
        'ipAddresses' => [{ 'ipAddress' => ip_address, 'ipVersion' => Php.ipv4?(ip_address) ? 'v4' : 'v6' }]
      }
      request('POST', 'domains/dns/host', payload)
      { 'result' => RESULT_OK, 'data' => { 'NameServer' => name_server, 'IPAdresses' => [ip_address] } }
    rescue ApiError => e
      error_envelope(e, 'ADD_CHILD_NS')
    end

    def delete_child_name_server(domain_name, name_server)
      request('DELETE', 'domains/dns/host', { 'domainName' => domain_name, 'hostName' => normalize_host_name(name_server) })
      { 'result' => RESULT_OK, 'data' => { 'NameServer' => name_server } }
    rescue ApiError => e
      error_envelope(e, 'DELETE_CHILD_NS')
    end

    def modify_child_name_server(domain_name, name_server, ip_address)
      host = normalize_host_name(name_server)
      payload = {
        'domainName' => domain_name,
        'hostName' => host,
        'newHostName' => host,
        'ipAddresses' => [{ 'ipAddress' => ip_address, 'ipVersion' => Php.ipv4?(ip_address) ? 'v4' : 'v6' }]
      }
      response = request('PUT', 'domains/dns/host', payload)
      host_out = Php.get(response, 'hostName')
      ips_out = Php.get(response, 'ipAddresses')
      {
        'result' => RESULT_OK,
        'data' => { 'NameServer' => host_out.nil? ? host : host_out, 'IPAdresses' => ips_out.nil? ? [ip_address] : ips_out }
      }
    rescue ApiError => e
      error_envelope(e, 'MODIFY_CHILD_NS')
    end

    # --- transfers -------------------------------------------------------------

    # Contacts are never sent with a transfer: the registrar handles them, so
    # the request always carries an empty contact list.
    def transfer(domain_name, epp_code, period)
      payload = { 'domainName' => domain_name, 'authCode' => epp_code, 'period' => period, 'contacts' => [] }
      response = request('POST', 'domains/transfer', payload)
      failed = operation_failure(response, 'TRANSFER_DOMAIN')
      return failed if failed

      parse_domain_info(response)
    rescue ApiError => e
      error_envelope(e, 'TRANSFER_DOMAIN')
    end

    def cancel_transfer(domain_name)
      transfer_action(domain_name, 'cancel', 'Cancelled', 'CANCEL_TRANSFER')
    end

    def approve_transfer(domain_name)
      transfer_action(domain_name, 'approve', 'Approved', 'APPROVE_TRANSFER')
    end

    def reject_transfer(domain_name)
      transfer_action(domain_name, 'reject', 'Rejected', 'REJECT_TRANSFER')
    end

    def check_transfer(domain_name, auth_code)
      response = request('POST', 'domains/transfers/check', { 'domainName' => domain_name, 'authCode' => auth_code })

      available = Php.truthy?(Php.get(response, 'transferAvailabilityStatus'))
      additional = Php.get(response, 'additionalAttributes')
      message = Php.get(response, 'message')
      message_key = Php.get(response, 'messageKey')
      envelope = {
        'result' => available ? RESULT_OK : RESULT_ERROR,
        'data' => {
          'TransferAvailabilityStatus' => available,
          'AuthCodeIsRequired' => Php.truthy?(Php.get(response, 'authCodeIsRequired')),
          'AuthCodeIsValid' => Php.truthy?(Php.get(response, 'authCodeIsValid')),
          'UserTransferRequired' => Php.truthy?(Php.get(response, 'userTransferRequired')),
          'TransferLock' => Php.truthy?(Php.get(response, 'transferLock')),
          'Message' => Php.to_s(message.nil? ? '' : message),
          'MessageKey' => Php.to_s(message_key.nil? ? '' : message_key),
          'Additional' => additional.nil? ? {} : Php.to_array(additional)
        }
      }
      unless available
        envelope['error'] = set_error(
          'TRANSFER_NOT_AVAILABLE',
          message.nil? ? 'Domain is not transferable' : message,
          message_key.nil? ? (message.nil? ? '' : message) : message_key
        )
      end
      envelope
    rescue ApiError => e
      error_envelope(e, 'CHECK_TRANSFER')
    end

    # --- DNS zone --------------------------------------------------------------

    def get_resource_records(domain_name)
      response = request('GET', 'domains/zones', { 'domainName' => domain_name })

      records = []
      Php.values(Php.to_array(response)).each do |set|
        next unless Php.array?(set)

        name = Php.get(set, 'name') || ''
        type = Php.get(set, 'type') || ''
        ttl = Php.to_i(Php.get(set, 'ttl') || 0)
        rows = Php.get(set, 'records') || []
        if !Php.array?(rows) || rows.empty?
          records << { 'Name' => name, 'Type' => type, 'TTL' => ttl, 'Content' => '', 'Disabled' => false }
          next
        end
        Php.values(rows).each do |rec|
          content = Php.get(rec, 'content')
          records << {
            'Name' => name, 'Type' => type, 'TTL' => ttl,
            'Content' => content.nil? ? '' : content,
            'Disabled' => Php.truthy?(Php.get(rec, 'disabled'))
          }
        end
      end

      { 'result' => RESULT_OK, 'data' => { 'records' => records } }
    rescue ApiError => e
      error_envelope(e, 'GET_ZONE')
    end

    def add_resource_record(domain_name, name, type, content, ttl = 3600, apply = true)
      if (why = unsupported_zone_type(type))
        return { 'result' => RESULT_ERROR, 'error' => set_error('ADD_ZONE', why, why) }
      end

      name = relativize_record_name(name, domain_name)
      body = { 'zoneStruct' => build_zone_struct(name, type, content, ttl) }
      request('POST', "domains/zones?#{Php.http_build_query({ 'domainName' => domain_name })}", body)
      if Php.truthy?(apply)
        applied = apply_resource_records(domain_name)
        return applied if applied['result'] != RESULT_OK
      end

      { 'result' => RESULT_OK,
        'data' => { 'Name' => name, 'Type' => body['zoneStruct']['type'], 'TTL' => body['zoneStruct']['ttl'], 'Content' => content } }
    rescue ApiError => e
      error_envelope(e, 'ADD_ZONE')
    end

    def edit_resource_record(domain_name, record_name, name, type, content, ttl = 3600, apply = true)
      if (why = unsupported_zone_type(type))
        return { 'result' => RESULT_ERROR, 'error' => set_error('EDIT_ZONE', why, why) }
      end

      name = relativize_record_name(name, domain_name)
      body = { 'zoneStruct' => build_zone_struct(name, type, content, ttl) }
      query = Php.http_build_query({ 'domainName' => domain_name, 'recordName' => record_name })
      request('PUT', "domains/zones?#{query}", body)
      if Php.truthy?(apply)
        applied = apply_resource_records(domain_name)
        return applied if applied['result'] != RESULT_OK
      end

      { 'result' => RESULT_OK,
        'data' => { 'Name' => name, 'Type' => body['zoneStruct']['type'], 'TTL' => body['zoneStruct']['ttl'], 'Content' => content } }
    rescue ApiError => e
      error_envelope(e, 'EDIT_ZONE')
    end

    def delete_resource_record(domain_name, name, record, record_type, apply = true)
      request('DELETE', 'domains/zones', {
                'domainName' => domain_name, 'Name' => name, 'Record' => record, 'RecordType' => record_type
              })
      if Php.truthy?(apply)
        applied = apply_resource_records(domain_name)
        return applied if applied['result'] != RESULT_OK
      end

      { 'result' => RESULT_OK, 'data' => { 'Name' => name, 'Type' => record_type, 'Content' => record } }
    rescue ApiError => e
      error_envelope(e, 'DELETE_ZONE')
    end

    def apply_resource_records(domain_name)
      request('POST', "domains/zones/apply?#{Php.http_build_query({ 'domainName' => domain_name })}", [])
      { 'result' => RESULT_OK, 'data' => { 'DomainName' => domain_name } }
    rescue ApiError => e
      error_envelope(e, 'APPLY_ZONE')
    end

    def set_resource_record_set(domain_name, name, type, contents, ttl = 3600, apply = true)
      raise TypeError, 'contents must be an Array' unless Php.array?(contents)

      if (why = unsupported_zone_type(type))
        return { 'result' => RESULT_ERROR, 'error' => set_error('SET_ZONE', why, why) }
      end

      name = relativize_record_name(name, domain_name)
      contents = Php.values(contents).map { |v| Php.to_s(v) }.reject { |v| Php.trim(v) == '' }

      return delete_resource_record_set(domain_name, name, type, apply) if contents.empty?

      body = { 'zoneStruct' => build_zone_struct(name, type, contents, ttl) }
      request('POST', "domains/zones?#{Php.http_build_query({ 'domainName' => domain_name })}", body)
      if Php.truthy?(apply)
        applied = apply_resource_records(domain_name)
        return applied if applied['result'] != RESULT_OK
      end

      { 'result' => RESULT_OK,
        'data' => { 'Name' => name, 'Type' => body['zoneStruct']['type'], 'TTL' => body['zoneStruct']['ttl'], 'Contents' => contents } }
    rescue ApiError => e
      error_envelope(e, 'SET_ZONE')
    end

    def delete_resource_record_set(domain_name, name, type, apply = true, known_value = '')
      type = Php.upper(Php.trim(type))
      value = Php.to_s(known_value)

      if value == ''
        current = get_resource_records(domain_name)
        return current if current['result'] != RESULT_OK

        fqdn = qualify_record_name(name, domain_name)
        current['data']['records'].each do |rec|
          next unless Php.casecmp_eq?(rec['Name'], fqdn) && Php.casecmp_eq?(rec['Type'], type)

          value = Php.to_s(rec['Content'])
          break
        end
        return { 'result' => RESULT_OK, 'data' => { 'Name' => name, 'Type' => type, 'Removed' => false } } if value == ''
      end

      delete_resource_record(domain_name, qualify_record_name(name, domain_name), value, type, apply)
    rescue ApiError => e
      error_envelope(e, 'DELETE_ZONE')
    end

    def add_resource_record_value(domain_name, name, type, value, ttl = nil, apply = true)
      if (why = unsupported_zone_type(type))
        return { 'result' => RESULT_ERROR, 'error' => set_error('ADD_ZONE', why, why) }
      end

      name = relativize_record_name(name, domain_name)
      set = read_resource_record_set(domain_name, name, type)
      return set if set.key?('result')

      if set['contents'].any? { |existing| same_record_value?(type, existing, value) }
        return { 'result' => RESULT_OK,
                 'data' => { 'Name' => name, 'Type' => Php.upper(type), 'Contents' => set['contents'], 'Changed' => false } }
      end

      contents = set['contents'] + [Php.to_s(value)]
      set_resource_record_set(domain_name, name, type, contents, ttl.nil? ? fallback_ttl(set) : ttl, apply)
    rescue ApiError => e
      error_envelope(e, 'ADD_ZONE')
    end

    def remove_resource_record_value(domain_name, name, type, value, apply = true)
      if (why = unsupported_zone_type(type))
        return { 'result' => RESULT_ERROR, 'error' => set_error('DELETE_ZONE', why, why) }
      end

      name = relativize_record_name(name, domain_name)
      set = read_resource_record_set(domain_name, name, type)
      return set if set.key?('result')

      remaining = []
      found = false
      set['contents'].each do |existing|
        if !found && same_record_value?(type, existing, value)
          found = true
          next
        end
        remaining << existing
      end

      unless found
        return { 'result' => RESULT_OK,
                 'data' => { 'Name' => name, 'Type' => Php.upper(type), 'Contents' => set['contents'], 'Changed' => false } }
      end

      return delete_resource_record_set(domain_name, name, type, apply, Php.to_s(value)) if remaining.empty?

      set_resource_record_set(domain_name, name, type, remaining, fallback_ttl(set), apply)
    rescue ApiError => e
      error_envelope(e, 'DELETE_ZONE')
    end

    def replace_resource_record_value(domain_name, name, type, old_value, new_value, ttl = nil, apply = true)
      if (why = unsupported_zone_type(type))
        return { 'result' => RESULT_ERROR, 'error' => set_error('EDIT_ZONE', why, why) }
      end

      name = relativize_record_name(name, domain_name)
      set = read_resource_record_set(domain_name, name, type)
      return set if set.key?('result')

      contents = []
      found = false
      set['contents'].each do |existing|
        if !found && same_record_value?(type, existing, old_value)
          found = true
          contents << Php.to_s(new_value)
          next
        end
        contents << existing
      end

      unless found
        why = format('No %<type>s record "%<name>s" with value "%<value>s" to edit.',
                     type: Php.upper(type), name: name, value: Php.to_s(old_value))
        return { 'result' => RESULT_ERROR, 'error' => set_error('EDIT_ZONE', why, why) }
      end

      set_resource_record_set(domain_name, name, type, contents, ttl.nil? ? fallback_ttl(set) : ttl, apply)
    rescue ApiError => e
      error_envelope(e, 'EDIT_ZONE')
    end

    # --- forwarding ------------------------------------------------------------

    def get_forwarding(domain_name)
      response = request('GET', 'domains/forwards', { 'domainName' => domain_name })
      alias_ = Php.get(response, 'redirectAlias')
      type = Php.get(response, 'redirectType')
      {
        'result' => RESULT_OK,
        'data' => {
          'Enabled' => Php.truthy?(alias_),
          'RedirectAddress' => Php.to_s(alias_.nil? ? '' : alias_),
          'ForwardType' => Php.to_s(type.nil? ? '' : type)
        }
      }
    rescue ApiError => e
      raw = Php.get(@last_response, 'raw_response')
      raw = e.message if raw.nil?
      if forward_not_set?(e)
        return { 'result' => RESULT_OK, 'data' => { 'Enabled' => false, 'RedirectAddress' => '', 'ForwardType' => '' } }
      end

      details = Php.get(@last_parsed_response, 'Details')
      { 'result' => RESULT_ERROR, 'error' => set_error(format_error_code(e.code), e.message, details.nil? ? raw : details) }
    end

    def set_forwarding(domain_name, redirect_address, forward_type = 'Standard')
      type = Php.ucfirst(Php.lower(Php.trim(forward_type)))
      unless FORWARD_TYPES.include?(type)
        why = format('Forward type "%<type>s" is not supported. Supported types: %<list>s.',
                     type: Php.to_s(forward_type), list: FORWARD_TYPES.join(', '))
        return { 'result' => RESULT_ERROR, 'error' => set_error('SET_FORWARD', why, why) }
      end
      if Php.trim(redirect_address) == ''
        why = 'Redirect address is required.'
        return { 'result' => RESULT_ERROR, 'error' => set_error('SET_FORWARD', why, why) }
      end

      request('POST', 'domains/forwards', {
                'domainName' => domain_name, 'redirectAddress' => redirect_address, 'forwardType' => type
              })
      { 'result' => RESULT_OK, 'data' => { 'RedirectAddress' => redirect_address, 'ForwardType' => type } }
    rescue ApiError => e
      error_envelope(e, 'SET_FORWARD')
    end

    def delete_forwarding(domain_name)
      request('DELETE', 'domains/forwards', { 'DomainName' => domain_name })
      { 'result' => RESULT_OK, 'data' => { 'DomainName' => domain_name, 'Removed' => true } }
    rescue ApiError => e
      # Nothing configured: deleting is a no-op.
      return { 'result' => RESULT_OK, 'data' => { 'DomainName' => domain_name, 'Removed' => false } } if forward_not_set?(e)

      error_envelope(e, 'DELETE_FORWARD')
    end

    # --- utilities (no network) --------------------------------------------------

    def is_tr_tld(domain)
      str = Php.to_s(domain).b
      tail = str.bytesize >= 3 ? str.byteslice(-3, 3) : str
      Php.lower(tail) == '.tr'
    end

    VALIDATE_DEFAULTS = {
      'FirstName' => 'Isimyok',
      'LastName' => 'Isimyok',
      'AddressLine1' => 'Addres yok',
      'City' => 'ISTANBUL',
      'Country' => 'TR',
      'ZipCode' => '34000',
      'Phone' => '5555555555',
      'PhoneCountryCode' => '90'
    }.freeze

    def validate_contact(contact)
      contact = Php.to_hash(contact)
      VALIDATE_DEFAULTS.each { |key, value| contact[key] = value if contact[key].nil? }
      # No State default: a missing state falls back to the city below.
      contact['State'] = '' if contact['State'].nil?

      contact['FirstName'] = sanitize_person_name(contact['FirstName'])
      contact['LastName'] = sanitize_person_name(contact['LastName'])

      contact['FirstName'] = VALIDATE_DEFAULTS['FirstName'] if Php.trim(contact['FirstName']).empty?
      contact['LastName'] = contact['FirstName'] if Php.trim(contact['LastName']).empty?
      contact['AddressLine1'] = VALIDATE_DEFAULTS['AddressLine1'] if Php.trim(contact['AddressLine1']).empty?
      contact['City'] = VALIDATE_DEFAULTS['City'] if Php.trim(contact['City']).empty?
      contact['State'] = contact['City'] if Php.trim(contact['State']).empty?
      contact['Country'] = normalize_country_code(contact['Country'])
      contact['Country'] = VALIDATE_DEFAULTS['Country'] if Php.trim(contact['Country']).empty?
      contact['ZipCode'] = VALIDATE_DEFAULTS['ZipCode'] if Php.trim(contact['ZipCode']).empty?

      phone, phone_cc = normalize_phone(contact['Phone'], contact['PhoneCountryCode'])
      contact['Phone'] = phone
      contact['PhoneCountryCode'] = phone_cc
      contact['PhoneCountryCode'] = VALIDATE_DEFAULTS['PhoneCountryCode'] if Php.trim(contact['PhoneCountryCode']).empty?
      contact['Phone'] = VALIDATE_DEFAULTS['Phone'] if Php.trim(contact['Phone']).empty?

      fax, fax_cc = normalize_phone(contact['Fax'].nil? ? '' : contact['Fax'],
                                    contact['FaxCountryCode'].nil? ? '' : contact['FaxCountryCode'])
      contact['Fax'] = fax
      contact['FaxCountryCode'] = fax == '' ? '' : fax_cc

      contact
    end

    private

    # --- HTTP --------------------------------------------------------------------

    def request(method, endpoint, data = {})
      pace_zone_request(endpoint)

      @transport_failed = false
      @last_gateway_code = ''

      @start_at = monotonic
      @start_wall = Time.now
      @last_function = "request:#{method} #{endpoint.to_s.split('?', 2).first}"

      url = "#{@service_url}/#{endpoint.to_s.sub(%r{\A/+}, '')}"
      @last_request = { 'url' => url, 'method' => method, 'payload' => data }

      headers = {
        'Content-Type' => 'application/json',
        'Accept' => 'application/json',
        'X-API-KEY' => @token.to_s,
        '__reseller' => @reseller_id.to_s,
        'User-Agent' => USER_AGENT
      }

      body = nil
      if %w[GET DELETE].include?(method)
        url += "?#{Php.http_build_query(data)}" unless Php.empty?(data)
      else
        body = Php.json_encode(data)
      end

      begin
        raw = @transport.call(
          method: method, url: url, headers: headers, body: body,
          timeout: DEFAULT_TIMEOUT, connect_timeout: DEFAULT_CONNECT_TIMEOUT, verify_ssl: @ssl_verify
        )
      rescue TransportError => e
        transport_failure(url, e.code, e.message)
      rescue StandardError => e
        transport_failure(url, 0, e.message)
      end

      status, response_body, response_headers = unpack_response(raw)
      @last_response_headers = {
        'url' => url, 'http_code' => status, 'headers' => response_headers,
        'total_time' => (monotonic - @start_at).round(6)
      }
      decoded = Php.json_decode(response_body)
      @last_response = Php.array?(decoded) ? decoded : { 'raw_response' => response_body }

      if status >= 200 && status <= 299
        parsed = decoded
        @last_parsed_response = parsed
        maybe_send_performance
        return parsed
      end

      parsed = decoded
      if [301, 302].include?(status)
        parsed = { 'message' => 'Invalid API credentials', 'code' => 'CREDENTIALS',
                   'details' => 'Authentication failed. Check your API key and reseller ID.' }
      end

      message = first_set(Php.get(parsed, 'message'), Php.get(parsed, 'error', 'message'), response_body)
      code = first_set(Php.get(parsed, 'code'), Php.get(parsed, 'error', 'code'), "HTTP_#{status}")
      api_details = first_set(Php.get(parsed, 'details'), Php.get(parsed, 'error', 'details'))
      details = first_set(api_details, response_body)
      # The gateway's own code is kept as GatewayCode next to API_<status>.
      if code.is_a?(String) && code != '' && !code.start_with?('HTTP_') && code != 'CREDENTIALS'
        @last_gateway_code = code
      end

      if Php.trim(message) == ''
        message = "HTTP #{status} - #{http_status_reason(status)}"
        details = message if Php.trim(details) == ''
      end

      if BOILERPLATE_RE.match?(Php.to_s(message)) || Php.to_s(message) == Php.to_s(code)
        # Only the gateway's details field may replace the message, never the raw body.
        clean = Php.trim(Php.to_s(api_details).sub(/\ADna\s+/, ''))
        message = if clean != '' && clean != Php.to_s(message) && clean != Php.to_s(code) && !BOILERPLATE_RE.match?(clean)
                    clean
                  else
                    "The operation could not be completed by the registry (error: #{Php.to_s(code)}). " \
                      'Please try again or contact support.'
                  end
      end

      validation = first_set(Php.get(parsed, 'error', 'validationErrors'), Php.get(parsed, 'validationErrors'))
      if Php.array?(validation) && !validation.empty?
        flattened = flatten_validation_errors(validation)
        details = flattened unless flattened == ''
      end

      @last_parsed_response = set_error(code, message, details)
      error = ApiError.new(Php.to_s(message), status)
      error.set_backtrace(caller)
      send_error_to_sentry_async(error)
      raise error
    end

    def transport_failure(url, errno, detail)
      @transport_failed = true
      message = "Curl error during request: #{detail}"
      message = "Could not reach the DomainNameAPI service: the connection timed out. (#{detail})" if errno == 28
      @last_response_headers = { 'url' => url, 'http_code' => 0, 'headers' => {},
                                 'total_time' => (monotonic - @start_at).round(6) }
      @last_response = { 'raw_response' => false }
      @last_parsed_response = set_error("CURL_#{errno}", message, message)
      error = ApiError.new(message, errno)
      error.set_backtrace(caller)
      send_error_to_sentry_async(error)
      raise error
    end

    def unpack_response(raw)
      if raw.is_a?(Hash)
        status = raw[:status] || raw['status']
        body = raw[:body] || raw['body']
        headers = raw[:headers] || raw['headers'] || {}
      else
        status = raw.status
        body = raw.body
        headers = raw.respond_to?(:headers) ? raw.headers || {} : {}
      end
      [status.to_i, body.nil? ? '' : body.to_s, headers]
    end

    def maybe_send_performance
      duration = (monotonic - @start_at) * 1000.0
      return unless duration > 1000 || rand(1..1000) <= PERFORMANCE_SAMPLE_RATE

      send_performance_metrics_to_sentry(
        'operation' => @last_function,
        'duration' => duration,
        'success' => true,
        'timestamp' => Time.now.utc.strftime('%Y-%m-%dT%H:%M:%S.%LZ'),
        'start_timestamp' => @start_wall.utc.strftime('%Y-%m-%dT%H:%M:%S.%LZ')
      )
    end

    # $a ?? $b ?? $c
    def first_set(*values)
      values.find { |v| !v.nil? }
    end

    def pace_zone_request(endpoint)
      return unless endpoint.to_s.sub(%r{\A/+}, '').start_with?('domains/zones')

      if @last_zone_request_at.positive? && @zone_min_interval.positive?
        wait = @zone_min_interval - (monotonic - @last_zone_request_at)
        sleep(wait) if wait.positive?
      end
      @last_zone_request_at = monotonic
    end

    def http_status_reason(status)
      return HTTP_REASONS[status] if HTTP_REASONS.key?(status)
      return 'Server Error' if status >= 500
      return 'Client Error' if status >= 400

      'Unexpected Response'
    end

    # API_<status> for HTTP errors, CURL_<errno> for transport failures.
    def format_error_code(code)
      return Php.to_s(code) unless Php.numeric?(code)

      "#{@transport_failed ? 'CURL_' : 'API_'}#{Php.to_s(code)}"
    end

    def set_error(code, message = '', details = '')
      if code.is_a?(String) && DEFAULT_ERRORS.key?(code)
        default_message, default_details = DEFAULT_ERRORS[code]
        result = {
          'Code' => code,
          'Message' => Php.trim(message) != '' ? message : default_message,
          'Details' => Php.trim(details) != '' ? details : default_details
        }
      else
        result = { 'Code' => code, 'Message' => message, 'Details' => details }
      end
      if result['Code'].is_a?(String) && result['Code'].match?(/\AAPI_\d+\z/) && !Php.empty?(@last_gateway_code) &&
         @last_gateway_code != ''
        result['GatewayCode'] = @last_gateway_code
      end
      result
    end

    # register/transfer/renew can answer HTTP 200 with {"success": false}:
    # a refusal, returned as an error envelope (nil when it succeeded).
    def operation_failure(response, code)
      return nil unless response.is_a?(Hash) && response.key?('success') && response['success'] == false

      message = Php.trim(Php.to_s(first_set(response['message'], '')))
      message = 'The registry did not accept the request.' if message == ''
      { 'result' => RESULT_ERROR, 'error' => set_error(code, message, message) }
    end

    FORWARD_NOT_SET = 'redirect information not found'

    # The gateway answers "Redirect information not found" when no forwarding is set.
    def forward_not_set?(error)
      error.message.downcase.include?(FORWARD_NOT_SET) ||
        Php.to_s(first_set(Php.get(@last_response, 'raw_response'), '')).downcase.include?(FORWARD_NOT_SET) ||
        Php.json_encode(@last_response.nil? ? [] : @last_response).downcase.include?(FORWARD_NOT_SET)
    rescue StandardError
      false
    end

    # The catch block shared by every network method.
    def error_envelope(error, fallback)
      code = format_error_code(error.code)
      code = fallback if Php.empty?(code)
      details = Php.get(@last_parsed_response, 'Details')
      details = Php.get(@last_response, 'raw_response') if details.nil?
      details = error.message if details.nil?
      { 'result' => RESULT_ERROR, 'error' => set_error(code, error.message, details) }
    end

    # array_map() keeping the container type.
    def php_map(collection, &block)
      case collection
      when Hash then collection.transform_values(&block)
      when Array then collection.map(&block)
      else []
      end
    end

    # --- response parsing ------------------------------------------------------

    def list_item(item)
      status_code = Php.get(item, 'statusCode')
      status_text = Php.get(item, 'statusText')
      status = if !status_code.nil? && status_code != '' && !Php.numeric?(status_code)
                 Php.to_s(status_code)
               elsif !status_text.nil? && status_text != '' && !Php.numeric?(status_text)
                 Php.to_s(status_text)
               else
                 normalize_domain_status(first_set(Php.get(item, 'status'), ''))
               end
      ns = Php.get(item, 'nameServers')
      {
        'ID' => Php.to_i(first_set(Php.get(item, 'id'), 0)),
        'Status' => status,
        'DomainName' => first_set(Php.get(item, 'domainName'), ''),
        'AuthCode' => first_set(Php.get(item, 'authCode'), ''),
        'LockStatus' => Php.truthy?(Php.get(item, 'lockStatus')) ? 'true' : 'false',
        'PrivacyProtectionStatus' => Php.truthy?(Php.get(item, 'privacyProtectionStatus')) ? 'true' : 'false',
        'IsChildNameServer' => Php.truthy?(Php.get(item, 'hosts')) ? 'true' : 'false',
        'Contacts' => {
          'Billing' => { 'ID' => '' },
          'Technical' => { 'ID' => '' },
          'Administrative' => { 'ID' => '' },
          'Registrant' => { 'ID' => '' }
        },
        'Dates' => {
          'Start' => format_api_date(Php.get(item, 'startDate')),
          'Expiration' => format_api_date(Php.get(item, 'expirationDate')),
          'RemainingDays' => Php.to_i(first_set(Php.get(item, 'remainingDay'), 0))
        },
        'NameServers' => ns.nil? ? [] : ns,
        'Additional' => {},
        'ChildNameServers' => []
      }
    end

    def add_price(pricing, currencies, out_type, info)
      period = Php.to_i(first_set(Php.get(info, 'period'), 1))
      period = 1 if period < 1
      price = Php.get(info, 'price')
      (pricing[out_type] ||= {})[period] = price.nil? ? '0.0000' : Php.number_format(price, 4)
      currencies[out_type] = first_set(Php.get(info, 'currency'), '')
    end

    def normalize_domain_status(value)
      if Php.numeric?(value)
        DOMAIN_STATUS_MAP.fetch(Php.to_i(value)) { Php.to_s(value) }
      else
        Php.to_s(value)
      end
    end

    def parse_domain_info(data)
      return { 'result' => RESULT_ERROR, 'error' => set_error('RESPONSE') } if Php.empty?(data)

      remaining = Php.get(data, 'remainingDay')
      nameservers = Php.get(data, 'nameservers')
      additional = Php.get(data, 'additionalAttributes')
      hosts = Php.get(data, 'hosts')
      {
        'data' => {
          'ID' => Php.to_i(first_set(Php.get(data, 'id'), 0)),
          'Status' => normalize_domain_status(first_set(Php.get(data, 'status'), '')),
          'DomainName' => Php.to_s(first_set(Php.get(data, 'domainName'), Php.get(data, 'name'), '')),
          'AuthCode' => Php.to_s(first_set(Php.get(data, 'authCode'), Php.get(data, 'eppCode'), '')),
          'LockStatus' => Php.truthy?(Php.get(data, 'lockStatus')) ? 'true' : 'false',
          'PrivacyProtectionStatus' => Php.truthy?(Php.get(data, 'privacyProtectionStatus')) ? 'true' : 'false',
          'IsChildNameServer' => Php.truthy?(hosts) ? 'true' : 'false',
          'Contacts' => parse_contact_ids(first_set(Php.get(data, 'contacts'), [])),
          'Dates' => {
            'Start' => format_api_date(Php.get(data, 'startDate')),
            'Expiration' => format_api_date(Php.get(data, 'expirationDate')),
            'RemainingDays' => if remaining.nil?
                                 remaining_days_from_date(Php.get(data, 'expirationDate'))
                               else
                                 Php.to_i(remaining)
                               end
          },
          'NameServers' => nameservers.nil? ? [] : php_map(nameservers) { |v| Php.to_s(v) },
          'Additional' => additional.nil? ? {} : Php.to_array(additional),
          'ChildNameServers' => hosts.nil? ? [] : php_map(hosts) { |ns| child_name_server(ns) }
        },
        'result' => RESULT_OK
      }
    end

    def child_name_server(host)
      ips = Php.values(first_set(Php.get(host, 'ipAddresses'), [])).map { |ip| Php.get(ip, 'ipAddress') }
      { 'ns' => Php.get(host, 'name'), 'ip' => ips.empty? ? '' : ips.last }
    end

    def parse_contact_ids(contacts)
      result = {
        'Billing' => { 'ID' => 0 },
        'Technical' => { 'ID' => 0 },
        'Administrative' => { 'ID' => 0 },
        'Registrant' => { 'ID' => 0 }
      }
      return result unless Php.array?(contacts)

      Php.values(contacts).each do |c|
        api_type = first_set(Php.get(c, 'ContactType'), Php.get(c, 'contactType'), '')
        key = api_type.is_a?(String) ? CONTACT_TYPE_IN[api_type] : nil
        result[key]['ID'] = first_set(Php.get(c, 'handle'), Php.get(c, 'id'), 0) if key
      end
      result
    end

    def parse_contact_info(data)
      return [] if Php.empty?(data)

      g = ->(*keys) { first_set(*keys.map { |k| Php.get(data, k) }, '') }
      {
        'ID' => g.call('handle', 'id'),
        'Status' => first_set(Php.get(data, 'status'), 'Active'),
        'AuthCode' => g.call('authCode'),
        'FirstName' => g.call('firstName'),
        'LastName' => g.call('lastName'),
        'Company' => g.call('companyName', 'organizationName', 'company'),
        'EMail' => g.call('eMail', 'emailAddress', 'email'),
        'Type' => g.call('type'),
        'Address' => {
          'Line1' => g.call('address', 'addressLine1'),
          'Line2' => g.call('addressLine2'),
          'Line3' => g.call('addressLine3'),
          'State' => g.call('state', 'stateOrProvince'),
          'City' => g.call('city'),
          'Country' => g.call('country', 'countryCode'),
          'ZipCode' => g.call('postalCode', 'zipCode')
        },
        'Phone' => {
          'Phone' => { 'Number' => g.call('phone', 'phoneNumber'), 'CountryCode' => g.call('phoneCountryCode') },
          'Fax' => { 'Number' => g.call('fax', 'faxNumber'), 'CountryCode' => g.call('faxCountryCode') }
        },
        'Additional' => first_set(Php.get(data, 'additionalAttributes'), {})
      }
    end

    # Build a gateway contact (ContactLiteDto) from the flat or nested shape.
    def parse_contact(contact, type)
      api_type = CONTACT_TYPE_OUT[type] || type

      address = first_set(Php.get(contact, 'AddressLine1'), Php.get(contact, 'Address', 'Line1'), '')
      line2 = first_set(Php.get(contact, 'AddressLine2'), Php.get(contact, 'Address', 'Line2'), '')
      address = "#{Php.to_s(address)} #{Php.to_s(line2)}" unless Php.empty?(line2)

      phone = first_set(Php.get(contact, 'Phone'), Php.get(contact, 'Phone', 'Phone', 'Number'), '')
      phone_cc = first_set(Php.get(contact, 'PhoneCountryCode'), Php.get(contact, 'Phone', 'Phone', 'CountryCode'), '')
      fax = first_set(Php.get(contact, 'Fax'), Php.get(contact, 'Phone', 'Fax', 'Number'), '')
      fax_cc = first_set(Php.get(contact, 'FaxCountryCode'), Php.get(contact, 'Phone', 'Fax', 'CountryCode'), '')

      if Php.array?(phone)
        phone_cc = first_set(Php.get(phone, 'Phone', 'CountryCode'), '')
        phone = first_set(Php.get(phone, 'Phone', 'Number'), '')
      end
      if Php.array?(fax)
        fax_cc = first_set(Php.get(fax, 'Fax', 'CountryCode'), '')
        fax = first_set(Php.get(fax, 'Fax', 'Number'), '')
      end

      validated = validate_contact(
        'FirstName' => first_set(Php.get(contact, 'FirstName'), ''),
        'LastName' => first_set(Php.get(contact, 'LastName'), ''),
        'AddressLine1' => address,
        'City' => first_set(Php.get(contact, 'City'), Php.get(contact, 'Address', 'City'), ''),
        'State' => first_set(Php.get(contact, 'State'), Php.get(contact, 'Address', 'State'), ''),
        'Country' => first_set(Php.get(contact, 'Country'), Php.get(contact, 'Address', 'Country'), ''),
        'ZipCode' => first_set(Php.get(contact, 'ZipCode'), Php.get(contact, 'Address', 'ZipCode'), ''),
        'Phone' => phone,
        'PhoneCountryCode' => phone_cc,
        'Fax' => fax,
        'FaxCountryCode' => fax_cc
      )

      {
        'contactType' => api_type,
        'firstName' => validated['FirstName'],
        'lastName' => validated['LastName'],
        'companyName' => first_set(Php.get(contact, 'Company'), ''),
        'eMail' => first_set(Php.get(contact, 'EMail'), ''),
        'address' => validated['AddressLine1'],
        'city' => validated['City'],
        'state' => validated['State'],
        'country' => validated['Country'],
        'postalCode' => validated['ZipCode'],
        'phoneCountryCode' => validated['PhoneCountryCode'],
        'phone' => validated['Phone'],
        'faxCountryCode' => validated['FaxCountryCode'],
        'fax' => validated['Fax'],
        'isHidden' => Php.truthy?(first_set(Php.get(contact, 'IsHidden'), false))
      }
    end

    def sanitize_person_name(name)
      str = Php.to_s(name)
      clean = if str.dup.force_encoding(Encoding::UTF_8).valid_encoding?
                str.dup.force_encoding(Encoding::UTF_8).gsub(/[^\p{L}[[:space:]]'\-]/, '')
              else
                str.b.gsub(/[^a-zA-Z\s'\-]/n, '').force_encoding(Encoding::UTF_8)
              end
      Php.trim(clean.gsub(/[[:space:]]+/, ' '))
    end

    COUNTRY_NAMES = {
      'turkey' => 'TR', 'türkiye' => 'TR', 'turkiye' => 'TR',
      'united states' => 'US', 'united states of america' => 'US', 'usa' => 'US',
      'united kingdom' => 'GB', 'great britain' => 'GB', 'england' => 'GB',
      'germany' => 'DE', 'deutschland' => 'DE', 'france' => 'FR', 'spain' => 'ES',
      'italy' => 'IT', 'netherlands' => 'NL', 'india' => 'IN', 'china' => 'CN',
      'russia' => 'RU', 'canada' => 'CA', 'australia' => 'AU', 'brazil' => 'BR'
    }.freeze

    def normalize_country_code(country)
      country = Php.trim(country)
      return '' if country == ''
      return Php.upper(country) if country.bytesize == 2

      COUNTRY_NAMES.fetch(Php.lower(country)) { country }
    end

    TWO_DIGIT_CALLING_CODES = %w[20 27 30 31 32 33 34 36 39 40 41 43 44 45 46 47 48 49 51 52 53 54 55 56 57 58
                                 60 61 62 63 64 65 66 81 82 84 86 90 91 92 93 94 95 98].freeze

    # E.164 calling code at the start of an international number (digits only).
    def calling_code_prefix(digits)
      return '' if digits == '' || digits[0] == '0'
      return digits[0] if %w[1 7].include?(digits[0])
      return digits[0, 2] if TWO_DIGIT_CALLING_CODES.include?(digits[0, 2])

      digits.length >= 3 ? digits[0, 3] : ''
    end

    # Split a free-form phone number into [subscriber number, country code].
    def normalize_phone(number, country_code)
      number_s = Php.to_s(number).b
      intl = number_s.match?(/\A\s*(\+|00)/n)
      digits = number_s.gsub(/\D/n, '')
      cc = Php.to_s(country_code).b.gsub(/\D/n, '')

      return ['', cc] if digits == ''

      if intl
        digits = digits[2..] if digits.start_with?('00')
        if cc != '' && digits.start_with?(cc) && digits.length > cc.length
          digits = digits[cc.length..]
        else
          # The number carries its own calling code and it differs from the given one.
          own = calling_code_prefix(digits)
          if own != '' && digits.length > own.length
            cc = own
            digits = digits[own.length..]
          end
        end
      elsif cc != '' && digits.start_with?(cc) && digits.length > 10
        digits = digits[cc.length..]
      end

      if cc == ''
        digits = digits[2..] if digits.length == 12 && digits.start_with?('90')
        cc = '90'
      end

      digits = digits.sub(/\A0+/, '') if digits.length > 1 && digits[0] == '0'

      [digits.dup.force_encoding(Encoding::UTF_8), cc.dup.force_encoding(Encoding::UTF_8)]
    end

    def normalize_host_name(host)
      Php.lower(Php.rtrim(Php.trim(host), '.'))
    end

    def normalize_host_name_list(hosts)
      return [] unless Php.array?(hosts)

      out = []
      Php.values(hosts).each do |host|
        next unless host.is_a?(String)

        host = normalize_host_name(host)
        out << host if host != '' && !out.include?(host)
      end
      out
    end

    TR_KEY_MAP = {
      'TRABISDOMAINCATEGORY' => 'TRABISDOMAINCATEGORY',
      'TRABISCITIZENID' => 'TRABISCITIZENID',
      'TRABISCITIZIENID' => 'TRABISCITIZENID',
      'TRABISTAXOFFICE' => 'TRABISTAXOFFICE',
      'TRABISTAXNUMBER' => 'TRABISTAXNUMBER'
    }.freeze

    def normalize_tr_attributes(attrs)
      return attrs if attrs.empty?

      normalized = {}
      attrs.each do |key, value|
        next unless key.is_a?(String) && TR_KEY_MAP.key?(key)
        next if key == 'TRABISCITIZIENID' && normalized.key?('TRABISCITIZENID')

        normalized[TR_KEY_MAP[key]] = value
      end

      unless normalized['TRABISDOMAINCATEGORY'].nil?
        cat = Php.lower(Php.trim(normalized['TRABISDOMAINCATEGORY']))
        if %w[1 owner personal individual].include?(cat)
          normalized['TRABISDOMAINCATEGORY'] = 'Owner'
        elsif %w[0 corporate company].include?(cat)
          normalized['TRABISDOMAINCATEGORY'] = 'Corporate'
        end
      end
      normalized
    end

    def stringify_attributes(attrs)
      attrs.each_with_object({}) do |(key, value), out|
        out[key.to_s] = case value
                        when true then 'true'
                        when false then 'false'
                        when nil then ''
                        when String, Integer, Float then Php.to_s(value)
                        else Php.json_encode(value)
                        end
      end
    end

    def flatten_validation_errors(errors)
      parts = []
      Php.values(errors).each do |ve|
        if ve.is_a?(String)
          parts << Php.trim(ve) if Php.trim(ve) != ''
          next
        end
        next unless Php.array?(ve)

        message = Php.isset?(ve, 'message') ? Php.trim(Php.to_s(Php.get(ve, 'message'))) : ''
        members = []
        member_list = Php.get(ve, 'members')
        if Php.array?(member_list)
          Php.values(member_list).each do |member|
            label = humanize_validation_member(Php.to_s(member))
            members << label if label != ''
          end
        end

        if !members.empty? && message != ''
          parts << "#{members.join(', ')} - #{message}"
        elsif !members.empty?
          parts << members.join(', ')
        elsif message != ''
          parts << message
        end
      end
      parts.uniq.join(' | ')
    end

    VALIDATION_ROLES = {
      'administrativecontact' => 'Admin', 'administrative' => 'Admin',
      'technicalcontact' => 'Tech', 'technical' => 'Tech',
      'registrantcontact' => 'Registrant', 'registrant' => 'Registrant',
      'billingcontact' => 'Billing', 'billing' => 'Billing'
    }.freeze

    def humanize_validation_member(member)
      member = Php.trim(member)
      return '' if member == ''

      member = Php.ltrim(member, '$.')
      member = member.gsub(/\[\d+\]/, '')
      segments = member.split(%r{[./]+}).reject(&:empty?)
      return '' if segments.empty?

      segments.map { |seg| VALIDATION_ROLES[Php.lower(seg)] || Php.ucfirst(seg) }.join(' ').then { |s| Php.trim(s) }
    end

    # --- dates -----------------------------------------------------------------

    ISO_DATE_RE = /\A\s*(-?\d{4,})-(\d{1,2})-(\d{1,2})(?:[T\s]+(\d{1,2}):(\d{2})(?::(\d{2})(?:[.,](\d+))?)?)?\s*(Z|[+-]\d{2}:?\d{2}|[+-]\d{2})?\s*\z/i.freeze

    # strtotime() for the date shapes the gateway sends; nil when unparseable.
    def parse_api_time(value)
      return nil if value.nil? || value == ''

      str = Php.to_s(value)
      if (m = ISO_DATE_RE.match(str))
        year, month, day = m[1].to_i, m[2].to_i, m[3].to_i
        hour, min, sec = m[4].to_i, m[5].to_i, m[6].to_i
        return nil if month < 1 || month > 12 || day < 1 || day > 31 || hour > 24 || min > 59 || sec > 59

        time = Time.utc(year, month, day, hour, min, sec)
        if m[8] && m[8].upcase != 'Z'
          sign = m[8].start_with?('-') ? -1 : 1
          digits = m[8].delete(':+-')
          offset = (digits[0, 2].to_i * 3600) + (digits[2, 2].to_i * 60)
          time -= sign * offset
        end
        return time
      end
      return nil unless str.match?(/\d/)

      Time.parse(str).utc
    rescue ArgumentError, RangeError
      nil
    end

    def format_api_date(value)
      time = parse_api_time(value)
      time.nil? ? '' : time.strftime('%Y-%m-%dT%H:%M:%S')
    end

    def remaining_days_from_date(value)
      time = parse_api_time(value)
      return 0 if time.nil?

      [0, ((time - Time.now) / 86_400.0).ceil].max
    end

    # --- zone helpers ------------------------------------------------------------

    def unsupported_zone_type(type)
      type = Php.upper(Php.trim(type))
      return 'Record type is required.' if type == ''
      return nil if ZONE_RECORD_TYPES.include?(type)

      "Record type \"#{type}\" is not supported by the DNS zone API. Supported types: #{ZONE_RECORD_TYPES.join(', ')}."
    end

    def relativize_record_name(name, domain_name)
      name = Php.trim(name)
      domain = Php.rtrim(Php.lower(Php.trim(domain_name)), '.')
      return '' if name == '' || name == '@'

      bare = Php.rtrim(name, '.')
      return '' if Php.casecmp_eq?(bare, domain)

      suffix = ".#{domain}"
      if bare.bytesize > suffix.bytesize && Php.casecmp_eq?(bare.b[-suffix.bytesize..], suffix.b)
        return bare.b[0, bare.bytesize - suffix.bytesize].force_encoding(bare.encoding)
      end

      bare
    end

    def qualify_record_name(name, domain_name)
      name = Php.trim(name)
      domain = Php.rtrim(Php.lower(Php.trim(domain_name)), '.')
      apex = "#{domain}."
      return apex if name == '' || name == '@'

      bare = Php.rtrim(name, '.')
      return "#{bare}." if Php.casecmp_eq?(bare, domain) || Php.lower(bare).end_with?(".#{domain}")

      "#{bare}.#{apex}"
    end

    def build_zone_struct(name, type, content, ttl)
      ttl = Php.to_i(ttl)
      ttl = 3600 if ttl < 1
      ttl = 86_400 if ttl > 86_400
      {
        'name' => Php.to_s(name),
        'ttl' => ttl,
        'type' => Php.upper(type),
        'contents' => Php.values(Php.to_array(content)).map { |v| Php.to_s(v) }
      }
    end

    def read_resource_record_set(domain_name, name, type)
      current = get_resource_records(domain_name)
      return current if current['result'] != RESULT_OK

      fqdn = qualify_record_name(name, domain_name)
      type = Php.upper(Php.trim(type))
      contents = []
      ttl = 0
      current['data']['records'].each do |rec|
        next unless Php.casecmp_eq?(rec['Name'], fqdn) && Php.casecmp_eq?(rec['Type'], type)

        contents << Php.to_s(rec['Content']) if Php.to_s(rec['Content']) != ''
        ttl = Php.to_i(rec['TTL'])
      end
      { 'ttl' => ttl, 'contents' => contents }
    end

    def fallback_ttl(set)
      Php.truthy?(set['ttl']) ? set['ttl'] : 3600
    end

    def same_record_value?(type, a, b)
      normalize = lambda do |v|
        v = Php.trim(Php.to_s(v))
        if Php.upper(type) == 'TXT'
          v = v[1...-1] if v.length > 1 && v.start_with?('"') && v.end_with?('"')
          v
        else
          Php.lower(Php.rtrim(v, '.'))
        end
      end
      normalize.call(a) == normalize.call(b)
    end

    def transfer_action(domain_name, action, default_status, fallback)
      response = request('POST', "domains/transfers/#{action}", { 'domainName' => domain_name })
      status = Php.get(response, 'status')
      { 'result' => RESULT_OK, 'data' => { 'DomainName' => domain_name, 'Status' => status.nil? ? default_status : status } }
    rescue ApiError => e
      error_envelope(e, fallback)
    end
  end
end
