# frozen_string_literal: true

module DomainNameApi
  # A domain's transfer authorization (EPP) code.
  class AuthCode < Model
    field :domain_name
    field :auth_code
  end

  # Turns the transfer lock on. CLI: dna domain lock
  class DomainLockRequest < BaseRequest
    endpoint :post, '/api/v1/domains/lock', safety: :write, idempotent: true
    attribute :domain_name

    def body
      domain_body
    end

    def validate
      required :domain_name
    end
  end

  # Turns the transfer lock off, which a transfer to another registrar needs.
  # CLI: dna domain unlock
  class DomainUnlockRequest < BaseRequest
    endpoint :post, '/api/v1/domains/unlock', safety: :write, idempotent: true
    attribute :domain_name

    def body
      domain_body
    end

    def validate
      required :domain_name
    end
  end

  # Turns WHOIS privacy protection on or off. CLI: dna domain privacy
  class DomainPrivacyRequest < BaseRequest
    endpoint :post, '/api/v1/domains/privacy', safety: :write, idempotent: true
    attribute :domain_name
    attribute :enabled, default: false

    def body
      { 'domainName' => clean(domain_name), 'privacyStatus' => Util.to_bool(enabled) ? true : false }
    end

    def validate
      required :domain_name
    end
  end

  # Asks the registry for a new transfer auth code. CLI: dna domain update-auth-code
  class DomainUpdateAuthCodeRequest < BaseRequest
    endpoint :put, '/api/v1/domains/auth', safety: :write
    returns AuthCode
    attribute :domain_name

    def body
      domain_body
    end

    def validate
      required :domain_name
    end
  end

  # Replaces the nameservers of a domain. CLI: dna domain nameservers set
  class DomainNameServersSetRequest < BaseRequest
    endpoint :put, '/api/v1/domains/dns/name-server', safety: :write, idempotent: true
    attribute :domain_name
    # The complete new list of nameserver host names.
    attribute :name_servers, default: []
    # Matters only for a DNSSEC-signed domain (DNSSECMode): :block (the default)
    # refuses the change while DS records exist, :keep keeps them, :disable
    # removes them first.
    attribute :dnssec_mode, default: :block

    def body
      { 'domainName' => clean(domain_name), 'nameServers' => clean_list(name_servers).map(&:downcase),
        'dnssecMode' => (DNSSECMode[dnssec_mode] || DNSSECMode::BLOCK).value }
    end

    def validate
      required :domain_name
      required_list :name_servers
      enum(:dnssec_mode, DNSSECMode)
    end
  end

  # Address lists of child nameserver requests. @api private
  module HostAddresses
    private

    def ip_address_items
      clean_list(ip_addresses).map do |ip|
        { 'ipAddress' => ip, 'ipVersion' => Util.ip_version(ip) == :v4 ? 'v4' : 'v6' }
      end
    end

    def validate_ip_addresses
      required_list :ip_addresses
      clean_list(ip_addresses).each do |ip|
        check(!Util.ip_version(ip).nil?, :ip_addresses, "#{ip} is not an IP address")
      end
    end
  end

  # Creates a child nameserver (glue record) such as ns1.example.com.
  # CLI: dna domain host add
  class DomainHostAddRequest < BaseRequest
    include HostAddresses

    endpoint :post, '/api/v1/domains/dns/host', safety: :write
    attribute :domain_name
    # The full host name, e.g. "ns1.example.com".
    attribute :host_name
    # IPv4 or IPv6 addresses; the version is detected.
    attribute :ip_addresses, default: []

    def body
      { 'domainName' => clean(domain_name), 'hostName' => clean(host_name), 'ipAddresses' => ip_address_items }
    end

    def validate
      required :domain_name
      required :host_name
      validate_ip_addresses
    end
  end

  # Changes a child nameserver's IP addresses, and optionally its name.
  # CLI: dna domain host update
  class DomainHostUpdateRequest < BaseRequest
    include HostAddresses

    endpoint :put, '/api/v1/domains/dns/host', safety: :write, idempotent: true
    attribute :domain_name
    attribute :host_name
    # Renames the host; nil keeps the name.
    attribute :new_host_name
    # The complete new list of addresses.
    attribute :ip_addresses, default: []

    def body
      { 'domainName' => clean(domain_name), 'hostName' => clean(host_name), 'ipAddresses' => ip_address_items }
        .merge(optional('newHostName' => new_host_name))
    end

    def validate
      required :domain_name
      required :host_name
      validate_ip_addresses
    end
  end

  # Deletes a child nameserver. CLI: dna domain host delete
  class DomainHostDeleteRequest < BaseRequest
    endpoint :delete, '/api/v1/domains/dns/host', safety: :destructive
    attribute :domain_name
    attribute :host_name

    def query
      params.string('DomainName', domain_name).string('HostName', host_name)
    end

    def validate
      required :domain_name
      required :host_name
    end
  end

  class DomainService < Service
    # Turns the transfer lock on.
    def lock(domain_name)
      call(DomainLockRequest.new(domain_name: domain_name))
      nil
    end

    # Turns the transfer lock off, which a transfer to another registrar needs.
    def unlock(domain_name)
      call(DomainUnlockRequest.new(domain_name: domain_name))
      nil
    end

    # Turns WHOIS privacy protection on or off. TLDs without privacy answer with
    # ErrorCode::PRIVACY_NOT_SUPPORTED.
    def set_privacy(domain_name, enabled)
      call(DomainPrivacyRequest.new(domain_name: domain_name, enabled: enabled))
      nil
    end

    # Asks the registry for a new transfer auth code and returns it. The current
    # code is in info(domain_name).auth_code.
    def update_auth_code(domain_name)
      call(DomainUpdateAuthCodeRequest.new(domain_name: domain_name)).auth_code
    end

    # Replaces the nameservers of a domain.
    #
    #   client.domains.set_name_servers('example.com', %w[ns1.example.net ns2.example.net])
    #   client.domains.set_name_servers('example.com', %w[ns1.other.net ns2.other.net], dnssec_mode: :disable)
    def set_name_servers(domain_name, name_servers, dnssec_mode: :block)
      call(DomainNameServersSetRequest.new(domain_name: domain_name, name_servers: name_servers,
                                           dnssec_mode: dnssec_mode))
      nil
    end

    # Creates a child nameserver such as ns1.example.com with one or more
    # IPv4/IPv6 addresses.
    #
    #   client.domains.add_host('example.com', 'ns1.example.com', '192.0.2.10', '2001:db8::10')
    def add_host(domain_name, host_name, *ip_addresses)
      call(DomainHostAddRequest.new(domain_name: domain_name, host_name: host_name,
                                    ip_addresses: ip_addresses.flatten))
      nil
    end

    # Changes a child nameserver's addresses, and its name with new_host_name.
    def update_host(domain_name, host_name, ip_addresses:, new_host_name: nil)
      call(DomainHostUpdateRequest.new(domain_name: domain_name, host_name: host_name,
                                       ip_addresses: Array(ip_addresses), new_host_name: new_host_name))
      nil
    end

    # Deletes a child nameserver.
    def delete_host(domain_name, host_name)
      call(DomainHostDeleteRequest.new(domain_name: domain_name, host_name: host_name))
      nil
    end
  end
end
