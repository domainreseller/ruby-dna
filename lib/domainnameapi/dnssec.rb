# frozen_string_literal: true

module DomainNameApi
  # A DS record at the registry.
  class DSRecord < Model
    field :key_tag, :integer
    field :algorithm, DNSSECAlgorithm
    field :digest_type, DSDigestType
    field :digest
    field :status, DSRecordStatus
    field :algorithm_not_recommended, :boolean, from: 'isAlgorithmNotRecommended'
    field :created_at, :time
    field :activated_at, :time
    field :removed_at, :time
  end

  # The DNSSEC state of a domain.
  class DNSSECInfo < Model
    field :domain_name
    # Whether the TLD supports DNSSEC.
    field :available, :boolean, from: 'isDnssecAvailable'
    field :status, DNSSECStatus
    field :delegation_signed, :boolean
    field :max_sig_life, :integer
    field :last_changed_at, :time
    field :ds_records, [DSRecord], from: 'dsRecords'
    field :allowed_algorithms, [DNSSECAlgorithm]
    field :allowed_digest_types, [DSDigestType]
    field :max_ds_record_count, :integer, from: 'maxDsRecordCount'
  end

  # A DS record to publish or remove, as your DNS provider shows it.
  #
  #   DomainNameApi::DS.parse('2371 13 2 1F987CC6583E92DF0890718C42...')
  #   DomainNameApi::DS.new(key_tag: 2371, algorithm: :ecdsa_p256_sha256, digest_type: :sha256, digest: '1F98...')
  class DS < Model
    PATTERN_HELP = 'want KEYTAG ALGORITHM DIGESTTYPE DIGEST'

    field :key_tag, :integer
    field :algorithm, DNSSECAlgorithm
    field :digest_type, DSDigestType
    field :digest

    # Parses a DS record in presentation format, "2371 13 2 1F98...", or a whole
    # zone-file line such as "example.com. 3600 IN DS 2371 13 2 1F98...".
    # Spaces inside the digest are removed.
    def self.parse(text)
      words = text.to_s.split
      at = words.index { |w| w.casecmp?('DS') }
      words = words[(at + 1)..] if at
      error = ArgumentError.new("#{text.inspect} is not a DS record (#{PATTERN_HELP})")
      raise error if words.size < 4

      key_tag = Util.to_int(words[0])
      algorithm = DNSSECAlgorithm[words[1]]
      digest_type = DSDigestType[words[2]]
      raise error if key_tag.nil? || !words[0].match?(/\A\d+\z/) || algorithm.nil? || digest_type.nil?

      new(key_tag: key_tag, algorithm: algorithm, digest_type: digest_type, digest: words[3..].join.upcase)
    end

    # Accepts a DS, a presentation-format String or a Hash of fields.
    def self.coerce(value)
      value.is_a?(String) ? parse(value) : super
    end

    # "2371 13 2 1F98..."
    def to_s
      "#{key_tag} #{algorithm&.to_i} #{digest_type&.to_i} #{digest}"
    end

    def to_api
      { 'keyTag' => key_tag.to_i, 'algorithm' => algorithm&.to_i, 'digestType' => digest_type&.to_i,
        'digest' => normalized_digest }
    end

    # The digest upper-cased, without spaces.
    def normalized_digest
      digest.to_s.split.join.upcase
    end

    # @api private
    def validate_into(v, field)
      v.check(!key_tag.nil? && key_tag.between?(0, 65_535), "#{field}.key_tag", 'must be between 0 and 65535')
      v.check(!algorithm.nil? && algorithm.to_i.between?(1, 255), "#{field}.algorithm",
              'is required (e.g. :ecdsa_p256_sha256)')
      v.check(!digest_type.nil? && digest_type.to_i.between?(1, 255), "#{field}.digest_type",
              'is required (e.g. :sha256)')
      v.required("#{field}.digest", digest)
      v.max_length("#{field}.digest", Util.clean(digest), 128)
      v
    end
  end

  # One DNSSEC operation.
  class DNSSECOperationResult < Model
    field :key_tag, :integer
    field :operation_type, DNSSECOperationType
    field :success, :boolean, from: 'isSuccess'
    # The registry accepted the change but has not confirmed it yet.
    field :pending, :boolean, from: 'isPending'
    field :message, from: 'resultMessage'
  end

  # The "items" wrapper of DNSSECAddRequest. @api private
  class DNSSECOperationResultList < Model
    field :items, [DNSSECOperationResult]
  end

  # Reads the DNSSEC state of a domain. CLI: dna dnssec get
  class DNSSECGetRequest < BaseRequest
    endpoint :get, '/api/v1/domains/dns/dnssec', safety: :read
    returns DNSSECInfo
    attribute :domain_name

    def query
      params.string('DomainName', domain_name)
    end

    def validate
      required :domain_name
    end
  end

  # Publishes DS records at the registry. CLI: dna dnssec add
  class DNSSECAddRequest < BaseRequest
    endpoint :post, '/api/v1/domains/dns/dnssec', safety: :write
    returns DNSSECOperationResultList
    attribute :domain_name
    # DS values, presentation-format Strings or Hashes of DS fields.
    attribute :records, default: []

    def body
      { 'domainName' => clean(domain_name), 'records' => ds_records.map(&:to_api) }
    end

    def validate
      required :domain_name
      list = ds_records
      check(!list.empty?, :records, 'needs at least one value')
      list.each_with_index { |d, i| d.validate_into(validator, "records[#{i}]") }
    end

    private

    def ds_records
      Array(records).map { |r| DS.coerce(r) }
    end
  end

  # Removes one DS record. CLI: dna dnssec remove
  class DNSSECRemoveRequest < BaseRequest
    endpoint :delete, '/api/v1/domains/dns/dnssec', safety: :destructive
    returns DNSSECOperationResult
    attribute :domain_name
    # A DS, a presentation-format String or a Hash of DS fields.
    attribute :record

    def query
      ds = DS.coerce(record)
      params.string('DomainName', domain_name)
            .always('KeyTag', ds.key_tag.to_i)
            .always('Algorithm', ds.algorithm&.to_i)
            .always('DigestType', ds.digest_type&.to_i)
            .always('Digest', ds.normalized_digest)
    end

    def validate
      required :domain_name
      return invalid(:record, 'is required') if record.nil?

      DS.coerce(record).validate_into(validator, 'record')
    end
  end

  # Removes every DS record of a domain. CLI: dna dnssec disable
  class DNSSECDisableRequest < BaseRequest
    endpoint :post, '/api/v1/domains/dns/dnssec/disable', safety: :destructive
    returns DNSSECOperationResult
    attribute :domain_name

    def body
      domain_body
    end

    def validate
      required :domain_name
    end
  end

  # Publishes and removes DS records at the registry. CLI: dna dnssec
  class DNSSECService < Service
    # The DNSSEC state of a domain: status, DS records and the algorithms the
    # registry accepts.
    def get(domain_name)
      call(DNSSECGetRequest.new(domain_name: domain_name))
    end

    # Publishes DS records from your DNS provider. Wrong DS records make the
    # domain unresolvable for validating resolvers: copy them exactly. Check
    # success? or pending? of each result.
    #
    #   client.dnssec.add('example.com', '2371 13 2 1F987CC6583E92DF0890718C42...')
    def add(domain_name, *records)
      call(DNSSECAddRequest.new(domain_name: domain_name, records: records.flatten)).items
    end

    # Removes one DS record.
    def remove(domain_name, record)
      operation(DNSSECRemoveRequest.new(domain_name: domain_name, record: record))
    end

    # Removes every DS record of a domain.
    def disable(domain_name)
      operation(DNSSECDisableRequest.new(domain_name: domain_name))
    end

    private

    def operation(request)
      response = execute(request)
      res = response.value
      raise operation_error(request, response, nil, res.message) if !res.success? && !res.pending?

      res
    end
  end
end
