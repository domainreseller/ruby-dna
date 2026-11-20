# frozen_string_literal: true

module DomainNameApi
  # A product of the catalogue.
  class Product < Model
    field :id
    field :parent_product_id
    field :name, from: 'productName'
    field :product_code
    field :entity_id
    field :product_type, ProductType
  end

  # The price of a product for one order type and period.
  class ProductInfo < Model
    # A sub-product and its prices.
    class Subproduct < Model
      field :parent_product_id
      field :name, from: 'productName'
      field :product_code
      field :product_type, ProductType
      field :entity_id
      field :buying_price, :float
      field :buying_currency
      field :selling_price, :float
      field :selling_currency
    end

    field :parent_product_id
    field :name, from: 'productName'
    field :product_code
    field :entity_id
    field :product_type, ProductType
    field :selling_price, :float
    field :selling_currency
    field :subproducts, [Subproduct]
  end

  # The prices of one price group of a TLD.
  class TLDPriceGroup < Model
    field :price_group
    field :register, [Price]
    field :renew, [Price]
    field :transfer, [Price]
    field :restore, Price
    field :refund, Price
    field :backorder, Price
  end

  # A registry attribute of a TLD.
  class TLDAttribute < Model
    # An allowed value.
    class Option < Model
      field :value
    end

    field :key
    field :description
    field :required, :boolean, from: 'isRequired'
    field :type
    field :options, [Option]
  end

  # A top-level domain you can sell: prices, periods, rules and the registry
  # attributes it needs.
  class TLD < Model
    # The TLD without the leading dot, e.g. "com" or "com.tr".
    field :name
    field :min_registration_period, :integer
    field :max_registration_period, :integer
    field :registration_periods, [:integer]
    field :renewal_periods, [:integer]
    # Grace and lifecycle periods, in days.
    field :add_grace_period, :integer
    field :auto_renew_grace_period, :integer
    field :finalization_period, :integer
    field :failure_period, :integer
    field :payment_period, :integer
    field :deletion_restorable_period, :integer
    field :deletion_hold_period, :integer
    field :transfer_period, :integer
    field :register_period, :integer
    field :renewal_period, :integer
    # Capabilities.
    field :supports_transfer, :boolean, from: 'isSupportTransfer'
    field :supports_idn, :boolean, from: 'isSupportIdn'
    field :requires_document, :boolean, from: 'isRequireDocument'
    field :supports_trustee, :boolean, from: 'isSupportTrustee'
    field :trustee_required, :boolean, from: 'isTrusteeRequired'
    field :sale_allowed, :boolean, from: 'isSaleAllowed'
    field :transfer_lock_possible, :boolean, from: 'isTransferLockPossible'
    field :handle_update_available, :boolean, from: 'isHandleUpdateAvailable'
    field :privacy_available, :boolean, from: 'isPrivacyAvailable'
    field :dnssec_available, :boolean, from: 'isDnssecAvailable'
    field :ipv6_available, :boolean, from: 'isIpv6Available'
    field :explicit_renewal_supported, :boolean, from: 'isExplicitRenewalSupported'
    field :available_in_test_environment, :boolean
    field :auth_code_required, :boolean, from: 'isRequiredAuthCode'
    field :registry_dns_check, :boolean, from: 'registryDnsCheck'
    field :transfer_check_supported, :boolean, from: 'isTransferCheckSupported'
    field :glue_record_allowed, :boolean, from: 'isGlueRecordAllowed'
    field :host_object_accepted, :boolean, from: 'isHostObjectAccepted'
    field :prices, [TLDPriceGroup]
    # The registry attributes; pass the required ones as tld_attributes when
    # registering.
    field :attributes, [TLDAttribute]

    # The registration Price for a period in years, or nil.
    def register_price(years = 1)
      price(:register, years)
    end

    # The renewal Price for a period in years, or nil.
    def renew_price(years = 1)
      price(:renew, years)
    end

    # The transfer Price for a period in years, or nil.
    def transfer_price(years = 1)
      price(:transfer, years)
    end

    # The attributes a registration must include.
    def required_attributes
      attributes.select(&:required?)
    end

    private

    def price(kind, years)
      prices.each do |group|
        found = group.public_send(kind).find { |p| p.period == years.to_i }
        return found if found
      end
      nil
    end
  end

  # An SSL certificate product.
  class SSLProduct < Model
    # The prices of one price group.
    class PriceGroup < Model
      field :price_group
      field :create, [Price]
    end

    field :name
    # The package code ssl.purchase takes.
    field :product_code
    field :vendor_name
    field :validation_type
    field :wildcard, :boolean, from: 'isWildcard'
    field :multi_domain, :boolean, from: 'isMultiDomain'
    field :default_san_count, :integer, from: 'defaultSanCount'
    field :max_san_count, :integer, from: 'maxSanCount'
    field :warranty_amount, :float
    field :issue_time_minutes, :integer
    field :reissue_free, :boolean, from: 'isReissueFree'
    field :requires_csr, :boolean, from: 'requiresCsr'
    field :prices, [PriceGroup]
  end

  # Lists products. CLI: dna product list
  class ProductListRequest < PagedRequest
    endpoint :get, '/api/v1/products', safety: :read
    returns Page.of(Product)
    attribute :filter_text
    # ProductType; nil for all.
    attribute :product_type

    def query
      params.string('FilterText', filter_text)
            .number('ProductType', ProductType[product_type]&.value)
            .page(skip: skip, limit: limit, sort: sort)
    end

    def validate
      super
      enum(:product_type, ProductType)
    end
  end

  # Reads the price of a product for an order type and period.
  # CLI: dna product info
  class ProductInfoRequest < BaseRequest
    endpoint :get, '/api/v1/products/info', safety: :read
    returns ProductInfo
    # A TLD without the dot ("com", "com.tr") or another product name.
    attribute :product_name
    # OrderType: :register, :renew, :transfer, ...
    attribute :order_type
    # The period in years.
    attribute :years

    def query
      params.string('ProductName', clean(product_name).delete_prefix('.'))
            .always('OrderType', OrderType[order_type]&.value)
            .always('Period', Util.to_int(years))
    end

    def validate
      required :product_name
      enum(:order_type, OrderType, required: true)
      check((Util.to_int(years) || 0).between?(1, 10), :years, 'must be between 1 and 10')
    end
  end

  # Lists TLDs with prices and rules. CLI: dna product tlds
  class TLDListRequest < PagedRequest
    endpoint :get, '/api/v1/products/tlds', safety: :read
    returns Page.of(TLD)
    # Keeps TLDs matching this text, e.g. "com.tr".
    attribute :filter_text
    # Currency of the prices; nil uses the client's currency: option or the account's.
    attribute :currency

    def query
      params.string('FilterText', filter_text).string('Currency', currency)
            .page(skip: skip, limit: limit, sort: sort)
    end
  end

  # Lists SSL certificate products. CLI: dna product ssls
  class SSLProductListRequest < PagedRequest
    endpoint :get, '/api/v1/products/ssls', safety: :read
    returns Page.of(SSLProduct)
    attribute :filter_text
    attribute :vendor_name
    # Currency of the prices; nil uses the client's or the account's.
    attribute :currency
    # The API's numeric validation type; nil for all.
    attribute :validation_type
    # Filter when set (true or false).
    attribute :wildcard
    attribute :multi_domain

    def query
      params.string('FilterText', filter_text).string('VendorName', vendor_name).string('Currency', currency)
            .number('ValidationType', validation_type)
            .boolean('IsWildcard', wildcard).boolean('IsMultiDomain', multi_domain)
            .page(skip: skip, limit: limit, sort: sort)
    end
  end

  # The catalogue: TLDs, SSL certificates and other products with your
  # prices. CLI: dna product
  class ProductService < Service
    # One page of products.
    def list(request = nil, **filters)
      call(build(ProductListRequest, request, filters))
    end

    # The price of a product for an order type and period, e.g. a 2-year .com
    # renewal:
    #
    #   client.products.info('com', order_type: :renew, years: 2)
    def info(product_name, order_type:, years: 1)
      call(ProductInfoRequest.new(product_name: product_name, order_type: order_type, years: years))
    end

    # One page of the TLD catalogue. Not rate limited; cache it rather than
    # asking for every search.
    def tlds(request = nil, **filters)
      req = build(TLDListRequest, request, filters)
      req.currency ||= client.currency
      call(req)
    end

    # The whole TLD catalogue, fetching pages as you go. Returns an Enumerator,
    # or iterates when given a block.
    def all_tlds(request = nil, **filters, &block)
      req = build(TLDListRequest, request, filters)
      req.currency ||= client.currency
      enum = paginate(req) { |r| call(r) }
      block ? enum.each(&block) : enum
    end

    # One TLD by name ("com.tr" or ".com.tr"), or nil when the catalogue does
    # not have it.
    #
    #   tld = client.products.tld('com.tr')
    #   tld.register_price(1).to_s     # => "12.50 USD"
    #   tld.required_attributes.map(&:key)
    def tld(name)
      wanted = name.to_s.strip.delete_prefix('.').downcase
      all_tlds(filter_text: wanted).find { |t| t.name.to_s.casecmp?(wanted) }
    end

    # One page of SSL certificate products.
    def ssls(request = nil, **filters)
      req = build(SSLProductListRequest, request, filters)
      req.currency ||= client.currency
      call(req)
    end
  end
end
