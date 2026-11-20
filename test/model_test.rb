# frozen_string_literal: true

require_relative 'test_helper'

class ModelTest < Minitest::Test
  include DomainNameApi

  def test_time_parsing
    {
      '2024-03-15T10:20:30' => Time.utc(2024, 3, 15, 10, 20, 30),
      '2024-03-15T10:20:30Z' => Time.utc(2024, 3, 15, 10, 20, 30),
      '2024-03-15T10:20:30.5' => Time.utc(2024, 3, 15, 10, 20, 30.5),
      '2024-03-15T13:20:30+03:00' => Time.utc(2024, 3, 15, 10, 20, 30),
      '2024-03-15T13:20:30+0300' => Time.utc(2024, 3, 15, 10, 20, 30),
      '2024-03-15 10:20:30' => Time.utc(2024, 3, 15, 10, 20, 30),
      '2024-03-15T10:20' => Time.utc(2024, 3, 15, 10, 20),
      '2024-03-15' => Time.utc(2024, 3, 15),
      Date.new(2024, 3, 15) => Time.utc(2024, 3, 15)
    }.each { |input, want| assert_equal want, Util.parse_time(input), input.inspect }
    [nil, '', 'not-a-date', '0001-01-01T00:00:00', '2024-13-45', 42].each do |input|
      assert_nil Util.parse_time(input), input.inspect
    end
    assert_equal '2024-03-15T10:20:30Z', Util.format_time(Time.new(2024, 3, 15, 13, 20, 30, '+03:00'))
  end

  def test_attributes
    assert_equal({ 'a' => 'x', 'n' => '12', 'b' => 'true', 'z' => '' },
                 Util.attributes('a' => 'x', 'n' => 12, 'b' => true, 'z' => nil))
    assert_equal({}, Util.attributes([]))
    assert_equal({}, Util.attributes(nil))
  end

  def test_decode_domain_info
    body = JSON.parse(<<~JSON)
      {"domainName":"example.com","domainNameIdn":"example.com","isIdnName":false,"startDate":"2024-03-15T10:20:30",
       "expirationDate":"2027-03-15T10:20:30","transferDate":null,"updatedDate":"2026-10-01T08:00:00","resellerId":"r1",
       "renewalMode":"Manual","authCode":"Ab1!xyZ9","lockStatus":true,"privacyProtectionStatus":false,"remainingDay":126,
       "statusCode":"clientTransferProhibited","objectId":"123456_DOMAIN_COM-VRSN","rgpStatues":null,"status":"Active",
       "statusReason":null,"isForwarded":false,"useTrusteeContact":false,"id":4321,
       "nameservers":["ns1.example.net","ns2.example.net"],
       "hosts":[{"name":"ns1.example.com","ipAddresses":[{"ipAddress":"192.0.2.10"},{"ipAddress":"192.0.2.11"}]},
                {"name":"ns2.example.com","ipAddresses":[]}],
       "contacts":[{"firstName":"Ada","contactType":"registrant","handle":"DNA-R-1","discloseFlag":false},
                   {"firstName":"Grace","contactType":"ADMINISTRATIVE","handle":"DNA-A-2"}],
       "additionalAttributes":[]}
    JSON
    d = DomainInfo.from_api(body)
    assert d.status.active?
    assert d.locked?
    assert_equal true, d.locked
    refute d.privacy_protection?
    assert_equal 126, d.remaining_days
    assert_equal 'Ab1!xyZ9', d.auth_code
    assert_equal '123456_DOMAIN_COM-VRSN', d.registry_object_id
    assert_equal Time.utc(2027, 3, 15, 10, 20, 30), d.expiration_date
    assert_nil d.transfer_date
    assert_equal %w[ns1.example.net ns2.example.net], d.name_servers
    assert_equal 2, d.hosts.size
    assert_equal '192.0.2.11', d.hosts[0].ip_addresses[1].address
    assert_equal [], d.hosts[1].ip_addresses
    assert_equal 'Grace', d.contact(:admin).first_name
    assert_equal 'DNA-A-2', d.contact('Admin').handle
    assert_equal false, d.contact(:registrant).disclose_flag
    assert_nil d.contact(:billing)
    assert_equal({}, d.additional_attributes)
    assert_equal 4321, d.raw['id']
    assert_raises(ArgumentError) { d.contact(:boss) }

    quirky = DomainInfo.from_api('status' => 4, 'expirationDate' => 'not-a-date', 'startDate' => '0001-01-01T00:00:00',
                                 'remainingDay' => nil, 'additionalAttributes' => nil, 'lockStatus' => 'true',
                                 'nameservers' => nil)
    assert quirky.status.transferred_out?
    assert_nil quirky.expiration_date
    assert_nil quirky.start_date
    assert_nil quirky.remaining_days
    assert quirky.locked?
    assert_equal [], quirky.name_servers
    assert_equal [], quirky.contacts
    assert_nil DomainInfo.from_api(nil)
    assert_nil DomainInfo.from_api([])
  end

  def test_model_basics
    c = Contact.new(first_name: 'Ada', country: 'tr')
    assert_equal 'Ada', c.first_name
    assert_nil c.last_name
    assert_nil c.disclose_flag, 'a nullable boolean stays nil'
    c.disclose_flag = 'true'
    assert_equal true, c.disclose_flag
    assert_equal c, Contact.new(first_name: 'Ada', country: 'tr', disclose_flag: true)
    refute_equal c, Contact.new(first_name: 'Grace')
    assert_includes c.inspect, 'first_name="Ada"'
    assert_equal 'Ada', c.to_h[:first_name]
    assert_equal({ 'period' => 2, 'currency' => 'USD' }, Price.new(period: '2', currency: 'USD').to_api,
                 'to_api uses the JSON names and leaves nil out')
    assert_equal '{"period":2,"currency":"USD"}', Price.new(period: 2, currency: 'USD').to_json
    assert_nil c.raw

    error = assert_raises(ArgumentError) { Contact.new(frist_name: 'Ada') }
    assert_includes error.message, ':frist_name'
    assert_includes error.message, 'first_name'

    assert_same c, Contact.coerce(c)
    assert_equal 'Ada', Contact.coerce(first_name: 'Ada').first_name
    assert_equal 'Ada', Contact.coerce('firstName' => 'Ada').first_name
    assert_equal 'Ada', Contact.coerce('first_name' => 'Ada').first_name
    assert_nil Contact.coerce(nil)
    assert_raises(ArgumentError) { Contact.coerce('Ada') }
  end

  def test_contact_normalisation
    c = Contact.new(first_name: ' Ada ', last_name: 'Lovelace', email: ' ada@example.com ', address: 'a', city: 'c',
                    state: 's', postal_code: ' 34000 ', country: ' tr ', phone_country_code: '+90',
                    phone: '(555) 123-45-67', fax: '', type: :admin, handle: 'DNA-1')
    api = c.to_api
    assert_equal 'Ada', api['firstName']
    assert_equal 'TR', api['country']
    assert_equal '90', api['phoneCountryCode']
    assert_equal '5551234567', api['phone']
    assert_equal '34000', api['postalCode']
    refute api.key?('fax'), 'blank optional fields are left out'
    refute api.key?('companyName')
    refute api.key?('handle')
    refute api.key?('contactType')
    refute api.key?('discloseFlag')
    assert_equal 'Tech', c.to_api(:tech)['contactType']

    v = Validator.new
    Contact.new(email: 'nope', country: 'TUR', phone_country_code: '12345', phone: '1' * 20).validate_into(v, 'c.')
    fields = v.errors.map(&:field)
    %w[c.first_name c.last_name c.address c.city c.state c.postal_code].each { |f| assert_includes fields, f }
    messages = v.errors.map(&:to_s)
    assert_includes messages, 'c.email: is not an e-mail address'
    assert_includes messages, 'c.country: must be a 2-letter ISO code such as TR or US'
    assert_includes messages, 'c.phone_country_code: must be at most 3 digits, e.g. 90'
    assert_includes messages, 'c.phone: must be at most 16 digits'
    assert_empty DnaTest.sample_contact.validate_into(Validator.new).errors
  end

  def test_helpers
    assert Availability.from_api('status' => 'available').available?
    refute Availability.from_api('status' => 'NOTAVAILABLE').available?
    refute Availability.new.available?

    account = Account.from_api('usdBalance' => 12.5, 'tryBalance' => 400)
    assert_equal 12.5, account.balance('usd')
    assert_equal 400.0, account.balance(:try)
    assert_equal 400.0, account.balance('TL')
    assert_nil account.balance('EUR')

    tx = Transaction.from_api('balance' => 88.01, 'oldBalance' => 100, 'amount' => 0)
    assert_equal(-11.99, tx.change)

    tld = TLD.from_api('name' => 'com.tr',
                       'prices' => [{ 'register' => [{ 'period' => 1, 'price' => 12.5, 'currency' => 'USD' }],
                                      'renew' => [{ 'period' => 2, 'price' => 25, 'currency' => 'USD' }] }],
                       'attributes' => [{ 'key' => 'trabis', 'isRequired' => true }, { 'key' => 'x' }])
    assert_equal '12.50 USD', tld.register_price(1).to_s
    assert_nil tld.register_price(2)
    assert_equal 25.0, tld.renew_price(2).price
    assert_nil tld.transfer_price
    assert_equal ['trabis'], tld.required_attributes.map(&:key)

    content = CertificateContent.new(certificate: "CERT\n", intermediate1: 'I1', intermediate2: ' ', root: 'ROOT')
    assert_equal "CERT\nI1\n", content.chain

    st = HostingStatus.from_api('status' => 'active')
    assert st.active?
    refute st.failed?
    assert HostingStatus.from_api('status' => 'Failed').failed?
  end

  def test_fqdn_and_record_set_matching
    assert_equal 'www.example.com.', DomainNameApi.fqdn('example.com', 'www')
    assert_equal 'example.com.', DomainNameApi.fqdn('Example.com.', '')
    assert_equal 'example.com.', DomainNameApi.fqdn('example.com', '@')
    assert_equal 'example.com.', DomainNameApi.fqdn('example.com', 'EXAMPLE.com.')
    assert_equal 'a.b.example.com.', DomainNameApi.fqdn('example.com', 'a.b.example.com')
    assert_equal 'mail.example.com.', DomainNameApi.fqdn('example.com', 'Mail')

    set = RecordSet.from_api('name' => 'www.example.com.', 'type' => 'A', 'ttl' => 600,
                             'records' => [{ 'content' => '192.0.2.1' }, { 'content' => '192.0.2.2', 'disabled' => true }])
    assert_equal %w[192.0.2.1 192.0.2.2], set.values
    assert set.records[1].disabled?
    assert set.matches?('example.com', 'www', :a)
    assert set.matches?('example.com', 'WWW.example.com.', 'a')
    refute set.matches?('example.com', 'www', :aaaa)
    refute set.matches?('example.com', '@', :a)
    refute set.matches?('example.com', 'www', :bogus)
  end

  def test_ds_records
    ds = DS.parse('2371 13 2 1F987CC6583E92DF0890718C42 0A3E')
    assert_equal 2371, ds.key_tag
    assert ds.algorithm.ecdsa_p256_sha256?
    assert ds.digest_type.sha256?
    assert_equal '1F987CC6583E92DF0890718C420A3E', ds.digest
    assert_equal '2371 13 2 1F987CC6583E92DF0890718C420A3E', ds.to_s
    line = DS.parse('example.com. 3600 IN DS 2371 13 2 1f98')
    assert_equal '1F98', line.digest
    assert_equal({ 'keyTag' => 2371, 'algorithm' => 13, 'digestType' => 2, 'digest' => '1F98' }, line.to_api)
    ['', '2371 13 2', 'x 13 2 AB', '2371 99 2 AB', '2371 13 9 AB'].each do |bad|
      assert_raises(ArgumentError, bad) { DS.parse(bad) }
    end
    assert_equal 2371, DS.coerce(key_tag: 2371, algorithm: 13, digest_type: 2, digest: 'AB').key_tag
  end

  def test_pages
    page_class = Page.of(Domain)
    assert_same page_class, Page.of(Domain)
    assert_equal 'DomainNameApi::Page[Domain]', page_class.name
    page = page_class.from_api('items' => [{ 'domainName' => 'a.com' }, { 'domainName' => 'b.com' }], 'totalCount' => 7)
    assert_equal 7, page.total_count
    assert_equal %w[a.com b.com], page.map(&:domain_name)
    assert_equal 2, page.size
    refute page.empty?
    assert_kind_of Domain, page.first
    assert page_class.from_api('items' => nil).empty?
  end
end
