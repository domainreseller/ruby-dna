# frozen_string_literal: true

require 'uri'

module DomainNameApi
  # The URL forwarding of a domain.
  class Forwarding < Model
    # The target address.
    field :url, from: 'redirectAlias'
    field :type, ForwardType, from: 'redirectType'
  end

  # Reads the URL forwarding of a domain. CLI: dna domain forward get
  class DomainForwardGetRequest < BaseRequest
    endpoint :get, '/api/v1/domains/forwards', safety: :read
    returns Forwarding
    attribute :domain_name

    def query
      params.string('domainName', domain_name)
    end

    def validate
      required :domain_name
    end
  end

  # Forwards a domain to a URL. CLI: dna domain forward set
  class DomainForwardSetRequest < BaseRequest
    endpoint :post, '/api/v1/domains/forwards', safety: :write, idempotent: true
    attribute :domain_name
    # The target, e.g. "https://www.example.org".
    attribute :url
    # :standard (a 301 redirect, the default) or :frame (ForwardType).
    attribute :type, default: :standard

    def body
      { 'domainName' => clean(domain_name), 'redirectAddress' => clean(url),
        'forwardType' => (ForwardType[type] || ForwardType::STANDARD).value }
    end

    def validate
      required :domain_name
      required :url
      unless Util.blank?(url)
        uri = begin
          URI.parse(clean(url))
        rescue URI::InvalidURIError
          nil
        end
        check(uri && %w[http https].include?(uri.scheme) && !Util.blank?(uri.host), :url,
              'must be an http:// or https:// URL')
      end
      enum(:type, ForwardType)
    end
  end

  # Removes the URL forwarding of a domain. CLI: dna domain forward delete
  class DomainForwardDeleteRequest < BaseRequest
    endpoint :delete, '/api/v1/domains/forwards', safety: :destructive
    attribute :domain_name

    def query
      params.string('DomainName', domain_name)
    end

    def validate
      required :domain_name
    end
  end

  class DomainService < Service
    # The URL forwarding of a domain, or nil when it has none.
    def forwarding(domain_name)
      f = call(DomainForwardGetRequest.new(domain_name: domain_name))
      Util.blank?(f&.url) ? nil : f
    rescue APIError => e
      raise unless e.code?(ErrorCode::FORWARDING_NOT_FOUND)

      nil
    end

    # Forwards a domain with a redirect (:standard) or a frame (:frame).
    #
    #   client.domains.set_forwarding('example.com', 'https://www.example.org')
    def set_forwarding(domain_name, url, type: :standard)
      call(DomainForwardSetRequest.new(domain_name: domain_name, url: url, type: type))
      nil
    end

    # Removes the URL forwarding of a domain. Returns true, or false when the
    # domain had none.
    def delete_forwarding(domain_name)
      call(DomainForwardDeleteRequest.new(domain_name: domain_name))
      true
    rescue APIError => e
      raise unless e.code?(ErrorCode::FORWARDING_NOT_FOUND)

      false
    end
  end
end
