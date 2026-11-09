# frozen_string_literal: true

require_relative 'test_helper'

class UtilsTest < Minitest::Test
  include DnaTestSupport

  P = DomainNameApi::Php

  def setup
    @client = new_client(FakeTransport.new)
  end

  def test_is_tr_tld
    assert @client.is_tr_tld('example.com.tr')
    assert @client.is_tr_tld('EXAMPLE.TR')
    assert @client.tr_tld?('a.tr')
    refute @client.is_tr_tld('example.com')
    refute @client.is_tr_tld('tr')
    refute @client.is_tr_tld('example.tr.com')
  end

  def test_validate_contact_fills_defaults
    result = @client.validate_contact({})
    assert_equal 'Isimyok', result['FirstName']
    assert_equal 'Isimyok', result['LastName']
    assert_equal 'ISTANBUL', result['State']
    assert_equal '5555555555', result['Phone']
    assert_equal '90', result['PhoneCountryCode']
    assert_equal '', result['Fax']
  end

  def test_validate_contact_cleans_names_phone_and_country
    result = @client.validate_contact(
      FirstName: ' J0hn  O\'Brien-Smith!! ', LastName: '1234', City: 'Izmir', State: '',
      Country: 'turkey', Phone: '+90 532 374 33 88', PhoneCountryCode: '', Fax: '0212 123 45 67', FaxCountryCode: '',
      EMail: 'kept@example.com'
    )
    assert_equal "Jhn O'Brien-Smith", result['FirstName']
    assert_equal "Jhn O'Brien-Smith", result['LastName']
    assert_equal 'Izmir', result['State']
    assert_equal 'TR', result['Country']
    assert_equal '905323743388', "#{result['PhoneCountryCode']}#{result['Phone']}"
    assert_equal '2121234567', result['Fax']
    assert_equal '90', result['FaxCountryCode']
    assert_equal 'kept@example.com', result['EMail']
  end

  def test_validate_contact_keeps_unicode_letters
    result = @client.validate_contact('FirstName' => "Bünyamin", 'LastName' => "Çelik")
    assert_equal "Bünyamin", result['FirstName']
    assert_equal "Çelik", result['LastName']
  end

  def test_php_empty_and_casts
    [nil, false, 0, 0.0, '', '0', [], {}].each { |v| assert P.empty?(v), v.inspect }
    ['a', '0.0', ' ', 1, [0], { 'a' => nil }, true].each { |v| refute P.empty?(v), v.inspect }
    assert_equal 12, P.to_i('12abc')
    assert_equal 0, P.to_i('abc')
    assert_equal 1000, P.to_i('1e3')
    assert_equal '1', P.to_s(true)
    assert_equal '', P.to_s(false)
    assert_equal '1250.5', P.to_s(1250.5)
    assert_equal '0.3', P.to_s(0.1 + 0.2)
    assert_equal '1.0E+15', P.to_s(1e15)
    assert P.numeric?('1.5')
    refute P.numeric?('1.5x')
  end

  def test_number_format
    assert_equal '11.9900', P.number_format(11.99, 4)
    assert_equal '1.01', P.number_format(1.005, 2)
    assert_equal '0.00', P.number_format(-0.001, 2)
    assert_equal '601.64', P.number_format('601.64', 2)
    assert_equal '-2', P.number_format(-1.5, 0)
  end

  def test_http_build_query
    assert_equal 'a=1&b=0&c%5B0%5D=x&c%5B1%5D%5Bk%5D=y+z', P.http_build_query('a' => true, 'b' => false, 'n' => nil,
                                                                                'c' => ['x', { 'k' => 'y z' }])
  end

  def test_trim_family
    assert_equal 'x', P.trim(" \t\n\r\0\x0Bx\x0B ")
    assert_equal 'administrativeContact.zip', P.ltrim('$.administrativeContact.zip', '$.')
    assert_equal 'ns1.example.com', P.rtrim('ns1.example.com..', '.')
  end

  def test_ipv4
    assert P.ipv4?('192.0.2.1')
    refute P.ipv4?('192.0.2.256')
    refute P.ipv4?('01.2.3.4')
    refute P.ipv4?('2001:db8::1')
  end

  def test_version_constant
    assert_equal '1.0.0', DomainNameApi::VERSION
    assert_equal 'DomainNameAPI-Ruby/1.0.0', DomainNameApi::Rest::USER_AGENT
  end

  def test_client_implements_the_whole_public_api
    %w[
      get_reseller_details get_current_balance check_availability get_list get_tld_list get_details
      sync_from_registry get_contacts save_contacts modify_name_server enable_theft_protection_lock
      disable_theft_protection_lock modify_privacy_protection_status renew register_with_contact_info
      add_child_name_server delete_child_name_server modify_child_name_server transfer cancel_transfer
      approve_transfer reject_transfer check_transfer get_resource_records add_resource_record
      edit_resource_record delete_resource_record apply_resource_records set_resource_record_set
      delete_resource_record_set add_resource_record_value remove_resource_record_value
      replace_resource_record_value get_forwarding set_forwarding delete_forwarding is_tr_tld
      validate_contact get_request_data get_response_data get_response_headers get_parsed_response_data
      get_last_function get_service_url set_service_url set_error_reporting_enabled set_telemetry_minimal
      set_ssl_verification
    ].each { |m| assert_respond_to @client, m }
  end
end
