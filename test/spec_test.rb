# frozen_string_literal: true

require_relative 'test_helper'

# These tests check every request class against the API's OpenAPI document in
# test/fixtures/openapi.json: the method and path exist, query parameters and
# body fields have the exact names the API uses, required fields are sent, and
# the JSON names of the response models exist in the response schemas. The
# coverage test fails when the API gains an operation without a request class.
#
# To update the document, download it from
# https://api.domainresellerapi.com/swagger/v1/swagger.json.
class SpecTest < Minitest::Test
  include DomainNameApi

  SPEC = JSON.parse(File.read(File.expand_path('fixtures/openapi.json', __dir__)))

  # Fields deliberately not in a response schema (the model is shared with a request).
  RESPONSE_FIELDS_NOT_IN_SPEC = ['Certificate.contacts[].title'].freeze

  def self.cases
    c = DnaTest.sample_contact
    from = Time.utc(2026, 1, 1)
    certificate = DnaTest::CERTIFICATE_ID
    [
      # account
      AccountGetRequest.new,
      AccountProfileRequest.new,
      AccountTransactionsRequest.new(skip: 10, limit: 20, sort: 'creationTime desc',
                                     transaction_types: %i[register renew], product_types: [:domain],
                                     charge_type: :subtract, currencies: ['USD'], from: from, to: from + 86_400,
                                     trace_id: 'abc', description: 'renew', filter_text: 'example', amount: 9.99),

      # contact
      ContactGetRequest.new(handle: 'DNA-1'),
      ContactCreateRequest.new(contact: c),
      ContactUpdateRequest.new(handle: 'DNA-1', contact: c),
      ContactVerificationRequest.new(handle: 'DNA-1'),
      ContactResendVerificationRequest.new(handle: 'DNA-1'),

      # domain
      DomainSearchRequest.new(domain_name: 'example.com', currency: 'USD'),
      DomainBulkSearchRequest.new(domain_names: %w[example.com example.net], currency: 'USD'),
      DomainListRequest.new(skip: 5, limit: 50, sort: 'expirationDate', domain_name: 'example',
                            statuses: %i[active pending_delete]),
      DomainInfoRequest.new(domain_name: 'example.com'),
      DomainRegisterRequest.new(domain_name: 'example.com', years: 2, name_servers: %w[ns1.example.net ns2.example.net],
                                handles: ContactHandles.same('DNA-1'), tld_attributes: { 'x' => 'y' }),
      DomainRegisterWithContactsRequest.new(domain_name: 'example.com', years: 1, name_servers: ['ns1.example.net'],
                                            contacts: DomainContacts.same(c), tld_attributes: { 'x' => 'y' },
                                            use_trustee_contact: true),
      DomainRenewRequest.new(domain_name: 'example.com', years: 1),
      DomainRenewCheckRequest.new(domain_name: 'example.com', years: 1),
      DomainRestoreRequest.new(domain_name: 'example.com'),
      DomainTransferRequest.new(domain_name: 'example.com', auth_code: 'Xy7!kP2q', years: 1),
      DomainTransferCheckRequest.new(domain_name: 'example.com', auth_code: 'Xy7!kP2q'),
      DomainTransferStatusRequest.new(domain_name: 'example.com'),
      DomainLockRequest.new(domain_name: 'example.com'),
      DomainUnlockRequest.new(domain_name: 'example.com'),
      DomainPrivacyRequest.new(domain_name: 'example.com', enabled: true),
      DomainUpdateAuthCodeRequest.new(domain_name: 'example.com'),
      DomainNameServersSetRequest.new(domain_name: 'example.com', name_servers: ['ns1.example.net'], dnssec_mode: :keep),
      DomainHostAddRequest.new(domain_name: 'example.com', host_name: 'ns1.example.com',
                               ip_addresses: ['192.0.2.1', '2001:db8::1']),
      DomainHostUpdateRequest.new(domain_name: 'example.com', host_name: 'ns1.example.com',
                                  new_host_name: 'ns3.example.com', ip_addresses: ['192.0.2.2']),
      DomainHostDeleteRequest.new(domain_name: 'example.com', host_name: 'ns1.example.com'),
      DomainContactsUpdateRequest.new(domain_name: 'example.com', contacts: DomainContacts.same(c)),
      DomainContactsSetHandlesRequest.new(domain_name: 'example.com', handles: ContactHandles.same('DNA-1')),
      DomainDocumentsListRequest.new(limit: 10, domain_name: 'example.com.tr', types: [:identity_card]),
      DomainDocumentsUploadRequest.new(domain_name: 'example.com.tr',
                                       documents: [DocumentUpload.new(type: :identity_card, file_name: 'id.pdf',
                                                                      content: '%PDF-1.4')]),
      DomainForwardGetRequest.new(domain_name: 'example.com'),
      DomainForwardSetRequest.new(domain_name: 'example.com', url: 'https://www.example.org', type: :frame),
      DomainForwardDeleteRequest.new(domain_name: 'example.com'),

      # dns
      DNSListRequest.new(domain_name: 'example.com'),
      DNSAddRequest.new(domain_name: 'example.com', name: 'www', type: 'a', ttl: 600, values: ['192.0.2.1']),
      DNSUpdateRequest.new(domain_name: 'example.com', record_name: 'www', name: 'web', type: :a, ttl: 600,
                           values: ['192.0.2.2']),
      DNSDeleteRequest.new(domain_name: 'example.com', name: 'www', type: :a, value: '192.0.2.1'),
      DNSApplyRequest.new(domain_name: 'example.com'),

      # dnssec
      DNSSECGetRequest.new(domain_name: 'example.com'),
      DNSSECAddRequest.new(domain_name: 'example.com',
                           records: [DS.new(key_tag: 2371, algorithm: :ecdsa_p256_sha256, digest_type: :sha256,
                                            digest: '1F98')]),
      DNSSECRemoveRequest.new(domain_name: 'example.com', record: '2371 13 2 1F98'),
      DNSSECDisableRequest.new(domain_name: 'example.com'),

      # ssl
      SSLGenerateCSRRequest.new(domain_name: 'example.com', country: 'TR', state: 'Istanbul', locality: 'Istanbul',
                                organization: 'Example Ltd', organization_unit: 'IT',
                                alternative_names: ['www.example.com']),
      SSLCheckCSRRequest.new(csr: '-----BEGIN CERTIFICATE REQUEST-----'),
      SSLInitializeRequest.new(domain_name: 'example.com', package_code: 'PositiveSSL'),
      SSLConfigureRequest.new(certificate_id: certificate, csr: 'csr', private_key: 'key',
                              approver_mail: 'admin@example.com', authentication_type: :email,
                              web_server_type: :apache, san_list: ['a.example.com'],
                              wildcard_list: ['*.example.com'], contact: DnaTest.sample_ssl_contact),
      SSLStatusRequest.new(certificate_id: certificate),
      SSLGetRequest.new(certificate_id: certificate),
      SSLContentRequest.new(certificate_id: certificate),
      SSLReissueRequest.new(certificate_id: certificate, approver_mail: 'admin@example.com', csr: 'csr',
                            private_key: 'key'),
      SSLApproversRequest.new(certificate_id: certificate),
      SSLRevokeRequest.new(certificate_id: certificate),
      SSLRenewRequest.new(certificate_id: certificate),
      SSLListRequest.new(skip: 10, limit: 20, domain_name: 'example.com'),

      # hosting
      HostingPackagesRequest.new,
      HostingPlansRequest.new(hosting_id: '6f1c0000-0000-4000-8000-000000000001'),
      HostingCreateRequest.new(domain_name: 'example.com', service_plan: 'Linux-Starter'),
      HostingGetRequest.new(service_id: 'HST-1'),
      HostingGetByTokenRequest.new(token: 'tok'),
      HostingStatusRequest.new(domain_name: 'example.com'),

      # order
      OrderGetRequest.new(order_code: 'ORD-1'),

      # product
      ProductListRequest.new(limit: 10, filter_text: 'com', product_type: :domain),
      ProductInfoRequest.new(product_name: 'com', order_type: :renew, years: 2),
      TLDListRequest.new(limit: 10, filter_text: 'com.tr', currency: 'USD'),
      SSLProductListRequest.new(limit: 10, filter_text: 'ssl', vendor_name: 'Sectigo', currency: 'USD',
                                validation_type: 1, wildcard: true, multi_domain: false)
    ]
  end

  # Other input modes of operations in .cases; checked against the spec too.
  def self.variants
    [
      # before a purchase there is no certificate yet
      SSLApproversRequest.new(domain_name: 'example.com', package_code: 'PositiveSSL')
    ]
  end

  def client
    @client ||= Client.new(reseller_id: 'r', api_key: 'k', base_url: 'https://api.example.test', pacing: false)
  end

  # --- a small reader for the OpenAPI document ---------------------------

  def resolve(schema)
    while schema.is_a?(Hash)
      if (ref = schema['$ref'])
        schema = SPEC['components']['schemas'][ref.delete_prefix('#/components/schemas/')]
      elsif schema['allOf'].is_a?(Array) && schema['allOf'].size == 1
        schema = schema['allOf'][0]
      else
        return schema
      end
    end
    nil
  end

  def find(method, path)
    SPEC['paths'].each do |template, ops|
      pattern = Regexp.new("\\A#{Regexp.escape(template).gsub(/\\\{[^}]+\\\}/, '[^/]+')}\\z")
      next unless pattern.match?(path)

      op = ops[method.downcase]
      return [template, op] if op
    end
    [nil, nil]
  end

  def first_schema(content)
    return nil unless content

    %w[application/json text/json text/plain].each { |ct| return content[ct]['schema'] if content[ct] }
    content.values.first&.fetch('schema', nil)
  end

  # Every key of value exists in schema, and every required key is present.
  def check_json(value, schema, path, errors)
    schema = resolve(schema)
    return unless schema

    case value
    when Hash
      props = schema['properties']
      return unless props # free-form map such as tldAttributes

      value.each do |k, sub|
        if props.key?(k)
          check_json(sub, props[k], "#{path}.#{k}", errors)
        else
          errors << "#{path}.#{k} is not in the spec (want one of #{props.keys.sort.join(', ')})"
        end
      end
      Array(schema['required']).each do |r|
        errors << "#{path}.#{r} is required by the spec but not sent" unless value.key?(r)
      end
    when Array
      value.each_with_index { |item, i| check_json(item, schema['items'], "#{path}[#{i}]", errors) }
    end
  end

  # The JSON names of a response type exist in its schema.
  def check_type(type, schema, path, errors)
    schema = resolve(schema)
    return unless schema

    if type.is_a?(Array)
      return errors << "#{path} is a list, but the spec has no array" unless schema['items']

      return check_type(type.first, schema['items'], "#{path}[]", errors)
    end
    return unless type.is_a?(Class) && type <= Model

    props = schema['properties'] || {}
    type.fields.each_value do |f|
      field_path = "#{path}.#{f.from}"
      if props.key?(f.from)
        check_type(f.type, props[f.from], field_path, errors)
      elsif !RESPONSE_FIELDS_NOT_IN_SPEC.include?(field_path)
        errors << "#{field_path} (#{f.name}) is not in the response schema (want one of #{props.keys.sort.join(', ')})"
      end
    end
  end

  # --- tests -------------------------------------------------------------

  def test_every_operation_has_a_request_class
    covered = {}
    self.class.cases.each do |req|
      template, op = find(req.http_method, req.path)
      refute_nil op, "#{req.class.request_name}: #{req.http_method} #{req.path} is not in the OpenAPI document"
      key = "#{req.http_method} #{template}"
      refute covered[key], "#{req.class.request_name}: #{key} is covered twice"
      covered[key] = true
    end

    missing = SPEC['paths'].flat_map { |t, ops| ops.keys.map { |m| "#{m.upcase} #{t}" } }.reject { |k| covered[k] }
    assert_empty missing.sort, 'the API has these operations but this gem has no request class for them'
    assert_equal 67, covered.size
  end

  def test_every_request_class_is_checked
    defined = ObjectSpace.each_object(Class).select do |k|
      k < BaseRequest && k != PagedRequest && k.name.to_s.start_with?('DomainNameApi::')
    end
    checked = self.class.cases.map(&:class)
    assert_empty (defined - checked).map(&:name).sort, 'request classes without a spec case'
    defined.each do |k|
      assert k.request_name.end_with?('Request'), "#{k.name}: request class names end in Request"
      refute_nil k.endpoint, "#{k.name} has no endpoint"
    end
  end

  def test_requests_match_the_spec
    (self.class.cases + self.class.variants).each do |req|
      name = req.class.request_name
      _, op = find(req.http_method, req.path)
      next unless op

      errors = req.validation_errors
      assert_empty errors.map(&:to_s), "#{name}: validation rejects the complete sample"
      if req.http_method == 'GET'
        assert_equal :read, req.safety, "#{name}: GET request with safety #{req.safety}"
      end

      prepared = client.prepare(req)
      problems = []

      # Query parameters: names must match the spec exactly.
      params = Array(op['parameters']).select { |p| p['in'] == 'query' }
      sent = URI.decode_www_form(URI(prepared.url).query.to_s).map(&:first)
      params.each do |p|
        problems << "required query parameter #{p['name']} is not sent" if p['required'] && !sent.include?(p['name'])
      end
      allowed = params.map { |p| p['name'] }
      sent.uniq.each do |k|
        problems << "query parameter #{k} is not in the spec (want one of #{allowed.sort.join(', ')})" unless allowed.include?(k)
      end

      # Body.
      body = prepared.body && JSON.parse(prepared.body)
      if op['requestBody'].nil? && !body.nil?
        problems << 'sends a body, but the operation takes none'
      elsif op['requestBody'] && body.nil?
        problems << 'sends no body, but the operation takes one'
      elsif body
        check_json(body, first_schema(op['requestBody']['content']), 'body', problems)
      end

      # Response type.
      type = req.class.returns
      if type
        response = %w[200 201 202].map { |code| op.dig('responses', code) }.compact.first
        schema = first_schema(response && response['content'])
        if schema.nil?
          problems << "the spec has no response body, but the request decodes into #{type.inspect}"
        else
          root = type.is_a?(Array) ? 'response' : type.name.to_s.split('::').last
          check_type(type, schema, root, problems)
        end
      end

      assert_empty problems, "#{name} (#{req.http_method} #{req.path})"
    end
  end

  def test_safety_classes
    expected = {
      DomainRegisterRequest => :billable, DomainRegisterWithContactsRequest => :billable,
      DomainRenewRequest => :billable, DomainRestoreRequest => :billable, DomainTransferRequest => :billable,
      SSLInitializeRequest => :billable, SSLRenewRequest => :billable, HostingCreateRequest => :billable,
      DomainSearchRequest => :read, DomainBulkSearchRequest => :read, SSLStatusRequest => :read,
      DomainRenewCheckRequest => :read, DomainTransferCheckRequest => :read, SSLGenerateCSRRequest => :read,
      DomainForwardDeleteRequest => :destructive, DomainHostDeleteRequest => :destructive,
      DNSDeleteRequest => :destructive, DNSSECRemoveRequest => :destructive, DNSSECDisableRequest => :destructive,
      SSLRevokeRequest => :destructive
    }
    expected.each { |klass, safety| assert_equal safety, klass.endpoint[:safety], klass.name }
    self.class.cases.each do |req|
      next unless req.billable?

      refute req.idempotent?, "#{req.class.name}: a billable request is never idempotent"
    end
  end
end
