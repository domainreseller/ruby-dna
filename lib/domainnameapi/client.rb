# frozen_string_literal: true

module DomainNameApi
  # Public facade, the Ruby counterpart of php-dna's DomainNameAPI_PHPLibrary.
  #
  #   dna = DomainNameApi::Client.new('xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'your-api-key')
  #   dna.get_details('example.com')
  #   # => { 'data' => { 'DomainName' => 'example.com', ... }, 'result' => 'OK' }
  #
  # Every network method returns php-dna's result structure (Hashes with
  # String keys) and never raises for API or transport errors: failures come
  # back as { 'result' => 'ERROR', 'error' => { 'Code', 'Message', 'Details' } }
  # (get_current_balance uses its own OperationResult envelope).
  class Client
    attr_reader :rest

    # @param reseller_id [String] Reseller ID (UUID) from the panel's API settings
    # @param api_key [String] API key from the panel's API settings
    # @param test_mode [Boolean, String] true (or "true"/"1"/"on"/"yes") for the OTE test gateway
    # @param transport [#call, nil] custom HTTP transport (see NetHttpTransport)
    # @param sentry_dsn [String, nil] override the telemetry DSN ('' disables telemetry)
    # @param zone_min_interval [Numeric, nil] seconds between /domains/zones calls (default 1.0)
    def initialize(reseller_id = '', api_key = '', test_mode = false, transport: nil, sentry_dsn: nil,
                   zone_min_interval: nil)
      reseller_id = Php.trim(reseller_id)
      api_key = Php.trim(api_key)
      test_mode = test_mode.is_a?(String) ? Php.filter_bool(test_mode) : Php.truthy?(test_mode)
      @rest = Rest.new(reseller_id, api_key, test_mode, transport: transport, sentry_dsn: sentry_dsn,
                                                       zone_min_interval: zone_min_interval)
    end

    # Account

    def get_reseller_details
      @rest.get_reseller_details
    end

    def get_current_balance(currency_id = 'USD')
      @rest.get_current_balance(currency_id)
    end

    # Search and lists

    def check_availability(domains, extensions, period, command = 'create')
      @rest.check_availability(domains, extensions, period, command)
    end

    def get_list(extra_parameters = {})
      @rest.get_list(extra_parameters)
    end

    def get_tld_list(count = 20)
      @rest.get_tld_list(count)
    end

    # Domain

    def get_details(domain_name)
      @rest.get_details(domain_name)
    end

    def sync_from_registry(domain_name)
      @rest.sync_from_registry(domain_name)
    end

    def get_contacts(domain_name)
      @rest.get_contacts(domain_name)
    end

    def save_contacts(domain_name, contacts)
      @rest.save_contacts(domain_name, contacts)
    end

    def modify_name_server(domain_name, name_servers)
      @rest.modify_name_server(domain_name, name_servers)
    end

    def enable_theft_protection_lock(domain_name)
      @rest.enable_theft_protection_lock(domain_name)
    end

    def disable_theft_protection_lock(domain_name)
      @rest.disable_theft_protection_lock(domain_name)
    end

    # `status` accepts true/false and 1/"1"/"on"/"true"/"yes"; `reason` is
    # accepted for compatibility and not sent (the gateway has no such field).
    def modify_privacy_protection_status(domain_name, status, reason = 'Owner request')
      @rest.modify_privacy_protection_status(domain_name, status, reason)
    end

    def renew(domain_name, period)
      @rest.renew(domain_name, period)
    end

    def register_with_contact_info(domain_name, period, contacts, name_servers = [], epp_lock = true,
                                   privacy_lock = false, additional_attributes = {})
      @rest.register_with_contact_info(domain_name, period, contacts, name_servers, epp_lock, privacy_lock,
                                       additional_attributes)
    end

    # Child nameservers

    def add_child_name_server(domain_name, name_server, ip_address)
      @rest.add_child_name_server(domain_name, name_server, ip_address)
    end

    def delete_child_name_server(domain_name, name_server)
      @rest.delete_child_name_server(domain_name, name_server)
    end

    def modify_child_name_server(domain_name, name_server, ip_address)
      @rest.modify_child_name_server(domain_name, name_server, ip_address)
    end

    # Transfers

    # Contacts are never sent with a transfer: the registrar handles them,
    # so the request always carries an empty contact list.
    def transfer(domain_name, epp_code, period)
      @rest.transfer(domain_name, epp_code, period)
    end

    def cancel_transfer(domain_name)
      @rest.cancel_transfer(domain_name)
    end

    def approve_transfer(domain_name)
      @rest.approve_transfer(domain_name)
    end

    def reject_transfer(domain_name)
      @rest.reject_transfer(domain_name)
    end

    def check_transfer(domain_name, auth_code)
      @rest.check_transfer(domain_name, auth_code)
    end

    # DNS zone

    def get_resource_records(domain_name)
      @rest.get_resource_records(domain_name)
    end

    def add_resource_record(domain_name, name, type, content, ttl = 3600, apply = true)
      @rest.add_resource_record(domain_name, name, type, content, ttl, apply)
    end

    def edit_resource_record(domain_name, record_name, name, type, content, ttl = 3600, apply = true)
      @rest.edit_resource_record(domain_name, record_name, name, type, content, ttl, apply)
    end

    def delete_resource_record(domain_name, name, record, record_type, apply = true)
      @rest.delete_resource_record(domain_name, name, record, record_type, apply)
    end

    def apply_resource_records(domain_name)
      @rest.apply_resource_records(domain_name)
    end

    def set_resource_record_set(domain_name, name, type, contents, ttl = 3600, apply = true)
      @rest.set_resource_record_set(domain_name, name, type, contents, ttl, apply)
    end

    def delete_resource_record_set(domain_name, name, type, apply = true, known_value = '')
      @rest.delete_resource_record_set(domain_name, name, type, apply, known_value)
    end

    def add_resource_record_value(domain_name, name, type, value, ttl = nil, apply = true)
      @rest.add_resource_record_value(domain_name, name, type, value, ttl, apply)
    end

    def remove_resource_record_value(domain_name, name, type, value, apply = true)
      @rest.remove_resource_record_value(domain_name, name, type, value, apply)
    end

    def replace_resource_record_value(domain_name, name, type, old_value, new_value, ttl = nil, apply = true)
      @rest.replace_resource_record_value(domain_name, name, type, old_value, new_value, ttl, apply)
    end

    # Forwarding

    def get_forwarding(domain_name)
      @rest.get_forwarding(domain_name)
    end

    def set_forwarding(domain_name, redirect_address, forward_type = 'Standard')
      @rest.set_forwarding(domain_name, redirect_address, forward_type)
    end

    def delete_forwarding(domain_name)
      @rest.delete_forwarding(domain_name)
    end

    # Utilities (no network)

    def is_tr_tld(domain)
      @rest.is_tr_tld(domain)
    end
    alias tr_tld? is_tr_tld

    def validate_contact(contact)
      @rest.validate_contact(contact)
    end

    # Diagnostics

    def get_request_data
      @rest.get_request_data
    end

    def set_request_data(request)
      @rest.set_request_data(request)
      self
    end

    def get_response_data
      @rest.get_response_data
    end

    def set_response_data(response)
      @rest.set_response_data(response)
      self
    end

    def get_response_headers
      @rest.get_response_headers
    end

    def set_response_headers(headers)
      @rest.set_response_headers(headers)
      self
    end

    def get_parsed_response_data
      @rest.get_parsed_response_data
    end

    def set_parsed_response_data(response)
      @rest.set_parsed_response_data(response)
      self
    end

    def get_last_function
      @rest.get_last_function
    end

    def set_last_function(function)
      @rest.set_last_function(function)
      self
    end

    def get_service_url
      @rest.get_service_url
    end

    def set_service_url(url)
      @rest.set_service_url(url)
      nil
    end

    # Settings

    def set_error_reporting_enabled(enabled)
      @rest.set_error_reporting_enabled(enabled)
    end

    def set_telemetry_minimal(minimal)
      @rest.set_telemetry_minimal(minimal)
    end

    def set_ssl_verification(enabled)
      @rest.set_ssl_verification(enabled)
    end

    def set_sentry_dsn(dsn)
      @rest.set_sentry_dsn(dsn)
    end

    def set_telemetry_sender(sender)
      @rest.set_telemetry_sender(sender)
    end

    def set_transport(transport)
      @rest.set_transport(transport)
    end

    def set_zone_min_interval(seconds)
      @rest.zone_min_interval = seconds.to_f
      nil
    end
  end
end
