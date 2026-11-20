# frozen_string_literal: true

module DomainNameApi
  # The result of a domain search.
  class Availability < Model
    field :domain_name
    field :tld
    # The registry answer: "AVAILABLE", "NOTAVAILABLE", ... Use #available?.
    field :status
    # Explains a status other than AVAILABLE, e.g. "Domain exists".
    field :reason
    field :price, :float
    field :currency
    field :period, :integer
    field :premium, :boolean, from: 'isPremium'
    # The registry asks for documents (domains.upload_documents).
    field :document_required, :boolean, from: 'isDocumentRequired'

    # Whether the domain can be registered.
    def available?
      status.to_s.casecmp?('AVAILABLE')
    end
  end

  # The API's answer to DomainSearchRequest.
  class DomainSearchResult < Model
    field :success, :boolean
    field :code
    field :message, from: 'operationMessage'
    field :reason
    field :info, Availability
  end

  # The API's answer to DomainBulkSearchRequest.
  class DomainBulkSearchResult < Model
    field :success, :boolean
    field :code
    field :message, from: 'operationMessage'
    field :reason
    field :infos, [Availability]
  end

  # A nameserver of a domain in the domain list.
  class NameServer < Model
    field :name
    field :child_name_server, :boolean, from: 'isChildnameServer'
    field :glue_record, :boolean, from: 'isGlueRecord'
    field :linked, :boolean, from: 'isLinked'
  end

  # A domain in the domain list. domains.info returns more.
  class Domain < Model
    field :domain_name
    field :domain_name_idn, from: 'domainNameIdn'
    field :idn, :boolean, from: 'isIdnName'
    field :status, DomainStatus
    # The registry (EPP) status, e.g. "clientTransferProhibited".
    field :status_code
    field :start_date, :time
    field :expiration_date, :time
    field :transfer_date, :time
    field :updated_date, :time
    # End of the redemption grace period.
    field :rgp_expiration_date, :time, from: 'rgpExpirationDate'
    # End of the add grace period.
    field :agp_expiration_date, :time, from: 'agpExpirationDate'
    field :failure_date, :time
    field :finalization_date, :time
    field :remaining_days, :integer, from: 'remainingDay'
    field :locked, :boolean, from: 'lockStatus'
    field :privacy_protection, :boolean, from: 'privacyProtectionStatus'
    field :renewal_mode
    field :object_class
    # The contact roles and their handles.
    field :contacts, :attributes
    field :name_servers, [NameServer], from: 'nameservers'
  end

  # An address of a child nameserver.
  class IPAddress < Model
    field :address, from: 'ipAddress'
    field :version, IPVersion, from: 'ipVersion'
  end

  # A child nameserver (glue record) such as ns1.example.com.
  class Host < Model
    field :name
    field :ip_addresses, [IPAddress]
  end

  # The full record of a domain.
  class DomainInfo < Model
    field :domain_name
    field :domain_name_idn, from: 'domainNameIdn'
    field :idn, :boolean, from: 'isIdnName'
    field :status, DomainStatus
    # The registry (EPP) status, e.g. "clientTransferProhibited".
    field :status_code
    # Explains the status, e.g. "RddsVerificationPending".
    field :status_reason
    # The registry's redemption grace period status.
    field :rgp_status, from: 'rgpStatues'
    field :start_date, :time
    field :expiration_date, :time
    field :transfer_date, :time
    field :updated_date, :time
    field :remaining_days, :integer, from: 'remainingDay'
    field :reseller_id
    field :renewal_mode
    # The transfer authorization (EPP) code.
    field :auth_code
    field :locked, :boolean, from: 'lockStatus'
    field :privacy_protection, :boolean, from: 'privacyProtectionStatus'
    # The registry's object ID, e.g. "123456_DOMAIN_COM-VRSN".
    field :registry_object_id, from: 'objectId'
    field :forwarded, :boolean, from: 'isForwarded'
    field :use_trustee_contact, :boolean
    field :name_servers, [:string], from: 'nameservers'
    # The child nameservers registered under the domain.
    field :hosts, [Host]
    field :contacts, [Contact]
    field :additional_attributes, :attributes

    # The contact in a role (:registrant, :admin, :tech, :billing), or nil.
    def contact(role)
      role = ContactType.parse(role)
      contacts.find { |c| c.type == role }
    end
  end

  # The API's answer to a registration, renewal or transfer.
  class DomainOperationResult < Model
    field :success, :boolean
    field :message
    # Identifies the domain on the platform.
    field :domain_id
    # The domain's status after the operation, e.g. "Active" or a waiting status.
    field :status
    field :expiration_date, :time
  end

  # Whether and at what price a domain can be renewed.
  class RenewCheck < Model
    field :renewable, :boolean, from: 'renewabilityStatus'
    field :renewal_lock, :boolean
    field :error_message_key
    field :premium, :boolean, from: 'isPremium'
    field :premium_price, :float
    field :premium_currency
  end

  # The contact handle of each role.
  #
  #   DomainNameApi::ContactHandles.new(registrant: 'DNA-1', admin: 'DNA-2', tech: 'DNA-2', billing: 'DNA-2')
  #   DomainNameApi::ContactHandles.same('DNA-1')
  #
  # Requests also accept a Hash of roles, or one handle String for all four.
  class ContactHandles < Model
    ROLES = %i[registrant admin tech billing].freeze

    field :registrant
    field :admin
    field :tech
    field :billing

    # One handle for all four roles.
    def self.same(handle)
      new(registrant: handle, admin: handle, tech: handle, billing: handle)
    end

    def self.coerce(value)
      value.is_a?(String) ? same(value) : super
    end

    # The roles that are set, as the API expects them, in the order Registrant,
    # Admin, Tech, Billing.
    def items
      ROLES.filter_map do |role|
        handle = Util.clean(public_send(role))
        { 'contactType' => ContactType.parse(role).value, 'handle' => handle } unless handle.empty?
      end
    end

    # @api private
    def validate_into(v, field, all:)
      n = items.size
      if all && n < 4
        v.add(field, 'needs a handle for every role (registrant, admin, tech, billing); ' \
                     'ContactHandles.same sets all four')
      elsif n.zero?
        v.add(field, 'needs at least one handle')
      end
      v
    end
  end

  # The contact of each role.
  #
  #   DomainNameApi::DomainContacts.new(registrant: owner, admin: admin, tech: admin, billing: admin)
  #   DomainNameApi::DomainContacts.same(owner)
  #
  # Requests also accept a Hash of roles, or one Contact (or Hash of contact
  # fields) for all four.
  class DomainContacts < Model
    ROLES = ContactHandles::ROLES

    field :registrant, Contact
    field :admin, Contact
    field :tech, Contact
    field :billing, Contact

    # One contact for all four roles.
    def self.same(contact)
      contact = Contact.coerce(contact)
      new(registrant: contact, admin: contact, tech: contact, billing: contact)
    end

    def self.coerce(value)
      case value
      when Contact then same(value)
      when Hash
        return new if value.empty?

        roles = value.keys.map { |k| ContactType[k]&.key }
        if roles.none?(&:nil?)
          new(**value.each_with_object({}) { |(k, v), out| out[ContactType[k].key] = Contact.coerce(v) })
        else
          same(Contact.coerce(value))
        end
      else super
      end
    end

    # The contacts that are set, each with its role, as the API expects them.
    def items
      ROLES.filter_map do |role|
        contact = public_send(role)
        contact&.to_api(role)
      end
    end

    # @api private
    def validate_into(v, field, all:)
      ROLES.each do |role|
        contact = public_send(role)
        if contact
          contact.validate_into(v, "#{field}.#{role}.")
        elsif all
          v.add("#{field}.#{role}", 'is required (DomainContacts.same sets all four roles)')
        end
      end
      v.add(field, 'needs at least one contact') if !all && items.empty?
      v
    end
  end

  # --- Requests ----------------------------------------------------------------

  # Checks the availability and price of a domain. CLI: dna domain search
  class DomainSearchRequest < BaseRequest
    endpoint :post, '/api/v1/domains/search', safety: :read
    returns DomainSearchResult
    attribute :domain_name
    # Currency of the price, e.g. "USD" or "TRY". nil uses the account's.
    attribute :currency

    def body
      domain_body.merge(optional('currency' => currency))
    end

    def validate
      required :domain_name
    end
  end

  # Checks several domains at once (at most MAX_DOMAINS). domains.bulk_search
  # splits longer lists for you. CLI: dna domain bulk-search
  class DomainBulkSearchRequest < BaseRequest
    MAX_DOMAINS = 30

    endpoint :post, '/api/v1/domains/bulk-search', safety: :read
    returns DomainBulkSearchResult
    attribute :domain_names, default: []
    # Currency of the prices, e.g. "USD" or "TRY". nil uses the account's.
    attribute :currency

    def body
      clean_list(domain_names).map { |name| { 'domainName' => name }.merge(optional('currency' => currency)) }
    end

    def validate
      required_list :domain_names
      check(clean_list(domain_names).size <= MAX_DOMAINS, :domain_names,
            "may hold at most #{MAX_DOMAINS} domains; domains.bulk_search splits longer lists")
    end
  end

  # Lists your domains. CLI: dna domain list
  class DomainListRequest < PagedRequest
    endpoint :get, '/api/v1/domains', safety: :read
    returns Page.of(Domain)
    # Keeps domains whose name contains this text.
    attribute :domain_name
    # Keeps only domains in these states (DomainStatus: :active, :pending_delete, ...).
    attribute :statuses, default: []

    def query
      params.string('DomainName', domain_name)
            .joined('StatusIds', Array(statuses).map { |s| DomainStatus[s] || s })
            .page(skip: skip, limit: limit, sort: sort)
    end

    def validate
      super
      Array(statuses).each { |s| enum(:statuses, DomainStatus, s) }
    end
  end

  # Reads the full record of a domain. CLI: dna domain info
  class DomainInfoRequest < BaseRequest
    endpoint :get, '/api/v1/domains/info', safety: :read
    returns DomainInfo
    attribute :domain_name

    def query
      params.string('DomainName', domain_name)
    end

    def validate
      required :domain_name
    end
  end

  # Registers a domain with existing contact handles. Charges your balance.
  # CLI: dna domain register
  class DomainRegisterRequest < BaseRequest
    endpoint :post, '/api/v1/domains/register', safety: :billable
    returns DomainOperationResult
    attribute :domain_name
    # Registration period, 1 to 10 years (nil means 1).
    attribute :years
    # Nameserver host names; most registries want two or more.
    attribute :name_servers, default: []
    # The contact handles of the four roles: ContactHandles, a Hash of roles,
    # or one handle for all four.
    attribute :handles
    # Registry attributes some TLDs require (see TLD#required_attributes).
    attribute :tld_attributes, default: {}

    def body
      domain_body.merge(optional(
                          'period' => Util.to_int(years), 'nameServers' => clean_list(name_servers),
                          'handles' => handles.nil? ? [] : ContactHandles.coerce(handles).items,
                          'tldAttributes' => Util.attributes(tld_attributes)
                        ))
    end

    def validate
      required :domain_name
      between :years, 1, 10
      required_list :name_servers
      return invalid(:handles, 'is required (ContactHandles.same sets all four roles)') if handles.nil?

      ContactHandles.coerce(handles).validate_into(validator, :handles, all: true)
    end
  end

  # Registers a domain with the contact details given inline. Charges your
  # balance. CLI: dna domain register-with-contacts
  class DomainRegisterWithContactsRequest < BaseRequest
    endpoint :post, '/api/v1/domains/register-with-contacts', safety: :billable
    returns DomainOperationResult
    attribute :domain_name
    # Registration period, 1 to 10 years (nil means 1).
    attribute :years
    attribute :name_servers, default: []
    # Required for all four roles unless use_trustee_contact is set:
    # DomainContacts, a Hash of roles, or one Contact for all four.
    attribute :contacts
    attribute :tld_attributes, default: {}
    # Uses the registrar's trustee contact, for TLDs with TLD#support_trustee?.
    attribute :use_trustee_contact, default: false

    def body
      b = domain_body.merge(optional(
                              'period' => Util.to_int(years), 'nameServers' => clean_list(name_servers),
                              'tldAttributes' => Util.attributes(tld_attributes)
                            ))
      items = contact_items
      b['contacts'] = items unless items.empty?
      b['useTrusteeContact'] = true if use_trustee_contact
      b
    end

    def validate
      required :domain_name
      between :years, 1, 10
      required_list :name_servers
      return if use_trustee_contact && contact_items.empty?
      return invalid(:contacts, 'is required (DomainContacts.same sets all four roles)') if contacts.nil?

      DomainContacts.coerce(contacts).validate_into(validator, :contacts, all: !use_trustee_contact)
    end

    private

    def contact_items
      contacts.nil? ? [] : DomainContacts.coerce(contacts).items
    end
  end

  # Renews a domain. Charges your balance. CLI: dna domain renew
  class DomainRenewRequest < BaseRequest
    endpoint :post, '/api/v1/domains/renew', safety: :billable
    returns DomainOperationResult
    attribute :domain_name
    # Years to add, 1 to 10.
    attribute :years

    def body
      domain_body.merge(optional('period' => Util.to_int(years)))
    end

    def validate
      required :domain_name
      check((Util.to_int(years) || 0).between?(1, 10), :years, 'must be between 1 and 10')
    end
  end

  # Checks whether a domain can be renewed. CLI: dna domain renew-check
  class DomainRenewCheckRequest < BaseRequest
    endpoint :post, '/api/v1/domains/renew/check', safety: :read
    returns RenewCheck
    attribute :domain_name
    # Years to add, 1 to 10 (nil lets the API choose).
    attribute :years

    def body
      domain_body.merge(optional('period' => Util.to_int(years)))
    end

    def validate
      required :domain_name
      between :years, 1, 10
    end
  end

  # Restores a deleted domain during the registry's redemption period
  # (DomainStatus::PENDING_DELETE). Charges your balance; restore fees are
  # usually high. CLI: dna domain restore
  class DomainRestoreRequest < BaseRequest
    endpoint :post, '/api/v1/domains/restore', safety: :billable
    attribute :domain_name

    def body
      domain_body
    end

    def validate
      required :domain_name
    end
  end

  # --- Service -----------------------------------------------------------------

  # Searches, registers, renews, transfers and manages domains. CLI: dna domain
  class DomainService < Service
    # Whether a domain is available and what it costs. Prices use +currency+,
    # the client's currency: option or the account's. 2 searches per second are
    # allowed; the client paces them.
    #
    #   a = client.domains.search('example.com')
    #   puts "#{a.price} #{a.currency}" if a.available?
    def search(domain_name, currency: nil)
      req = DomainSearchRequest.new(domain_name: domain_name, currency: currency || client.currency)
      response = execute(req)
      res = response.value
      raise operation_error(req, response, res.code, first_present(res.reason, res.message)) unless res.success?

      res.info || Availability.new
    end

    # Checks several domains. Lists longer than 30 are sent in several
    # requests. Each result has its own status.
    #
    #   client.domains.bulk_search('example.com', 'example.net').each { |a| puts "#{a.domain_name} #{a.status}" }
    def bulk_search(*domain_names, currency: nil)
      names = Util.clean_list(domain_names)
      if names.empty?
        raise InputError.new('DomainBulkSearchRequest', [FieldError.new('domain_names', 'needs at least one value')])
      end

      names.each_slice(DomainBulkSearchRequest::MAX_DOMAINS).flat_map do |slice|
        req = DomainBulkSearchRequest.new(domain_names: slice, currency: currency || client.currency)
        response = execute(req)
        res = response.value
        if !res.success? && res.infos.empty?
          raise operation_error(req, response, res.code, first_present(res.reason, res.message))
        end

        res.infos
      end
    end

    # One page of your domains.
    #
    #   page = client.domains.list(statuses: [:active], limit: 50)
    def list(request = nil, **filters)
      call(build(DomainListRequest, request, filters))
    end

    # Every matching domain, fetching pages as you go. Returns an Enumerator, or
    # iterates when given a block.
    #
    #   client.domains.all { |d| puts "#{d.domain_name} expires #{d.expiration_date}" if d.remaining_days.to_i < 30 }
    def all(request = nil, **filters, &block)
      enum = paginate(build(DomainListRequest, request, filters)) { |req| call(req) }
      block ? enum.each(&block) : enum
    end

    # The full record of a domain: dates, status, lock and privacy, nameservers,
    # child hosts, contacts and the auth code. Not rate limited.
    def info(domain_name)
      call(DomainInfoRequest.new(domain_name: domain_name))
    end

    # Registers a domain with existing contact handles and charges your
    # balance. Check availability and price with #search first.
    #
    #   client.domains.register(domain_name: 'example.com', years: 1,
    #                           name_servers: %w[ns1.example.net ns2.example.net], handles: 'DNA-1')
    #
    # A refusal ("success": false) raises OperationError. After a NetworkError
    # check e.outcome_unknown? and the domain's state before trying again.
    def register(request = nil, **attributes)
      operation(build(DomainRegisterRequest, request, attributes))
    end

    # Registers a domain with inline contact details and charges your balance.
    #
    #   client.domains.register_with_contacts(domain_name: 'example.com',
    #                                         name_servers: %w[ns1.example.net ns2.example.net],
    #                                         contacts: DomainNameApi::DomainContacts.same(owner))
    def register_with_contacts(request = nil, **attributes)
      operation(build(DomainRegisterWithContactsRequest, request, attributes))
    end

    # Adds years (1 to 10) to a domain and charges your balance. Use
    # #renew_check first to see whether it is renewable and at what price.
    def renew(domain_name, years:)
      operation(DomainRenewRequest.new(domain_name: domain_name, years: years))
    end

    # Whether a domain can be renewed for +years+ (nil lets the API choose), and
    # the premium price, if any.
    def renew_check(domain_name, years: nil)
      call(DomainRenewCheckRequest.new(domain_name: domain_name, years: years))
    end

    # Brings back a deleted domain during the redemption period and charges
    # your balance.
    def restore(domain_name)
      call(DomainRestoreRequest.new(domain_name: domain_name))
      nil
    end

    private

    # Sends a request answered with a DomainOperationResult and turns
    # "success": false into an OperationError.
    def operation(request)
      response = execute(request)
      res = response.value
      raise operation_error(request, response, nil, res.message) unless res.success?

      res
    end
  end
end
