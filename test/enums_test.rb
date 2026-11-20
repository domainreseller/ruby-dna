# frozen_string_literal: true

require_relative 'test_helper'

class EnumsTest < Minitest::Test
  include DomainNameApi

  INTEGER_ENUMS = [
    DomainStatus, DNSSECMode, DocumentType, DocumentStatus, DocumentOperationType, DNSSECStatus,
    DNSSECOperationType, DSRecordStatus, DNSSECAlgorithm, DSDigestType, TransactionType, TransactionStatus,
    ChargeType, ProductType, OrderType, OrderStatus, OrderProductStatus
  ].freeze
  STRING_ENUMS = [ContactType, ForwardType, IPVersion, RecordType, AuthenticationType, WebServerType].freeze

  def test_every_member_parses_back_and_decodes
    (INTEGER_ENUMS + STRING_ENUMS).each do |enum|
      refute_empty enum.members, enum.name
      enum.members.each do |m|
        assert_same m, enum[m.key], "#{enum}[#{m.key.inspect}]"
        assert_same m, enum[m.name.downcase], "#{enum}[#{m.name.downcase.inspect}]"
        assert_same m, enum[m.value], "#{enum}[#{m.value.inspect}]"
        assert_same m, enum.parse(m.name), "#{enum}.parse(#{m.name.inspect})"
        assert_same m, enum.decode(m.name), "#{enum}.decode(#{m.name.inspect})"
        assert_same m, enum.decode(m.value)
        assert_same m, enum.const_get(m.key.to_s.upcase)
        assert m.public_send(:"#{m.key}?"), "#{m.inspect}.#{m.key}?"
        assert m.known?
        assert_equal m.name, m.to_s
        assert m.frozen?
      end
      assert_equal enum.members.size, enum.members.map(&:value).uniq.size, "#{enum}: duplicate values"
    end
  end

  def test_integer_enums
    s = DomainStatus::PENDING_DELETE
    assert_equal 7, s.to_i
    assert_equal 'PendingDelete', s.to_s
    assert_equal :pending_delete, s.to_sym
    assert s.pending_delete?
    refute s.active?
    assert_equal s, :pending_delete
    assert_equal s, 'pendingdelete'
    assert_equal s, 'Pending_Delete'
    assert_equal s, 7
    assert_equal s, '7'
    refute_equal s, DomainStatus::ACTIVE
    refute_equal s, ProductType[7]
    assert_equal '7', s.to_json
    assert_equal({ s => 1 }, { DomainStatus[7] => 1 })
    assert_equal '#<DomainNameApi::DomainStatus PendingDelete (7)>', s.inspect

    assert_same DomainStatus::TRANSFERRED_OUT, DomainStatus.decode(4)
    assert_same DomainStatus::TRANSFERRED_OUT, DomainStatus.decode(4.0)
    assert_same DomainStatus::TRANSFERRED_OUT, DomainStatus.decode('transferredOut')
    assert_nil DomainStatus.decode(nil)
    assert_nil DomainStatus[nil]
    assert_nil DomainStatus[:nope]
    assert_nil DomainStatus[7.5]
  end

  def test_unknown_values_still_decode
    u = DomainStatus.decode(99)
    refute u.known?
    assert_equal 99, u.value
    assert_equal 'DomainStatus(99)', u.to_s
    assert_equal u, 99
    refute u.active?
    refute_equal u, DomainStatus::ACTIVE

    named = DomainStatus.decode('SomethingNew')
    refute named.known?
    assert_equal 'SomethingNew', named.to_s
    assert_equal 42, DomainStatus.decode('42').value

    contact = ContactType.decode('Reseller')
    refute contact.known?
    assert_equal 'Reseller', contact.to_s
  end

  def test_parse_explains_the_allowed_values
    error = assert_raises(ArgumentError) { DNSSECMode.parse(:sometimes) }
    assert_includes error.message, 'is not a valid DNSSECMode'
    assert_includes error.message, 'Block, KeepDnssec, DisableDnssec'
  end

  def test_names_and_aliases
    assert_same DNSSECMode::KEEP, DNSSECMode[:keep]
    assert_same DNSSECMode::KEEP, DNSSECMode['KeepDnssec']
    assert_same ProductType::SSL, ProductType['ssl']
    assert_equal 'SSL', ProductType::SSL.to_s
    assert_same ContactType::REGISTRANT, ContactType['owner']
    assert_same ContactType::ADMIN, ContactType['ADMINISTRATIVE']
    assert_same ContactType::TECH, ContactType['technical']
    assert_same ChargeType::SUBTRACT, ChargeType[:debit]
    assert_same DNSSECAlgorithm::ECDSA_P256_SHA256, DNSSECAlgorithm['EcdsaP256Sha256']
    assert_same DNSSECAlgorithm::ECDSA_P256_SHA256, DNSSECAlgorithm['13']
  end

  def test_record_types_keep_the_api_case
    assert_equal 'TXT', RecordType['txt'].value
    assert_equal 'DNSKey', RecordType[:dnskey].value
    assert_equal 'NSEC3Param', RecordType['nsec3param'].value
    assert_equal 'AAAA', RecordType::AAAA.value
    assert_nil RecordType['BOGUS']
    assert_equal 35, RecordType.members.size
  end

  # Every integer enum of the spec must map to an enum class here, and each of
  # its values must have a member.
  def test_spec_enums
    domains = 'Dna.DomainService.Domains.'
    dnssec = 'Dna.DomainService.Dnssec.'
    deposit = 'Dna.DepositService.Accounts.'
    orders = 'Dna.OrderService.Orders.'
    product = 'Dna.ProductService.Products.'
    known = {
      "#{domains}DomainDto.status" => DomainStatus,
      "#{domains}DomainDocumentInfoDto.status" => DocumentStatus,
      "#{domains}DomainDocumentInfoDto.type" => DocumentType,
      "#{domains}DomainDocumentInfoDto.operationType" => DocumentOperationType,
      "#{domains}DomainDocumentUploadItemInput.documentType" => DocumentType,
      "#{domains}DomainDocumentUploadedItemDto.type" => DocumentType,
      "#{dnssec}DnssecInfoBaseDto.status" => DNSSECStatus,
      "#{dnssec}DsRecordBaseDto.status" => DSRecordStatus,
      "#{dnssec}DnssecOperationResultBaseDto.operationType" => DNSSECOperationType,
      'Dna.DomainService.Dns.DnsEditNameServerInput.dnssecMode' => DNSSECMode,
      "#{deposit}AccountTransactionDto.type" => TransactionType,
      "#{deposit}AccountTransactionDto.status" => TransactionStatus,
      "#{deposit}AccountTransactionDto.chargeType" => ChargeType,
      "#{deposit}AccountTransactionDto.productType" => ProductType,
      "#{orders}OrderDto.status" => OrderStatus,
      "#{orders}OrderProductDto.status" => OrderProductStatus,
      "#{orders}OrderProductDto.orderType" => OrderType,
      "#{orders}OrderProductDto.productType" => ProductType,
      "#{product}ProductDto.productType" => ProductType,
      "#{product}ProductInfoDto.productType" => ProductType,
      "#{product}SubproductDto.productType" => ProductType
    }
    seen = {}
    SpecTest::SPEC['components']['schemas'].each do |schema, s|
      (s['properties'] || {}).each do |prop, p|
        values = p['enum']
        next if values.nil? || values.empty?

        key = "#{schema}.#{prop}"
        enum = known[key]
        refute_nil enum, "#{key} is an enum without a Ruby class here"
        next unless enum

        seen[key] = true
        values.each { |v| refute_nil enum[v.to_i], "#{key}: value #{v} has no member in #{enum}" }
      end
    end
    assert_empty known.keys - seen.keys, 'enums that are not in the spec any more'
  end
end
