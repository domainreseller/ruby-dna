# frozen_string_literal: true

module DomainNameApi
  # Base class of the enums: named values the API sends as numbers
  # (DomainStatus, DocumentType, ...) or as fixed strings (RecordType,
  # ContactType, ...).
  #
  # Each member is a constant, has a predicate and compares with its symbol,
  # its name and its number:
  #
  #   status = domain.status            # => #<DomainNameApi::DomainStatus PendingDelete (7)>
  #   status.pending_delete?            # => true
  #   status == DomainNameApi::DomainStatus::PENDING_DELETE
  #   status == :pending_delete         # => true
  #   status.to_s                       # => "PendingDelete"
  #   status.to_i                       # => 7
  #   DomainNameApi::DomainStatus[:active]       # lookup, nil when unknown
  #   DomainNameApi::DomainStatus.parse('7')     # lookup, raises ArgumentError when unknown
  #
  # Requests accept members, symbols, names in any case and numbers. Values
  # this gem does not know yet still decode (#known? is false).
  class Enum
    # The member's symbol, e.g. :pending_delete (nil for unknown values).
    attr_reader :key
    # The API's name, e.g. "PendingDelete".
    attr_reader :name
    # The value sent on the wire: an Integer for numeric enums, a String otherwise.
    attr_reader :value
    # A short explanation, or nil.
    attr_reader :description

    class << self
      # Defines a member: a constant (KEY), a predicate (key?) and a lookup entry.
      def member(key, value, name: nil, aliases: [], description: nil)
        name ||= value.is_a?(String) ? value : Util.camelize(key, upper: true)
        item = allocate
        item.send(:setup, key, value, name, aliases, description, true)
        own_members << item
        const_set(key.to_s.upcase, item)
        define_method(:"#{key}?") { known? && self.key == key }
        item
      end

      # All members, in definition order.
      def members
        own_members.dup.freeze
      end
      alias values members

      # The member for an input (member, symbol, name in any case, alias or
      # number), or nil.
      def [](input)
        return input if input.is_a?(self) && input.known?
        return nil if input.nil?

        if input.is_a?(Numeric)
          int = input.to_i
          return int == input ? own_members.find { |m| m.value == int } : nil
        end

        text = normalize(input)
        return nil if text.empty?

        own_members.find { |m| m.match?(text) } ||
          (text.match?(/\A-?\d+\z/) ? own_members.find { |m| m.value == text.to_i } : nil)
      end

      # Like #[], but raises ArgumentError for an unknown input.
      def parse(input)
        self[input] || raise(ArgumentError, "#{input.inspect} is not a valid #{short_name} (allowed: #{allowed})")
      end

      # Decodes a value from the API: the member, or an unknown value that keeps
      # what the API sent.
      def decode(raw)
        return nil if raw.nil? || (raw.is_a?(String) && raw.strip.empty?)
        return raw if raw.is_a?(self)

        self[raw] || unknown(raw)
      end

      # A value this gem has no member for.
      def unknown(raw)
        raw = raw.to_i if raw.is_a?(Float) && raw.finite? && raw == raw.to_i
        raw = raw.strip.to_i if raw.is_a?(String) && raw.strip.match?(/\A-?\d+\z/)
        item = allocate
        item.send(:setup, nil, raw, nil, [], nil, false)
        item
      end

      # The member names, for error messages.
      def allowed
        own_members.map(&:name).join(', ')
      end

      def short_name
        name.to_s.split('::').last
      end

      # @api private
      def normalize(input)
        input.to_s.strip.downcase.delete('_ -')
      end

      private

      def own_members
        @own_members ||= []
      end
    end

    # Whether this gem knows the value.
    def known?
      @known
    end

    # The name, e.g. "PendingDelete"; for unknown values what the API sent.
    def to_s
      return name if known?

      value.is_a?(String) ? value : "#{self.class.short_name}(#{value})"
    end

    def to_i
      value.is_a?(Integer) ? value : value.to_s.to_i
    end

    def to_sym
      key || to_s.to_sym
    end

    # Compares with members and with anything #[] accepts.
    def ==(other)
      case other
      when Enum then other.instance_of?(self.class) && other.value == value
      when Integer, String, Symbol
        member = self.class[other]
        member ? member.value == value : (!known? && other == value)
      else false
      end
    end

    def eql?(other)
      other.instance_of?(self.class) && other.value == value
    end

    def hash
      [self.class, value].hash
    end

    def inspect
      return "#<#{self.class.name} #{name}>" if known? && value == name
      return "#<#{self.class.name} #{name} (#{value})>" if known?

      "#<#{self.class.name} unknown #{value.inspect}>"
    end

    # The wire value, so enums can go straight into a JSON body.
    def as_json(*)
      value
    end

    def to_json(*args)
      value.to_json(*args)
    end

    # @api private
    def match?(text)
      @match.include?(text)
    end

    private

    def setup(key, value, name, aliases, description, known)
      @key = key
      @value = value
      @name = name
      @description = description
      @known = known
      @match = ([key, name] + aliases).compact.map { |a| self.class.normalize(a) }
      @match << self.class.normalize(value) if value.is_a?(String)
      @match.uniq!
      freeze
    end
  end
end
