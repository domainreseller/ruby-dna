# frozen_string_literal: true

require_relative 'test_helper'
require 'tmpdir'

class ServicesTest < Minitest::Test
  include DomainNameApi
  include DnaTest

  # --- account ---------------------------------------------------------------

  def test_account
    client, api = fake_client(ok('resellerId' => 'r1', 'resellerName' => 'Example', 'usdBalance' => 12.5,
                                 'tryBalance' => 400))
    account = client.account.get
    assert_equal 'Example', account.reseller_name
    assert_equal 12.5, account.balance('USD')
    assert_equal '/api/v1/deposit/accounts/me', api.path
  end

  def test_account_transactions
    page = { 'items' => [{ 'traceId' => 't1', 'type' => 2, 'status' => 1, 'chargeType' => 1, 'balance' => 88.01,
                           'oldBalance' => 100, 'creationTime' => '2026-01-05T10:00:00' }], 'totalCount' => 1 }
    client, api = fake_client(ok(page))
    res = client.account.transactions(transaction_types: [:renew, 'register'], charge_type: :subtract,
                                      from: Date.new(2026, 1, 1), limit: 20)
    tx = res.first
    assert tx.type.renew?
    assert tx.status.success?
    assert tx.charge_type.subtract?
    assert_equal(-11.99, tx.change)
    q = api.query_hash
    assert_equal %w[2 1], q['TransactionTypes']
    assert_equal ['1'], q['ChargeType']
    assert_equal ['2026-01-01T00:00:00Z'], q['StartDate']
    assert_equal ['20'], q['MaxResultCount']

    client, api = fake_client(ok(page))
    client.account.transactions(charge_type: :add)
    assert_equal ['0'], api.query_hash['ChargeType'], 'charge type 0 (credit) is sent'

    e = assert_raises(InputError) { client.account.transactions(from: '2026-02-01', to: '2026-01-01') }
    assert_equal ['to: must not be before from'], e.fields.map(&:to_s)
    assert_raises(InputError) { client.account.transactions(transaction_types: [:gift]) }

    client, api = fake_client(ok('items' => [{ 'traceId' => 'a' }, { 'traceId' => 'b' }], 'totalCount' => 3),
                              ok('items' => [{ 'traceId' => 'c' }], 'totalCount' => 3))
    ids = []
    client.account.all_transactions(limit: 2) { |t| ids << t.trace_id }
    assert_equal %w[a b c], ids
    assert_equal [%w[2], %w[2]], api.requests.map { |r| api.query_hash(r)['MaxResultCount'] }
    assert_equal [nil, %w[2]], api.requests.map { |r| api.query_hash(r)['SkipCount'] }
  end

  # --- contacts --------------------------------------------------------------

  def test_contacts_create
    client, api = fake_client(ok('handle' => 'DNA-9', 'isSuccess' => true, 'operationMessage' => 'ok'))
    contact = sample_contact
    contact.phone = '+90 (555) 123-45-67'
    assert_equal 'DNA-9', client.contacts.create(contact)
    sent = api.json['contact']
    assert_equal '905551234567', sent['phone']
    assert_equal 'ada@example.com', sent['eMail']
    refute sent.key?('handle')

    client, = fake_client(ok('handle' => '', 'isSuccess' => false, 'operationMessage' => 'Invalid e-mail'))
    e = assert_raises(OperationError) { client.contacts.create(sample_contact) }
    assert_equal 'Invalid e-mail', e.api_message

    client, api = fake_client(ok('handle' => 'DNA-10', 'isSuccess' => true))
    client.contacts.create(sample_contact.to_h)
    assert_equal 'Ada', api.json['contact']['firstName'], 'a Hash of contact fields works too'

    e = assert_raises(InputError) { client.contacts.create(Contact.new(first_name: 'Ada')) }
    assert_includes e.fields.map(&:field), 'contact.last_name'
  end

  def test_contacts_other
    details = { 'contact' => { 'firstName' => 'Ada', 'handle' => 'DNA-1' },
                'verificationObjects' => [{ 'fieldValue' => 'ada@example.com', 'isUserVerified' => true }] }
    client, api = fake_client(ok(details))
    d = client.contacts.get('DNA 1')
    assert_equal 'Ada', d.contact.first_name
    assert d.verifications.first.verified?
    assert_equal '/api/v1/contacts/DNA%201', api.path

    client, api = fake_client(ok('handle' => 'DNA-1', 'contactUpdateSuccess' => true,
                                 'stats' => { 'totalDomainCount' => 2, 'splitCount' => 1 },
                                 'affectedDomains' => [{ 'domainName' => 'example.com', 'newHandle' => 'DNA-2' }]))
    res = client.contacts.update('DNA-1', sample_contact)
    assert_equal 2, res.stats.total_domain_count
    assert_equal 'DNA-2', res.affected_domains.first.new_handle
    assert_equal 'PUT', api.last.http_method

    client, = fake_client(ok('contactUpdateSuccess' => false))
    assert_raises(OperationError) { client.contacts.update('DNA-1', sample_contact) }

    client, api = fake_client(ok('results' => [{ 'fieldType' => 'Email', 'isUserVerified' => false }]))
    assert_equal 'Email', client.contacts.verification('DNA-1').first.field_type
    assert_equal [%w[HandleCode DNA-1]], api.query

    client, api = fake_client(ok)
    assert_equal true, client.contacts.resend_verification('DNA-1')
    assert_equal({ 'handleCode' => 'DNA-1' }, api.json)
    client, = fake_client(api_error(400, ErrorCode::VERIFICATION_ALREADY_DONE, 'already verified'))
    assert_equal false, client.contacts.resend_verification('DNA-1')
    client, = fake_client(api_error(400, 'Other', 'x'))
    assert_raises(APIError) { client.contacts.resend_verification('DNA-1') }
  end

  # --- domains ---------------------------------------------------------------

  def test_domain_search
    client, api = fake_client(ok('success' => true,
                                 'info' => { 'domainName' => 'example.com', 'status' => 'AVAILABLE', 'price' => 11.99,
                                             'currency' => 'TRY', 'isPremium' => false }), currency: 'try')
    a = client.domains.search('example.com')
    assert a.available?
    assert_equal 11.99, a.price
    refute a.premium?
    assert_equal({ 'domainName' => 'example.com', 'currency' => 'TRY' }, api.json)
    client.domains.search('example.com', currency: 'USD')
    assert_equal 'USD', api.json['currency']

    client, = fake_client(ok('success' => false, 'reason' => 'Invalid TLD', 'code' => 'TLD'))
    e = assert_raises(OperationError) { client.domains.search('example.invalid') }
    assert_equal 'Invalid TLD', e.api_message
    assert_equal 'TLD', e.code
  end

  def test_domain_bulk_search_splits_long_lists
    names = (1..65).map { |i| "example#{i}.com" }
    infos = ->(n) { ok('success' => true, 'infos' => Array.new(n) { |i| { 'domainName' => "d#{i}", 'status' => 'AVAILABLE' } }) }
    client, api = fake_client(infos.call(30), infos.call(30), infos.call(5))
    results = client.domains.bulk_search(*names)
    assert_equal 65, results.size
    assert_equal [30, 30, 5], api.requests.map { |r| api.json(r).size }
    assert_equal({ 'domainName' => 'example1.com' }, api.json(api.requests.first).first)

    assert_raises(InputError) { client.domains.bulk_search(' ') }
    client, = fake_client(ok('success' => false, 'infos' => [], 'operationMessage' => 'failed'))
    assert_raises(OperationError) { client.domains.bulk_search('example.com') }
    assert_raises(InputError) { client.call(DomainBulkSearchRequest.new(domain_names: names)) }
  end

  def test_domain_list_and_all
    client, api = fake_client(ok('items' => [{ 'domainName' => 'a.com', 'status' => 0 }], 'totalCount' => 1))
    page = client.domains.list(statuses: %i[active pending_delete], domain_name: 'a', limit: 10, sort: 'expirationDate')
    assert_equal 1, page.total_count
    assert page.first.status.active?
    assert_equal [%w[DomainName a], %w[StatusIds 0,7], %w[MaxResultCount 10], %w[Sorting expirationDate]], api.query
    client.domains.list(DomainListRequest.new(skip: 5))
    assert_equal [%w[SkipCount 5]], api.query
    assert_raises(ArgumentError) { client.domains.list(DomainListRequest.new, skip: 1) }
    assert_raises(InputError) { client.domains.list(statuses: [:sleeping]) }

    client, api = fake_client(ok('items' => [{ 'domainName' => 'a.com' }, { 'domainName' => 'b.com' }],
                                 'totalCount' => 0),
                              ok('items' => [{ 'domainName' => 'c.com' }], 'totalCount' => 0))
    assert_equal %w[a.com b.com c.com], client.domains.all(limit: 2).map(&:domain_name)
    assert_equal 2, api.requests.size

    client, api = fake_client(ok('items' => Array.new(100) { |i| { 'domainName' => "d#{i}.com" } }, 'totalCount' => 500))
    assert_equal 3, client.domains.all.first(3).size
    assert_equal 1, api.requests.size, 'the enumerator fetches lazily'
  end

  def test_domain_all_stops_on_error
    client, = fake_client(ok('items' => [{ 'domainName' => 'a.com' }], 'totalCount' => 5), api_error(500, 'X', 'boom'))
    seen = []
    assert_raises(APIError) { client.domains.all(limit: 1).each { |d| seen << d.domain_name } }
    assert_equal ['a.com'], seen
  end

  def test_domain_register
    client, api = fake_client(ok('success' => true, 'domainId' => 'd1', 'status' => 'Active',
                                 'expirationDate' => '2027-01-01T00:00:00'))
    res = client.domains.register(domain_name: 'example.com', years: 2,
                                  name_servers: [' NS1.example.net ', 'ns2.example.net'], handles: 'DNA-1',
                                  tld_attributes: { 'trabis' => 1 })
    assert_equal 'd1', res.domain_id
    assert_equal Time.utc(2027, 1, 1), res.expiration_date
    body = api.json
    assert_equal 2, body['period']
    assert_equal ['NS1.example.net', 'ns2.example.net'], body['nameServers']
    assert_equal %w[Registrant Admin Tech Billing], body['handles'].map { |h| h['contactType'] }
    assert_equal({ 'trabis' => '1' }, body['tldAttributes'])

    client.domains.register(DomainRegisterRequest.new(domain_name: 'example.com', name_servers: ['ns1.example.net'],
                                                      handles: ContactHandles.new(registrant: 'R', admin: 'A',
                                                                                  tech: 'T', billing: 'B')))
    refute api.json.key?('period'), 'years left out lets the API use 1'

    e = assert_raises(InputError) do
      client.domains.register(domain_name: 'example.com', name_servers: [], handles: { registrant: 'R' }, years: 11)
    end
    assert_equal %w[years name_servers handles], e.fields.map(&:field)

    client, = fake_client(ok('success' => false, 'message' => 'Domain is not available'))
    e = assert_raises(OperationError) do
      client.domains.register(domain_name: 'example.com', name_servers: ['ns1.example.net'], handles: 'DNA-1')
    end
    assert_equal 'Domain is not available', e.api_message
    assert_equal :rejected, e.kind
  end

  def test_domain_register_with_contacts
    client, api = fake_client(ok('success' => true, 'domainId' => 'd1'))
    client.domains.register_with_contacts(domain_name: 'example.com', name_servers: ['ns1.example.net'],
                                          contacts: sample_contact)
    contacts = api.json['contacts']
    assert_equal %w[Registrant Admin Tech Billing], contacts.map { |c| c['contactType'] }
    assert_equal 'Ada', contacts.last['firstName']
    refute api.json.key?('useTrusteeContact')

    billing = sample_contact
    billing.first_name = 'Grace'
    client.domains.register_with_contacts(
      domain_name: 'example.com', name_servers: ['ns1.example.net'],
      contacts: { registrant: sample_contact, admin: sample_contact, tech: sample_contact, billing: billing }
    )
    assert_equal 'Grace', api.json['contacts'].last['firstName']

    client.domains.register_with_contacts(domain_name: 'example.tr', name_servers: ['ns1.example.net'],
                                          use_trustee_contact: true)
    assert_equal true, api.json['useTrusteeContact']
    refute api.json.key?('contacts')

    e = assert_raises(InputError) do
      client.domains.register_with_contacts(domain_name: 'example.com', name_servers: ['ns1.example.net'],
                                            contacts: { registrant: sample_contact })
    end
    assert_equal %w[contacts.admin contacts.tech contacts.billing], e.fields.map(&:field)
  end

  def test_domain_renew_and_balance
    client, api = fake_client(ok('success' => true, 'status' => 'Active'))
    assert_equal 'Active', client.domains.renew('example.com', years: 1).status
    assert_equal({ 'domainName' => 'example.com', 'period' => 1 }, api.json)
    assert_raises(InputError) { client.domains.renew('example.com', years: 11) }

    client, = fake_client(api_error(402, 'Dna.DomainService:Deposit:10001', 'Insufficient balance',
                                    data: { 'usdBalance' => 1.5 }))
    e = assert_raises(APIError) { client.domains.renew('example.com', years: 1) }
    assert e.insufficient_balance?
    assert_equal 1.5, e.data['usdBalance']

    client, api = fake_client(ok('renewabilityStatus' => true, 'isPremium' => true, 'premiumPrice' => 99.9))
    check = client.domains.renew_check('example.com', years: 2)
    assert check.renewable?
    assert_equal 99.9, check.premium_price
    assert_equal '/api/v1/domains/renew/check', api.path

    client, api = fake_client(ok)
    assert_nil client.domains.restore('example.com')
    assert_equal '/api/v1/domains/restore', api.path
  end

  def test_domain_transfer
    client, api = fake_client(ok('success' => true, 'status' => 'WaitingForIncomingTransfer'))
    client.domains.transfer('example.com', auth_code: ' Xy7!kP2q ', years: 1)
    assert_equal({ 'domainName' => 'example.com', 'period' => 1, 'authCode' => ' Xy7!kP2q ' }, api.json,
                 'the auth code is sent as given')

    client, api = fake_client(ok('transferAvailabilityStatus' => true, 'authCodeIsValid' => true,
                                 'domainStatuses' => ['ok']))
    tc = client.domains.transfer_check('example.com', 'abc')
    assert tc.transferable?
    assert tc.auth_code_valid?
    assert_equal ['ok'], tc.domain_statuses
    assert_raises(InputError) { client.domains.transfer_check('example.com', '') }

    client, api = fake_client(ok('domainName' => 'example.com', 'status' => 'pending'))
    assert_equal 'pending', client.domains.transfer_status('example.com').status
    assert_equal '/api/v1/domains/transfers/query', api.path
  end

  def test_domain_settings
    client, api = fake_client(ok)
    client.domains.lock('example.com')
    assert_equal '/api/v1/domains/lock', api.path
    client.domains.unlock('example.com')
    assert_equal '/api/v1/domains/unlock', api.path
    client.domains.set_privacy('example.com', true)
    assert_equal({ 'domainName' => 'example.com', 'privacyStatus' => true }, api.json)
    client.domains.set_privacy('example.com', false)
    assert_equal false, api.json['privacyStatus']

    client.domains.set_name_servers('example.com', [' NS1.Example.NET', 'ns2.example.net', ''])
    assert_equal({ 'domainName' => 'example.com', 'nameServers' => %w[ns1.example.net ns2.example.net],
                   'dnssecMode' => 0 }, api.json)
    client.domains.set_name_servers('example.com', ['ns1.example.net'], dnssec_mode: :disable)
    assert_equal 2, api.json['dnssecMode']
    assert_raises(InputError) { client.domains.set_name_servers('example.com', ['ns1'], dnssec_mode: :maybe) }
    assert_raises(InputError) { client.domains.set_name_servers('example.com', []) }

    client.domains.add_host('example.com', 'ns1.example.com', '192.0.2.10', '2001:db8::10')
    assert_equal [{ 'ipAddress' => '192.0.2.10', 'ipVersion' => 'v4' },
                  { 'ipAddress' => '2001:db8::10', 'ipVersion' => 'v6' }], api.json['ipAddresses']
    e = assert_raises(InputError) { client.domains.add_host('example.com', 'ns1.example.com', '300.1.1.1') }
    assert_equal ['ip_addresses: 300.1.1.1 is not an IP address'], e.fields.map(&:to_s)
    assert_raises(InputError) { client.domains.add_host('example.com', 'ns1.example.com') }

    client.domains.update_host('example.com', 'ns1.example.com', ip_addresses: '192.0.2.20',
                                                                  new_host_name: 'ns3.example.com')
    assert_equal 'ns3.example.com', api.json['newHostName']
    assert_equal 'PUT', api.last.http_method
    client.domains.update_host('example.com', 'ns1.example.com', ip_addresses: ['192.0.2.20'])
    refute api.json.key?('newHostName')

    client.domains.delete_host('example.com', 'ns1.example.com')
    assert_equal [%w[DomainName example.com], %w[HostName ns1.example.com]], api.query
    assert_equal 'DELETE', api.last.http_method

    client, = fake_client(ok('domainName' => 'example.com', 'authCode' => 'New!Code'))
    assert_equal 'New!Code', client.domains.update_auth_code('example.com')

    client, = fake_client(api_error(400, ErrorCode::PRIVACY_NOT_SUPPORTED, 'no privacy'))
    e = assert_raises(APIError) { client.domains.set_privacy('example.tr', true) }
    assert e.code?(ErrorCode::PRIVACY_NOT_SUPPORTED)
  end

  def test_domain_contacts
    client, api = fake_client(ok)
    client.domains.set_contact_handles('example.com', admin: 'DNA-2', tech: 'DNA-2')
    assert_equal [{ 'contactType' => 'Admin', 'handle' => 'DNA-2' }, { 'contactType' => 'Tech', 'handle' => 'DNA-2' }],
                 api.json['handleItems']
    client.domains.set_contact_handles('example.com', 'DNA-3')
    assert_equal 4, api.json['handleItems'].size
    assert_raises(InputError) { client.domains.set_contact_handles('example.com') }

    client.domains.update_contacts('example.com', billing: sample_contact)
    assert_equal ['Billing'], api.json['contacts'].map { |c| c['contactType'] }
    assert_equal '/api/v1/domains/contacts/update', api.path
    client.domains.update_contacts('example.com', DomainContacts.same(sample_contact))
    assert_equal 4, api.json['contacts'].size
    e = assert_raises(InputError) { client.domains.update_contacts('example.com') }
    assert_equal ['contacts: needs at least one contact'], e.fields.map(&:to_s)
  end

  def test_domain_documents
    Dir.mktmpdir do |dir|
      path = File.join(dir, 'id.pdf')
      File.binwrite(path, "%PDF-1.4\x00\xff")
      doc = DocumentUpload.from_file(:identity_card, path)
      assert_equal 'id.pdf', doc.file_name
      assert doc.type.identity_card?
      assert_includes doc.inspect, 'size=10'
      assert_raises(Errno::ENOENT) { DocumentUpload.from_file(:identity_card, "#{path}.missing") }

      client, api = fake_client(ok('uploaded' => [{ 'name' => 'id.pdf', 'size' => 10, 'type' => 1 }],
                                   'duplicates' => [], 'failed' => [], 'totalDocumentCount' => 1))
      res = client.domains.upload_documents('example.com.tr', doc)
      assert res.uploaded.first.type.identity_card?
      sent = api.json['documents'].first
      assert_equal 1, sent['documentType']
      assert_equal "%PDF-1.4\x00\xff".b, sent['fileContent'].unpack1('m0')
    end

    client, = fake_client(ok)
    e = assert_raises(InputError) do
      client.domains.upload_documents('example.com.tr',
                                      DocumentUpload.new(type: 77, file_name: 'id.exe', content: ''),
                                      { type: :passport, file_name: 'p.pdf', content: 'x' * (11 * 1024 * 1024) })
    end
    assert_equal ['documents[0].type', 'documents[0].file_name', 'documents[0].content', 'documents[1].content'],
                 e.fields.map(&:field)
    assert_raises(InputError) { client.domains.upload_documents('example.com.tr') }

    client, api = fake_client(ok('items' => [{ 'name' => 'id.pdf', 'type' => 1, 'status' => 3 }], 'totalCount' => 1))
    page = client.domains.documents('example.com.tr', types: [:identity_card, :passport])
    assert page.first.status.approved?
    assert_equal [%w[DomainName example.com.tr], %w[DocumentTypes 1,2]], api.query
  end

  def test_domain_forwarding
    client, api = fake_client(ok('redirectAlias' => 'https://www.example.org', 'redirectType' => 'Frame'))
    f = client.domains.forwarding('example.com')
    assert_equal 'https://www.example.org', f.url
    assert f.type.frame?
    assert_equal [%w[domainName example.com]], api.query

    client, = fake_client(api_error(404, ErrorCode::FORWARDING_NOT_FOUND, 'Redirect information not found'))
    assert_nil client.domains.forwarding('example.com')
    client, = fake_client(ok('redirectAlias' => ''))
    assert_nil client.domains.forwarding('example.com')
    client, = fake_client(api_error(404, ErrorCode::DOMAIN_NOT_FOUND, 'not found'))
    assert_raises(APIError) { client.domains.forwarding('example.com') }

    client, api = fake_client(ok)
    client.domains.set_forwarding('example.com', 'https://www.example.org')
    assert_equal({ 'domainName' => 'example.com', 'redirectAddress' => 'https://www.example.org',
                   'forwardType' => 'Standard' }, api.json)
    client.domains.set_forwarding('example.com', 'http://www.example.org', type: :frame)
    assert_equal 'Frame', api.json['forwardType']
    assert_raises(InputError) { client.domains.set_forwarding('example.com', 'www.example.org') }
    assert_raises(InputError) { client.domains.set_forwarding('example.com', 'https://x.org', type: :popup) }

    assert_equal true, client.domains.delete_forwarding('example.com')
    assert_equal 'DELETE', api.last.http_method
    client, = fake_client(api_error(404, ErrorCode::FORWARDING_NOT_FOUND, 'Redirect information not found'))
    assert_equal false, client.domains.delete_forwarding('example.com')
  end

  # --- dns -------------------------------------------------------------------

  def test_dns
    sets = [{ 'name' => 'www.example.com.', 'type' => 'A', 'ttl' => 600, 'records' => [{ 'content' => '192.0.2.1' }] }]
    client, api = fake_client(ok(sets))
    list = client.dns.list('example.com')
    assert_equal ['192.0.2.1'], list.first.values
    assert list.first.type.a?
    assert_equal [%w[domainName example.com]], api.query

    client, api = fake_client(ok)
    client.dns.add('example.com', name: '@', type: 'txt', values: 'v=spf1 -all')
    assert_equal({ 'zoneStruct' => { 'name' => '', 'type' => 'TXT', 'ttl' => 3600, 'contents' => ['v=spf1 -all'] } },
                 api.json)
    client.dns.add('example.com', name: 'www', type: :a, values: ['192.0.2.1', '192.0.2.2'], ttl: 600)
    assert_equal 600, api.json['zoneStruct']['ttl']

    client.dns.update('example.com', record_name: 'www', type: :a, values: ['192.0.2.3'])
    assert_equal [%w[domainName example.com], %w[recordName www]], api.query
    assert_equal 'www', api.json['zoneStruct']['name']
    client.dns.update('example.com', record_name: 'www', name: 'web', type: :a, values: ['192.0.2.3'])
    assert_equal 'web', api.json['zoneStruct']['name']

    client.dns.delete('example.com', name: '@', type: :mx, value: '10 mail.example.com')
    assert_equal [%w[domainName example.com], %w[RecordType MX], ['Record', '10 mail.example.com'], ['Name', '']],
                 api.query

    client, = fake_client(ok('nameServersChanged' => true, 'currentNameServers' => ['ns1.dna.example']))
    res = client.dns.apply('example.com')
    assert res.name_servers_changed?
    assert_equal ['ns1.dna.example'], res.current_name_servers
  end

  def test_dns_validation
    client, api = fake_client(ok)
    {
      { name: '@', type: :cname, values: 'target.example.net' } => 'name: a CNAME cannot be at the apex; use an ALIAS record',
      { name: 'www', type: :cname, values: '192.0.2.1' } => 'values: a CNAME points to a host name, not an IP address (192.0.2.1)',
      { name: '@', type: :mx, values: 'mail.example.com' } => 'values: an MX value is "PRIORITY HOST", e.g. "10 mail.example.com" (mail.example.com)',
      { name: '@', type: :caa, values: 'issue letsencrypt.org' } => %(values: a CAA value has 3 parts, e.g. '0 issue "letsencrypt.org"' (issue letsencrypt.org)),
      { name: 'www', type: :a, values: '2001:db8::1' } => 'values: 2001:db8::1 is not an IPv4 address',
      { name: 'www', type: :aaaa, values: '192.0.2.1' } => 'values: 192.0.2.1 is not an IPv6 address',
      { name: 'www', type: :a, values: [] } => 'values: needs at least one value',
      { name: '@www', type: :a, values: '192.0.2.1' } => 'name: must not start with @ (use "@" alone for the apex)',
      { name: 'www', type: :a, values: '192.0.2.1', ttl: 100_000 } => 'ttl: must be between 1 and 86400',
      { name: 'www', type: :bogus, values: 'x' } => 'type: :bogus is not a DNS record type the zone API supports',
      { name: 'www', type: nil, values: 'x' } => 'type: is required'
    }.each do |args, message|
      e = assert_raises(InputError, args.inspect) { client.dns.add('example.com', **args) }
      assert_includes e.fields.map(&:to_s), message, args.inspect
    end
    client.dns.add('example.com', name: 'example.com.', type: :alias, values: 'target.example.net')
    assert_equal 1, api.requests.size, 'an ALIAS at the apex is fine'
    assert_raises(InputError) { client.dns.delete('example.com', name: 'www', type: :a, value: ' ') }
    assert_raises(InputError) { client.dns.update('example.com', record_name: '', type: :a, values: '192.0.2.1') }
  end

  # --- dnssec ----------------------------------------------------------------

  def test_dnssec
    info = { 'domainName' => 'example.com', 'isDnssecAvailable' => true, 'status' => 2,
             'dsRecords' => [{ 'keyTag' => 2371, 'algorithm' => 13, 'digestType' => 2, 'digest' => 'AB', 'status' => 1 }],
             'allowedAlgorithms' => [8, 13], 'allowedDigestTypes' => [2] }
    client, = fake_client(ok(info))
    i = client.dnssec.get('example.com')
    assert i.available?
    assert i.status.signed?
    assert i.ds_records.first.status.active?
    assert_equal [DNSSECAlgorithm::RSA_SHA256, DNSSECAlgorithm::ECDSA_P256_SHA256], i.allowed_algorithms

    client, api = fake_client(ok('items' => [{ 'keyTag' => 2371, 'isSuccess' => false, 'isPending' => true }]))
    results = client.dnssec.add('example.com', '2371 13 2 1f98 0a', DS.new(key_tag: 1, algorithm: :ed25519,
                                                                          digest_type: :sha256, digest: 'ab cd'))
    assert results.first.pending?
    assert_equal [{ 'keyTag' => 2371, 'algorithm' => 13, 'digestType' => 2, 'digest' => '1F980A' },
                  { 'keyTag' => 1, 'algorithm' => 15, 'digestType' => 2, 'digest' => 'ABCD' }], api.json['records']
    e = assert_raises(InputError) { client.dnssec.add('example.com', DS.new(key_tag: 70_000, digest: '')) }
    assert_equal %w[records[0].key_tag records[0].algorithm records[0].digest_type records[0].digest],
                 e.fields.map(&:field)
    e = assert_raises(InputError) { client.dnssec.add('example.com', 'not a ds') }
    assert_includes e.message, 'is not a DS record'

    client, api = fake_client(ok('keyTag' => 2371, 'isSuccess' => true))
    client.dnssec.remove('example.com', '2371 13 2 1F98')
    assert_equal [%w[DomainName example.com], %w[KeyTag 2371], %w[Algorithm 13], %w[DigestType 2], %w[Digest 1F98]],
                 api.query

    client, = fake_client(ok('isSuccess' => false, 'isPending' => false, 'resultMessage' => 'registry refused'))
    e = assert_raises(OperationError) { client.dnssec.disable('example.com') }
    assert_equal 'registry refused', e.api_message
  end

  # --- ssl -------------------------------------------------------------------

  def test_ssl
    client, api = fake_client(ok('csr' => 'CSR', 'privateKey' => 'KEY'))
    csr = client.ssl.generate_csr(domain_name: 'example.com', country: 'tr', state: 'Istanbul', locality: 'Istanbul',
                                  organization: 'Example Ltd', organization_unit: 'IT')
    assert_equal 'KEY', csr.private_key
    assert_equal 'TR', api.json['country']
    refute api.json.key?('alternativeNames')
    assert_raises(InputError) { client.ssl.generate_csr(domain_name: 'example.com', country: 'TUR') }

    client, api = fake_client(ok('success' => true, 'certificateId' => 'c1'))
    assert_equal 'c1', client.ssl.purchase('example.com', package_code: 'PositiveSSL').certificate_id
    assert_equal({ 'domainName' => 'example.com', 'packageCode' => 'PositiveSSL' }, api.json)

    client.ssl.configure(domain_name: 'example.com', csr: 'CSR', approver_mail: 'admin@example.com',
                         authentication_type: :email, web_server_type: :iis, san_list: %w[a.example.com b.example.com],
                         contact: sample_ssl_contact.to_h)
    body = api.json
    assert_equal 'Email', body['authenticationType']
    assert_equal 'IIS', body['webServerType']
    assert_equal 'a.example.com,b.example.com', body['sanList']
    refute body.key?('wildcardList')
    assert_equal 'Ada', body['contact']['firstName']
    e = assert_raises(InputError) do
      client.ssl.configure(domain_name: 'example.com', csr: 'CSR', approver_mail: 'nope', authentication_type: :fax,
                           contact: { first_name: 'Ada' })
    end
    assert_includes e.fields.map(&:field), 'approver_mail'
    assert_includes e.fields.map(&:field), 'authentication_type'
    assert_includes e.fields.map(&:field), 'contact.company_name'

    client, = fake_client(ok('success' => false, 'message' => 'CSR mismatch'))
    assert_raises(OperationError) { client.ssl.reissue('example.com', csr: 'CSR') }

    client, api = fake_client(ok('domainName' => 'example.com', 'status' => 'Issued', 'isIssued' => true,
                                 'certificateExpiresAt' => '2027-05-01T00:00:00'))
    st = client.ssl.status('example.com')
    assert st.issued?
    assert_equal Time.utc(2027, 5, 1), st.expires_at
    assert_equal 'PUT', api.last.http_method

    client, = fake_client(ok('certificate' => { 'issuedAt' => '2026-05-01T00:00:00' },
                             'subscription' => { 'expiresAt' => '2027-05-01T00:00:00' },
                             'configuration' => { 'approverMail' => 'admin@example.com' },
                             'contacts' => [{ 'firstName' => 'Ada', 'type' => 'Admin' }]))
    cert = client.ssl.get('example.com')
    assert_equal Time.utc(2026, 5, 1), cert.certificate.issued_at
    assert_equal 'admin@example.com', cert.configuration.approver_mail
    assert_equal 'Admin', cert.contacts.first.type

    client, = fake_client(ok('certificate' => 'C', 'intermediateCertificate1' => 'I'))
    assert_equal "C\nI\n", client.ssl.content('example.com').chain

    client, api = fake_client(ok('mails' => ['admin@example.com']))
    assert_equal ['admin@example.com'], client.ssl.approvers('example.com', package_code: 'PositiveSSL')
    assert_equal [%w[DomainName example.com], %w[PackageCode PositiveSSL]], api.query

    client, = fake_client(ok('success' => true))
    assert client.ssl.revoke('example.com').success?
  end

  # --- hosting ---------------------------------------------------------------

  def stub_pause(service, log)
    service.define_singleton_method(:pause) { |seconds| log << seconds }
  end

  def test_hosting_wait
    client, api = fake_client(ok('status' => 'Provisioning'), ok('status' => 'Provisioning'),
                              ok('status' => 'Active', 'panelAddress' => 'https://panel', 'username' => 'u'))
    pauses = []
    stub_pause(client.hosting, pauses)
    st = client.hosting.wait('HST-1')
    assert st.active?
    assert_equal 'https://panel', st.panel_address
    assert_equal [5, 5], pauses
    assert_equal [%w[ServiceId HST-1]], api.query

    client, = fake_client(ok('status' => 'Provisioning'), ok('status' => 'Failed', 'failureReason' => 'no capacity'))
    stub_pause(client.hosting, [])
    e = assert_raises(OperationError) { client.hosting.wait('HST-1') }
    assert_equal 'no capacity', e.api_message
    assert_equal 'Failed', e.code

    client, = fake_client(ok('status' => 'Provisioning'))
    stub_pause(client.hosting, [])
    e = assert_raises(WaitTimeoutError) { client.hosting.wait('HST-1', timeout: 0) }
    assert e.timeout?
    refute e.outcome_unknown?
    assert_equal 'Provisioning', e.last.status
  end

  def test_hosting_lookups
    client, api = fake_client(ok([{ 'name' => 'Linux', 'servicePlans' => [{ 'servicePlan' => 'Linux-Starter' }] }]))
    assert_equal 'Linux-Starter', client.hosting.packages.first.service_plans.first.service_plan

    client, api = fake_client(ok([{ 'name' => 'Starter', 'diskQuotaMb' => nil, 'maxDomains' => 5 }]))
    plan = client.hosting.plans(hosting_id: 'h1').first
    assert_nil plan.disk_quota_mb, 'nil means unlimited'
    assert_equal 5, plan.max_domains
    assert_equal [%w[hostingId h1]], api.query

    client, api = fake_client(ok('serviceId' => 'HST-1', 'status' => 'Provisioning'))
    assert_equal 'HST-1', client.hosting.create('example.com', service_plan: 'Linux-Starter').service_id

    client, api = fake_client(ok('serviceId' => 'HST-1', 'expiredOn' => '2027-01-01T00:00:00'))
    assert_equal Time.utc(2027, 1, 1), client.hosting.get(domain_name: 'example.com').expires_on
    assert_equal [%w[domainName example.com]], api.query
    assert_raises(InputError) { client.hosting.get }
    assert_raises(InputError) { client.hosting.status(service_id: 'HST-1', domain_name: 'example.com') }
    client.hosting.get_by_token('tok')
    assert_equal [%w[token tok]], api.query
  end

  # --- orders and products -----------------------------------------------------

  def test_orders_and_products
    client, api = fake_client(ok('orderCode' => 'ORD 1', 'status' => 1,
                                 'products' => [{ 'orderType' => 2, 'productType' => 1, 'status' => 1 }]))
    order = client.orders.get('ORD 1')
    assert order.status.active?
    assert order.products.first.order_type.renew?
    assert_equal '/api/v1/order/ORD%201', api.path

    client, api = fake_client(ok('productName' => 'com', 'sellingPrice' => 9.99, 'sellingCurrency' => 'USD',
                                 'subproducts' => [{ 'productName' => 'x', 'buyingPrice' => 1 }]))
    info = client.products.info('.com', order_type: :renew, years: 2)
    assert_equal 9.99, info.selling_price
    assert_equal 1.0, info.subproducts.first.buying_price
    assert_equal [%w[ProductName com], %w[OrderType 2], %w[Period 2]], api.query
    assert_raises(InputError) { client.products.info('com', order_type: nil) }
    assert_raises(InputError) { client.products.info('com', order_type: :renew, years: 0) }

    client, api = fake_client(ok('items' => [{ 'productName' => 'com', 'productType' => 1 }], 'totalCount' => 1))
    assert client.products.list(product_type: :domain).first.product_type.domain?
    assert_equal [%w[ProductType 1]], api.query

    tlds = ok('items' => [{ 'name' => 'com.tr.extra' }, { 'name' => 'com.tr', 'isPrivacyAvailable' => true }],
              'totalCount' => 2)
    client, api = fake_client(tlds, currency: 'usd')
    tld = client.products.tld('.COM.TR')
    assert_equal 'com.tr', tld.name
    assert tld.privacy_available?
    assert_equal [%w[FilterText com.tr], %w[Currency USD], %w[MaxResultCount 100]], api.query
    client, = fake_client(ok('items' => [], 'totalCount' => 0))
    assert_nil client.products.tld('nope')

    client, api = fake_client(ok('items' => [{ 'productCode' => 'PositiveSSL', 'isWildcard' => false,
                                               'prices' => [{ 'create' => [{ 'period' => 1, 'price' => 5 }] }] }],
                                 'totalCount' => 1))
    ssl = client.products.ssls(wildcard: false, limit: 10).first
    assert_equal 5.0, ssl.prices.first.create.first.price
    assert_equal [%w[IsWildcard false], %w[MaxResultCount 10]], api.query

    client, api = fake_client(ok('items' => [{ 'name' => 'com' }], 'totalCount' => 1))
    assert_equal ['com'], client.products.all_tlds.map(&:name)
    client.products.tlds(filter_text: 'net')
    assert_equal [%w[FilterText net]], api.query
  end

  # Every service method sends the request it documents.
  def test_every_service_method
    contact = sample_contact
    calls = {
      'GET /api/v1/deposit/accounts/me' => ->(c) { c.account.get },
      'GET /api/v1/deposit/transactions' => ->(c) { c.account.transactions },
      'GET /api/v1/contacts/DNA-1' => ->(c) { c.contacts.get('DNA-1') },
      'POST /api/v1/contacts' => ->(c) { c.contacts.create(contact) },
      'PUT /api/v1/contacts/DNA-1' => ->(c) { c.contacts.update('DNA-1', contact) },
      'GET /api/v1/contacts/verification/check' => ->(c) { c.contacts.verification('DNA-1') },
      'POST /api/v1/contacts/verification/request' => ->(c) { c.contacts.resend_verification('DNA-1') },
      'POST /api/v1/domains/search' => ->(c) { c.domains.search('example.com') },
      'POST /api/v1/domains/bulk-search' => ->(c) { c.domains.bulk_search('example.com') },
      'GET /api/v1/domains' => ->(c) { c.domains.list },
      'GET /api/v1/domains/info' => ->(c) { c.domains.info('example.com') },
      'POST /api/v1/domains/register' => lambda { |c|
        c.domains.register(domain_name: 'example.com', name_servers: ['ns1.example.net'], handles: 'DNA-1')
      },
      'POST /api/v1/domains/register-with-contacts' => lambda { |c|
        c.domains.register_with_contacts(domain_name: 'example.com', name_servers: ['ns1.example.net'],
                                         contacts: contact)
      },
      'POST /api/v1/domains/renew' => ->(c) { c.domains.renew('example.com', years: 1) },
      'POST /api/v1/domains/renew/check' => ->(c) { c.domains.renew_check('example.com') },
      'POST /api/v1/domains/restore' => ->(c) { c.domains.restore('example.com') },
      'POST /api/v1/domains/transfer' => ->(c) { c.domains.transfer('example.com', auth_code: 'x') },
      'POST /api/v1/domains/transfers/check' => ->(c) { c.domains.transfer_check('example.com', 'x') },
      'POST /api/v1/domains/transfers/query' => ->(c) { c.domains.transfer_status('example.com') },
      'POST /api/v1/domains/lock' => ->(c) { c.domains.lock('example.com') },
      'POST /api/v1/domains/unlock' => ->(c) { c.domains.unlock('example.com') },
      'POST /api/v1/domains/privacy' => ->(c) { c.domains.set_privacy('example.com', true) },
      'PUT /api/v1/domains/auth' => ->(c) { c.domains.update_auth_code('example.com') },
      'PUT /api/v1/domains/dns/name-server' => ->(c) { c.domains.set_name_servers('example.com', ['ns1.x.net']) },
      'POST /api/v1/domains/dns/host' => ->(c) { c.domains.add_host('example.com', 'ns1.example.com', '192.0.2.1') },
      'PUT /api/v1/domains/dns/host' => lambda { |c|
        c.domains.update_host('example.com', 'ns1.example.com', ip_addresses: ['192.0.2.1'])
      },
      'DELETE /api/v1/domains/dns/host' => ->(c) { c.domains.delete_host('example.com', 'ns1.example.com') },
      'PUT /api/v1/domains/contacts/update' => ->(c) { c.domains.update_contacts('example.com', admin: contact) },
      'PUT /api/v1/domains/contacts/update-with-handle' => ->(c) { c.domains.set_contact_handles('example.com', 'D') },
      'GET /api/v1/domains/documents' => ->(c) { c.domains.documents('example.com.tr') },
      'POST /api/v1/domains/documents' => lambda { |c|
        c.domains.upload_documents('example.com.tr', DocumentUpload.new(type: 1, file_name: 'a.pdf', content: 'x'))
      },
      'GET /api/v1/domains/forwards' => ->(c) { c.domains.forwarding('example.com') },
      'POST /api/v1/domains/forwards' => ->(c) { c.domains.set_forwarding('example.com', 'https://example.org') },
      'DELETE /api/v1/domains/forwards' => ->(c) { c.domains.delete_forwarding('example.com') },
      'GET /api/v1/domains/zones' => ->(c) { c.dns.list('example.com') },
      'POST /api/v1/domains/zones' => ->(c) { c.dns.add('example.com', name: 'www', type: :a, values: '192.0.2.1') },
      'PUT /api/v1/domains/zones' => lambda { |c|
        c.dns.update('example.com', record_name: 'www', type: :a, values: '192.0.2.1')
      },
      'DELETE /api/v1/domains/zones' => ->(c) { c.dns.delete('example.com', name: 'www', type: :a, value: '192.0.2.1') },
      'POST /api/v1/domains/zones/apply' => ->(c) { c.dns.apply('example.com') },
      'GET /api/v1/domains/dns/dnssec' => ->(c) { c.dnssec.get('example.com') },
      'POST /api/v1/domains/dns/dnssec' => ->(c) { c.dnssec.add('example.com', '1 13 2 AB') },
      'DELETE /api/v1/domains/dns/dnssec' => ->(c) { c.dnssec.remove('example.com', '1 13 2 AB') },
      'POST /api/v1/domains/dns/dnssec/disable' => ->(c) { c.dnssec.disable('example.com') },
      'POST /api/v1/ssls/generate-csr' => lambda { |c|
        c.ssl.generate_csr(domain_name: 'example.com', country: 'TR', state: 'S', locality: 'L', organization: 'O',
                           organization_unit: 'U')
      },
      'POST /api/v1/ssls/check-csr' => ->(c) { c.ssl.check_csr('CSR') },
      'POST /api/v1/ssls/initialize' => ->(c) { c.ssl.purchase('example.com', package_code: 'P') },
      'PUT /api/v1/ssls/configure' => lambda { |c|
        c.ssl.configure(domain_name: 'example.com', csr: 'CSR', contact: sample_ssl_contact)
      },
      'PUT /api/v1/ssls/check-status' => ->(c) { c.ssl.status('example.com') },
      'GET /api/v1/ssls/certificate' => ->(c) { c.ssl.get('example.com') },
      'GET /api/v1/ssls/certificate-content' => ->(c) { c.ssl.content('example.com') },
      'POST /api/v1/ssls/reissue' => ->(c) { c.ssl.reissue('example.com') },
      'GET /api/v1/ssls/approvers' => ->(c) { c.ssl.approvers('example.com') },
      'DELETE /api/v1/ssls/revoke' => ->(c) { c.ssl.revoke('example.com') },
      'GET /api/v1/hostings/packages' => ->(c) { c.hosting.packages },
      'GET /api/v1/hostings/plans' => ->(c) { c.hosting.plans },
      'POST /api/v1/hostings/create' => ->(c) { c.hosting.create('example.com', service_plan: 'P') },
      'GET /api/v1/hostings' => ->(c) { c.hosting.get(service_id: 'HST-1') },
      'GET /api/v1/hostings/by-token' => ->(c) { c.hosting.get_by_token('t') },
      'GET /api/v1/hostings/check-status' => ->(c) { c.hosting.status(service_id: 'HST-1') },
      'GET /api/v1/order/ORD-1' => ->(c) { c.orders.get('ORD-1') },
      'GET /api/v1/products' => ->(c) { c.products.list },
      'GET /api/v1/products/info' => ->(c) { c.products.info('com', order_type: :register) },
      'GET /api/v1/products/tlds' => ->(c) { c.products.tlds },
      'GET /api/v1/products/ssls' => ->(c) { c.products.ssls }
    }
    assert_equal 64, calls.size
    # One answer every operation accepts: success flags set, a handle, a forwarding target.
    universal = ok('success' => true, 'isSuccess' => true, 'contactUpdateSuccess' => true, 'handle' => 'DNA-1',
                   'redirectAlias' => 'https://example.org', 'items' => [], 'infos' => [{ 'domainName' => 'x' }])
    calls.each do |want, call|
      client, api = fake_client(universal)
      call.call(client)
      assert_equal want, "#{api.last.http_method} #{api.path}"
    end
  end
end
