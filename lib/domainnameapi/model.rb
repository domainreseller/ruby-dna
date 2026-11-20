# frozen_string_literal: true

module DomainNameApi
  # Base class of the data objects: what the API returns (Availability,
  # DomainInfo, ...) and what some requests take (Contact, DS, ...).
  #
  # A model declares its fields; each field has a snake_case reader (and writer)
  # and a JSON name, derived from the field name unless given:
  #
  #   class Expiry < DomainNameApi::Model
  #     field :domain_name                                # JSON "domainName"
  #     field :expiration_date, :time                     # a Time in UTC, or nil
  #     field :locked, :boolean, from: 'lockStatus'       # also defines locked?
  #   end
  #
  #   Expiry.new(domain_name: 'example.com')              # from Ruby
  #   Expiry.from_api('domainName' => 'example.com')      # from the API's JSON
  #
  # Field types: :string, :integer, :float, :boolean, :time, :attributes (a Hash
  # of Strings), :raw (JSON as it came), an Enum or Model subclass, or a
  # one-element Array of any of these for lists.
  #
  # Decoding is forgiving: a missing or null field is nil (lists are [],
  # booleans false, attributes {}); dates without a timezone, numbers sent as
  # strings, [] instead of {} and unknown enum values all decode. #raw keeps the
  # JSON object as received, for fields this gem does not model.
  class Model
    # A declared field. @api private
    Field = Struct.new(:name, :type, :from, :nullable) do
      def default
        return [] if type.is_a?(Array)
        return {} if type == :attributes
        return false if type == :boolean && !nullable

        nil
      end
    end

    class << self
      # Declares a field. See the class documentation.
      def field(name, type = :string, from: nil, nullable: false)
        name = name.to_sym
        f = Field.new(name, type, (from || Util.camelize(name)).to_s, nullable)
        own_fields[name] = f
        define_method(name) { instance_variable_get(:"@#{name}") }
        define_method(:"#{name}=") { |value| instance_variable_set(:"@#{name}", Types.cast(f.type, value, nullable: f.nullable)) }
        define_method(:"#{name}?") { instance_variable_get(:"@#{name}") ? true : false } if type == :boolean
        f
      end

      # All fields, including inherited ones, by name.
      def fields
        parent = superclass.respond_to?(:fields) ? superclass.fields : {}
        parent.merge(own_fields)
      end

      # Builds the model from a JSON object of the API. Anything that is not an
      # object gives nil.
      def from_api(data)
        return nil unless data.is_a?(Hash)

        item = allocate
        fields.each_value do |f|
          raw = data.key?(f.from) ? data[f.from] : data[f.name.to_s]
          item.instance_variable_set(:"@#{f.name}", Types.cast(f.type, raw, nullable: f.nullable, api: true))
        end
        item.instance_variable_set(:@raw, data)
        item
      end

      # Accepts the model itself, a Hash of its fields (symbol keys) or of the
      # API's JSON names (string keys), or nil.
      def coerce(value)
        case value
        when nil then nil
        when self then value
        when Hash
          value.keys.any? { |k| k.is_a?(Symbol) } ? new(**value.transform_keys(&:to_sym)) : from_api(value)
        else
          raise ArgumentError, "cannot use #{value.class} as #{name} (pass a #{name} or a Hash of its fields)"
        end
      end

      private

      def own_fields
        @own_fields ||= {}
      end
    end

    def initialize(**attributes)
      fields = self.class.fields
      unknown = attributes.keys.map(&:to_sym) - fields.keys
      unless unknown.empty?
        raise ArgumentError, "unknown #{unknown.size == 1 ? 'field' : 'fields'} #{unknown.map(&:inspect).join(', ')} " \
                             "for #{self.class.name} (fields: #{fields.keys.join(', ')})"
      end

      fields.each_value do |f|
        value = attributes.key?(f.name) ? attributes[f.name] : f.default
        instance_variable_set(:"@#{f.name}", Types.cast(f.type, value, nullable: f.nullable))
      end
      @raw = nil
    end

    # The JSON object this model was decoded from, or nil when built in Ruby.
    attr_reader :raw

    # The fields as a Hash with snake_case keys; nested models become Hashes too.
    def to_h
      self.class.fields.each_value.with_object({}) do |f, out|
        out[f.name] = plain(public_send(f.name))
      end
    end

    # The fields as the API's JSON object (camelCase keys), without nil values.
    def to_api
      self.class.fields.each_value.with_object({}) do |f, out|
        value = public_send(f.name)
        out[f.from] = Util.wire(value) unless value.nil?
      end
    end

    def to_json(*args)
      to_api.to_json(*args)
    end

    def ==(other)
      other.instance_of?(self.class) && other.to_h == to_h
    end
    alias eql? ==

    def hash
      [self.class, to_h].hash
    end

    def inspect
      parts = self.class.fields.each_key.filter_map do |name|
        value = public_send(name)
        next if value.nil? || value == [] || value == {} || value == false

        "#{name}=#{value.inspect}"
      end
      "#<#{self.class.name}#{parts.empty? ? '' : " #{parts.join(' ')}"}>"
    end
    alias to_s inspect

    private

    def plain(value)
      case value
      when Model then value.to_h
      when Array then value.map { |v| plain(v) }
      else value
      end
    end
  end

  # Conversion of JSON values to field types. @api private
  module Types
    module_function

    def cast(type, value, nullable: false, api: false)
      case type
      when Array then cast_list(type.first, value, api)
      when :string then cast_string(value)
      when :integer then Util.to_int(value)
      when :float then Util.to_float(value)
      when :boolean
        b = Util.to_bool(value)
        b.nil? && !nullable ? false : b
      when :time then Util.parse_time(value)
      when :attributes then Util.attributes(value)
      when :raw then value
      when Class
        if type <= Enum then type.decode(value)
        elsif type <= Model then api && value.is_a?(Hash) ? type.from_api(value) : type.coerce(value)
        else value
        end
      else value
      end
    end

    def cast_list(type, value, api)
      return [] if value.nil?

      list = value.is_a?(Array) ? value : [value]
      list.map { |v| cast(type, v, api: api) }.compact
    end

    def cast_string(value)
      case value
      when nil, String then value
      when Hash, Array then JSON.generate(value)
      else value.to_s
      end
    end

    # Decodes a response body for BaseRequest.returns.
    def decode(type, data)
      case type
      when nil then data
      when Array then cast_list(type.first, data.is_a?(Array) ? data : [], true)
      when Class
        # An empty body decodes to an empty model, so callers need no nil checks.
        cast(type, data.nil? && type <= Model ? {} : data, api: true)
      else cast(type, data, api: true)
      end
    end
  end

  # One page of a list endpoint. It is Enumerable over its items.
  #
  #   page = client.domains.list(limit: 50)
  #   page.total_count   # items across all pages
  #   page.each { |domain| ... }
  class Page < Model
    include Enumerable

    field :total_count, :integer

    class << self
      # The page class for an item type: Page.of(Domain).
      def of(item_class)
        @of ||= {}
        @of[item_class] ||= Class.new(Page) do
          field :items, [item_class]
          define_singleton_method(:item_class) { item_class }
          define_singleton_method(:name) { "DomainNameApi::Page[#{item_class.name.to_s.split('::').last}]" }
        end
      end

      def item_class
        nil
      end
    end

    def items
      @items || []
    end

    def each(&block)
      return enum_for(:each) unless block

      items.each(&block)
      self
    end

    def size
      items.size
    end
    alias length size

    def empty?
      items.empty?
    end
  end

  # The price of a product for one period.
  class Price < Model
    # Number of years.
    field :period, :integer
    # The amount.
    field :price, :float
    # ISO 4217 code, e.g. "USD".
    field :currency

    # "11.99 USD"
    def to_s
      format('%<price>.2f %<currency>s', price: price.to_f, currency: currency).strip
    end
  end
end
