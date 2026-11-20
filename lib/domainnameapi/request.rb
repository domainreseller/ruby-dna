# frozen_string_literal: true

require 'uri'

module DomainNameApi
  # What a request does to your account. The client uses it to decide what may
  # be retried and what read-only mode blocks; it matches the dna CLI.
  module Safety
    # No side effects, even when the method is POST or PUT (domain search is a
    # POST, the SSL status check a PUT).
    READ = :read
    # Changes something, free of charge and reversibly.
    WRITE = :write
    # Deletes something or is hard to undo.
    DESTRUCTIVE = :destructive
    # Charges the reseller balance.
    BILLABLE = :billable

    ALL = [READ, WRITE, DESTRUCTIVE, BILLABLE].freeze
  end

  # Where a request goes and what kind of request it is.
  Endpoint = Struct.new(:http_method, :path, :safety, :idempotent, keyword_init: true) do
    # Whether the request is safe to send again after a network error or a
    # 502/503/504 answer. Reads always are; other requests only when declared so.
    def idempotent?
      safety == Safety::READ || idempotent == true
    end

    def to_s
      "#{http_method} #{path}"
    end
  end

  # Collects the problems of a request or model during validation.
  class Validator
    attr_reader :errors

    def initialize
      @errors = []
    end

    def add(field, message)
      @errors << FieldError.new(field.to_s, message.to_s)
      self
    end

    def check(ok, field, message)
      add(field, message) unless ok
      self
    end

    def required(field, value)
      check(!Util.blank?(value), field, 'is required')
    end

    def required_list(field, values)
      check(!Util.clean_list(values).empty?, field, 'needs at least one value')
    end

    # Checks an optional number: nil and 0 mean "not set" and pass.
    def between(field, value, min, max)
      return self if value.nil? || value == 0

      n = Util.to_int(value)
      check(!n.nil? && n.between?(min, max), field, "must be between #{min} and #{max}")
    end

    def max_length(field, value, max)
      check(value.to_s.length <= max, field, "must be at most #{max} characters")
    end

    def empty?
      @errors.empty?
    end

    def any?
      !empty?
    end
  end

  # A query string under construction. Blank values are skipped, so the API
  # sees only what the caller set.
  #
  #   query.string('DomainName', domain_name).number('MaxResultCount', limit)
  class Query
    include Enumerable

    def initialize(pairs = [])
      @pairs = pairs.dup
    end

    # Adds a stripped string; skips nil and blanks.
    def string(key, value)
      text = Util.clean(value.is_a?(Enum) ? value.value : value)
      @pairs << [key.to_s, text] unless text.empty?
      self
    end

    # Adds a number; skips nil and 0.
    def number(key, value)
      value = value.value if value.is_a?(Enum)
      n = value.is_a?(Float) ? value : Util.to_float(value)
      return self if n.nil? || n.zero?

      @pairs << [key.to_s, n == n.to_i ? n.to_i.to_s : n.to_s]
      self
    end

    # Adds true or false; skips nil.
    def boolean(key, value)
      @pairs << [key.to_s, value ? 'true' : 'false'] unless value.nil?
      self
    end

    # Adds a Time, Date or ISO 8601 string as RFC 3339 in UTC; skips nil.
    def time(key, value)
      text = Util.format_time(value)
      @pairs << [key.to_s, text] if text
      self
    end

    # Adds the key once per value: TransactionTypes=1&TransactionTypes=2.
    def repeated(key, values)
      Util.clean_list(wire_list(values)).each { |v| @pairs << [key.to_s, v] }
      self
    end

    # Adds the values as one comma-separated value: StatusIds=0,7.
    def joined(key, values)
      list = Util.clean_list(wire_list(values))
      @pairs << [key.to_s, list.join(',')] unless list.empty?
      self
    end

    # Adds the value even when it is blank.
    def always(key, value)
      @pairs << [key.to_s, value.is_a?(Enum) ? value.value.to_s : value.to_s]
      self
    end

    # The paging parameters of list endpoints.
    def page(skip: nil, limit: nil, sort: nil)
      number('SkipCount', skip).number('MaxResultCount', limit).string('Sorting', sort)
    end

    def each(&block)
      @pairs.each(&block)
    end

    def to_a
      @pairs.dup
    end

    # The first value of a key, or nil.
    def [](key)
      pair = @pairs.find { |k, _| k == key.to_s }
      pair&.last
    end

    def key?(key)
      @pairs.any? { |k, _| k == key.to_s }
    end

    def empty?
      @pairs.empty?
    end

    def to_s
      URI.encode_www_form(@pairs)
    end

    # Normalises what BaseRequest#query may return: a Query, a Hash (Array values
    # become repeated keys, nil values are dropped) or an Array of pairs.
    # @api private
    def self.from(value)
      case value
      when nil then new
      when Query then value
      when Hash
        pairs = value.each_with_object([]) do |(k, v), out|
          Array(v).each { |item| out << [k.to_s, item.is_a?(Enum) ? item.value.to_s : item.to_s] unless item.nil? }
        end
        new(pairs)
      when Array then new(value.map { |k, v| [k.to_s, v.to_s] })
      else raise ArgumentError, "a query must be a Query, a Hash or an Array of pairs, not #{value.class}"
      end
    end

    private

    def wire_list(values)
      (values.is_a?(Array) ? values : [values]).map { |v| v.is_a?(Enum) ? v.value : v }
    end
  end

  # Base class of every request.
  #
  # A request knows where it goes (#endpoint), its query string (#query), its
  # JSON body (#body), how to check itself (#validate) and how to read the answer
  # (#decode). Every operation of this gem is a subclass, named after the dna CLI
  # command: `dna domain renew` is DomainRenewRequest. Subclass it yourself to call
  # an endpoint this gem does not wrap yet, or to read only the fields you need:
  #
  #   class ExpiryRequest < DomainNameApi::BaseRequest
  #     endpoint :get, '/api/v1/domains/info', safety: :read
  #     attribute :domain_name
  #
  #     def query
  #       params.string('DomainName', domain_name)
  #     end
  #
  #     def validate
  #       required :domain_name
  #     end
  #   end
  #
  #   data = client.call(ExpiryRequest.new(domain_name: 'example.com'))
  #   data['expirationDate']
  #
  # The client validates the request before sending it (nothing is sent when
  # validation fails) and adds credentials, retries, pacing, correlation IDs,
  # tracing and read-only enforcement.
  #
  # The wire format lives in #query and #body: attributes are Ruby-friendly
  # (snake_case, symbols for enums), the query and body use the API's names.
  class BaseRequest
    class << self
      # Declares the method, the path below the base URL and the safety class.
      # The path may contain {attribute} placeholders, filled in (and escaped)
      # from the attributes: '/api/v1/contacts/{handle}'.
      #
      # Set idempotent: true only when sending the request twice is harmless
      # (setting the same nameservers twice gives the same result).
      def endpoint(http_method = nil, path = nil, safety: Safety::READ, idempotent: false)
        if http_method.nil?
          return @endpoint if defined?(@endpoint) && @endpoint

          return superclass.respond_to?(:endpoint) ? superclass.endpoint : nil
        end
        unless Safety::ALL.include?(safety)
          raise ArgumentError, "unknown safety #{safety.inspect} (use one of #{Safety::ALL.map(&:inspect).join(', ')})"
        end

        @endpoint = { http_method: http_method.to_s.upcase, path: path.to_s, safety: safety,
                      idempotent: idempotent }.freeze
      end

      # Declares an attribute: a reader, a writer and a keyword of #initialize.
      # A default that is an Array or Hash is copied for every request.
      def attribute(name, default: nil)
        name = name.to_sym
        own_attributes[name] = default
        attr_accessor name
        name
      end

      # The attribute names and defaults, including inherited ones.
      def attributes
        parent = superclass.respond_to?(:attributes) ? superclass.attributes : {}
        parent.merge(own_attributes)
      end

      # Declares how a successful answer is decoded: a Model subclass, a
      # one-element Array of one ([RecordSet]), Page.of(Domain), or nil to keep
      # the parsed JSON (the default).
      def returns(type = :__none__)
        if type == :__none__
          return @returns if defined?(@returns)

          return superclass.respond_to?(:returns) ? superclass.returns : nil
        end
        @returns = type
      end

      # The class name without the module, e.g. "DomainRenewRequest".
      def request_name
        name.to_s.split('::').last || 'request'
      end

      private

      def own_attributes
        @own_attributes ||= {}
      end
    end

    def initialize(**attributes)
      known = self.class.attributes
      known.each do |name, default|
        value = default.is_a?(Array) || default.is_a?(Hash) ? default.dup : default
        instance_variable_set(:"@#{name}", value)
      end
      attributes.each do |name, value|
        unless known.key?(name.to_sym)
          raise ArgumentError, "unknown attribute #{name.inspect} for #{self.class.request_name} " \
                               "(attributes: #{known.keys.join(', ')})"
        end
        public_send(:"#{name}=", value)
      end
    end

    # The HTTP method: "GET", "POST", "PUT" or "DELETE".
    def http_method
      definition[:http_method]
    end

    # The path below the base URL, with placeholders filled in and escaped.
    def path
      definition[:path].gsub(/\{(\w+)\}/) do
        URI.encode_www_form_component(Util.clean(public_send(Regexp.last_match(1)))).gsub('+', '%20')
      end
    end

    # One of the Safety values.
    def safety
      definition[:safety]
    end

    # Whether the request may be sent again after a network error or a 5xx.
    def idempotent?
      endpoint.idempotent?
    end

    def read?
      safety == Safety::READ
    end

    def billable?
      safety == Safety::BILLABLE
    end

    def destructive?
      safety == Safety::DESTRUCTIVE
    end

    # The Endpoint of this request.
    def endpoint
      Endpoint.new(http_method: http_method, path: path, safety: safety, idempotent: definition[:idempotent])
    end

    # The query string parameters: a Query (see #params), a Hash, an Array of
    # pairs or nil. None by default.
    def query
      nil
    end

    # The JSON body: a Hash or Array with the API's names, or nil for none
    # (the default). Enums, models and times in it are converted for you.
    def body
      nil
    end

    # Checks the request before it is sent. Override it and report problems with
    # the helpers (#required, #check, #between, ...). Nothing is sent when it
    # reports any.
    def validate; end

    # Decodes the parsed JSON of a successful answer (see .returns).
    def decode(data)
      Types.decode(self.class.returns, data)
    end

    # Runs #validate and raises InputError when it reports problems.
    def validate!
      errors = validation_errors
      raise InputError.new(self.class.request_name, errors) unless errors.empty?

      self
    end

    def valid?
      validation_errors.empty?
    end

    # The problems #validate reports, as FieldError values.
    def validation_errors
      @validator = Validator.new
      begin
        validate
      rescue ArgumentError => e
        @validator.add('', e.message)
      end
      @validator.errors
    ensure
      remove_instance_variable(:@validator) if instance_variable_defined?(:@validator)
    end

    # The attributes as a Hash.
    def to_h
      self.class.attributes.each_key.with_object({}) { |name, out| out[name] = public_send(name) }
    end

    def inspect
      parts = to_h.reject { |_, v| v.nil? || v == [] || v == {} }.map { |k, v| "#{k}=#{v.inspect}" }
      "#<#{self.class.request_name} #{http_method} #{definition[:path]}#{parts.empty? ? '' : " #{parts.join(' ')}"}>"
    end

    private

    def definition
      self.class.endpoint || raise(NotImplementedError,
                                   "#{self.class.request_name} has no endpoint: declare one with `endpoint :get, '/api/v1/...'`")
    end

    # --- helpers for #query and #body ------------------------------------

    # A new Query.
    def params
      Query.new
    end

    # The optional keys of a body: drops nil, blank strings, 0 and empty lists,
    # strips strings. Merge it into the keys that are always sent.
    def optional(hash)
      Util.compact(hash)
    end

    def clean(value)
      Util.clean(value)
    end

    def clean_list(values)
      Util.clean_list(values)
    end

    # The body of the many requests that only name a domain.
    def domain_body
      { 'domainName' => clean(domain_name) }
    end

    # --- helpers for #validate -------------------------------------------

    def validator
      @validator ||= Validator.new
    end

    # Reports field as missing when its value is blank. The value defaults to
    # the attribute of that name.
    def required(field, value = public_send(field))
      validator.required(field, value)
    end

    # Reports field when the list has no non-blank value.
    def required_list(field, values = public_send(field))
      validator.required_list(field, values)
    end

    # Reports message for field unless ok.
    def check(ok, field, message)
      validator.check(ok, field, message)
    end

    # Reports message for field.
    def invalid(field, message)
      validator.add(field, message)
    end

    # Reports field when an optional number is outside min..max (nil and 0 pass).
    def between(field, min, max, value = public_send(field))
      validator.between(field, value, min, max)
    end

    def max_length(field, max, value = public_send(field))
      validator.max_length(field, value, max)
    end

    # Reports field when value is not a member of enum_class (nil passes unless required).
    def enum(field, enum_class, value = public_send(field), required: false)
      if value.nil? || (value.is_a?(String) && value.strip.empty?)
        invalid(field, 'is required') if required
        return
      end
      check(!enum_class[value].nil?, field, "must be one of #{enum_class.allowed}")
    end
  end

  # Base class of list requests that return one page at a time. Choose the page
  # with skip and limit, or let a service page for you (domains.all,
  # account.all_transactions, products.all_tlds).
  class PagedRequest < BaseRequest
    # The page size the all_* iterators ask for when limit is not set.
    DEFAULT_PAGE_SIZE = 100

    # Number of items to skip (SkipCount).
    attribute :skip
    # Page size (MaxResultCount); nil uses the API default.
    attribute :limit
    # Sort expression such as "expirationDate desc" (Sorting).
    attribute :sort

    # A copy of the request for another page; the original is not changed.
    def with_page(skip:, limit:)
      copy = dup
      copy.skip = skip
      copy.limit = limit
      copy
    end

    private

    # The paging parameters, for #query.
    def page_params
      params.page(skip: skip, limit: limit, sort: sort)
    end

    # Checks the paging attributes; call it from #validate.
    def validate_page
      check(skip.nil? || (Util.to_int(skip) || -1) >= 0, :skip, 'must not be negative')
      check(limit.nil? || (Util.to_int(limit) || -1) >= 0, :limit, 'must not be negative')
    end

    public

    def validate
      validate_page
    end
  end
end
