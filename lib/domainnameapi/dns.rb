# frozen_string_literal: true

module DomainNameApi
  # The fully qualified form of a DNS record name, the form the zone listing uses:
  # fqdn('example.com', 'www') is "www.example.com.", and '' and '@' give "example.com.".
  def self.fqdn(domain_name, name)
    domain = domain_name.to_s.strip.delete_suffix('.').downcase
    name = name.to_s.strip.delete_suffix('.')
    lower = name.downcase
    return "#{domain}." if name.empty? || name == '@' || lower == domain
    return "#{lower}." if lower.end_with?(".#{domain}")

    "#{lower}.#{domain}."
  end

  # One value of a record set.
  class Record < Model
    field :content
    field :disabled, :boolean
  end

  # The records with one name and type.
  class RecordSet < Model
    # Fully qualified with a trailing dot, e.g. "www.example.com.".
    field :name
    field :type, RecordType
    field :ttl, :integer
    field :change_type
    field :records, [Record]

    # The contents of the set's records.
    def values
      records.map(&:content)
    end

    # Whether the set has the given name and type. +name+ may be relative
    # ("www"), the apex ("" or "@") or fully qualified.
    def matches?(domain_name, name, type)
      type = RecordType[type]
      !type.nil? && self.type == type &&
        self.name.to_s.delete_suffix('.').casecmp?(DomainNameApi.fqdn(domain_name, name).delete_suffix('.'))
    end
  end

  # The report of dns.apply.
  class ZoneApplyResult < Model
    # False when the domain already used the platform nameservers.
    field :name_servers_changed, :boolean
    field :previous_name_servers, [:string]
    field :current_name_servers, [:string]
    field :system_name_servers, [:string]
  end

  # Building blocks of the zone requests. @api private
  module ZoneRecord
    # The TTL used when a request leaves it nil.
    DEFAULT_TTL = 3600

    private

    def zone_name(name)
      n = clean(name)
      n == '@' ? '' : n
    end

    def zone_type(type)
      RecordType[type]&.value || clean(type.is_a?(Enum) ? type.value : type)
    end

    def zone_struct(name, type, ttl, values)
      ttl = Util.to_int(ttl)
      { 'name' => zone_name(name), 'type' => zone_type(type), 'ttl' => ttl.nil? || ttl.zero? ? DEFAULT_TTL : ttl,
        'contents' => clean_list(values) }
    end

    def validate_record_type(type)
      if Util.blank?(type.is_a?(Enum) ? type.value : type)
        invalid(:type, 'is required')
      elsif RecordType[type].nil?
        invalid(:type, "#{type.inspect} is not a DNS record type the zone API supports")
      end
    end

    def validate_record_set(domain_name, name, type, ttl, values)
      required :domain_name, domain_name
      validate_record_type(type)
      n = Util.to_int(ttl)
      check(ttl.nil? || !n.nil?, :ttl, 'must be a number of seconds')
      check(n.nil? || n.zero? || n.between?(1, 86_400), :ttl, 'must be between 1 and 86400')
      text = clean(name)
      check(text == '@' || !text.start_with?('@'), :name, 'must not start with @ (use "@" alone for the apex)')
      apex = text.empty? || text == '@' || text.delete_suffix('.').casecmp?(clean(domain_name).delete_suffix('.'))
      contents = clean_list(values)
      required_list :values, contents

      case RecordType[type]&.key
      when :cname
        check(!apex, :name, 'a CNAME cannot be at the apex; use an ALIAS record')
        contents.each do |c|
          check(Util.ip_version(c).nil?, :values, "a CNAME points to a host name, not an IP address (#{c})")
        end
      when :mx
        contents.each do |c|
          parts = c.split
          ok = parts.size == 2 && parts[0].match?(/\A\d+\z/) && Util.ip_version(parts[1]).nil?
          check(ok, :values, %(an MX value is "PRIORITY HOST", e.g. "10 mail.example.com" (#{c})))
        end
      when :caa
        contents.each do |c|
          check(c.split.size == 3, :values, %(a CAA value has 3 parts, e.g. '0 issue "letsencrypt.org"' (#{c})))
        end
      when :a
        contents.each { |c| check(Util.ip_version(c) == :v4, :values, "#{c} is not an IPv4 address") }
      when :aaaa
        contents.each { |c| check(Util.ip_version(c) == :v6, :values, "#{c} is not an IPv6 address") }
      end
    end
  end

  # Lists the record sets of a domain. CLI: dna dns list
  class DNSListRequest < BaseRequest
    endpoint :get, '/api/v1/domains/zones', safety: :read
    returns [RecordSet]
    attribute :domain_name

    def query
      params.string('domainName', domain_name)
    end

    def validate
      required :domain_name
    end
  end

  # Adds values to a record set, creating the set when needed. Values already
  # in the set stay. CLI: dna dns add
  class DNSAddRequest < BaseRequest
    include ZoneRecord

    endpoint :post, '/api/v1/domains/zones', safety: :write
    attribute :domain_name
    # Relative ("www"), the apex ("" or "@") or fully qualified.
    attribute :name, default: ''
    # RecordType, in any case: :a, 'txt', RecordType::MX.
    attribute :type
    # Seconds, 1 to 86400 (nil means 3600).
    attribute :ttl
    # The record contents, e.g. "192.0.2.10", "10 mail.example.com" (MX) or
    # '0 issue "letsencrypt.org"' (CAA). TXT values are quoted by the API.
    attribute :values, default: []

    def query
      params.string('domainName', domain_name)
    end

    def body
      { 'zoneStruct' => zone_struct(name, type, ttl, values) }
    end

    def validate
      validate_record_set(domain_name, name, type, ttl, values)
    end
  end

  # Replaces every value of a record set (and its TTL); it can also rename the
  # set. CLI: dna dns update
  class DNSUpdateRequest < BaseRequest
    include ZoneRecord

    endpoint :put, '/api/v1/domains/zones', safety: :write, idempotent: true
    attribute :domain_name
    # The name of the existing set.
    attribute :record_name
    # The new name; nil keeps record_name.
    attribute :name
    attribute :type
    # Seconds, 1 to 86400 (nil means 3600).
    attribute :ttl
    # Replace all values of the set.
    attribute :values, default: []

    def query
      params.string('domainName', domain_name).string('recordName', record_name)
    end

    def body
      { 'zoneStruct' => zone_struct(new_name, type, ttl, values) }
    end

    def validate
      required :record_name
      validate_record_set(domain_name, new_name, type, ttl, values)
    end

    private

    def new_name
      Util.blank?(name) ? record_name : name
    end
  end

  # Removes one value from a record set; the set's other values stay.
  # CLI: dna dns delete
  class DNSDeleteRequest < BaseRequest
    include ZoneRecord

    endpoint :delete, '/api/v1/domains/zones', safety: :destructive
    attribute :domain_name
    attribute :name, default: ''
    attribute :type
    # The exact record content to remove.
    attribute :value

    def query
      params.string('domainName', domain_name)
            .string('RecordType', zone_type(type))
            .string('Record', value)
            .always('Name', zone_name(name)) # "" is the apex, and is sent
    end

    def validate
      required :domain_name
      validate_record_type(type)
      required :value
    end
  end

  # Switches a domain to the platform nameservers so its zone is served.
  # CLI: dna dns apply
  class DNSApplyRequest < BaseRequest
    endpoint :post, '/api/v1/domains/zones/apply', safety: :write, idempotent: true
    returns ZoneApplyResult
    attribute :domain_name

    def query
      params.string('domainName', domain_name)
    end

    def validate
      required :domain_name
    end
  end

  # The DNS zone of domains on the platform nameservers. CLI: dna dns
  #
  # A record set is all records with the same name and type; it has one TTL, and
  # a record is identified by its value. Changes are live at once in the
  # platform's DNS, but resolve publicly only when the domain uses the platform
  # nameservers (see #apply).
  #
  # The test environment (OTE) answers every zone call with HTTP 500, so zone
  # code can only be tried in production. Use a domain you do not mind changing.
  class DNSService < Service
    # The record sets of a domain. A domain without a zone has none.
    def list(domain_name)
      call(DNSListRequest.new(domain_name: domain_name))
    end

    # Adds values to a record set, creating it (and the zone) when needed.
    #
    #   client.dns.add('example.com', name: 'www', type: :a, values: '192.0.2.10', ttl: 600)
    def add(domain_name, name:, type:, values:, ttl: nil)
      call(DNSAddRequest.new(domain_name: domain_name, name: name, type: type, values: Array(values), ttl: ttl))
      nil
    end

    # Replaces all values (and the TTL) of a record set; +name+ renames it.
    #
    #   client.dns.update('example.com', record_name: 'www', type: :a, values: ['192.0.2.20'])
    def update(domain_name, record_name:, type:, values:, name: nil, ttl: nil)
      call(DNSUpdateRequest.new(domain_name: domain_name, record_name: record_name, name: name, type: type,
                                values: Array(values), ttl: ttl))
      nil
    end

    # Removes one value from a record set.
    #
    #   client.dns.delete('example.com', name: 'www', type: :a, value: '192.0.2.20')
    def delete(domain_name, name:, type:, value:)
      call(DNSDeleteRequest.new(domain_name: domain_name, name: name, type: type, value: value))
      nil
    end

    # Switches the domain to the platform nameservers, so the records managed
    # here become live. This replaces any other DNS provider of the domain; it
    # does nothing when the domain already uses them.
    def apply(domain_name)
      call(DNSApplyRequest.new(domain_name: domain_name))
    end
  end
end
