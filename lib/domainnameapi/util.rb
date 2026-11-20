# frozen_string_literal: true

require 'date'
require 'ipaddr'
require 'json'
require 'time'

module DomainNameApi
  # Helpers shared by requests and models. Not part of the public API.
  # @api private
  module Util
    module_function

    # nil, a blank string and an empty Array or Hash are blank; false and 0 are not.
    def blank?(value)
      case value
      when nil then true
      when String then value.strip.empty?
      when Array, Hash then value.empty?
      else false
      end
    end

    # The value as a stripped String ("" for nil).
    def clean(value)
      value.nil? ? '' : value.to_s.strip
    end

    # The values as stripped Strings, without blanks. A single value is a list of one.
    def clean_list(values)
      list = values.is_a?(Array) ? values.flatten : [values]
      list.map { |v| clean(v) }.reject(&:empty?)
    end

    # Keeps only the digits: "+90 (555) 123-45-67" becomes "905551234567".
    def digits(value)
      value.to_s.gsub(/[^0-9]/, '')
    end

    # :domain_name -> "domainName"; with upper: true -> "DomainName".
    def camelize(name, upper: false)
      parts = name.to_s.split('_')
      first = parts.shift.to_s
      first = first.capitalize if upper
      first + parts.map(&:capitalize).join
    end

    # "PendingDelete" -> "pending_delete"
    def underscore(name)
      name.to_s.gsub(/([A-Z\d]+)([A-Z][a-z])/, '\1_\2').gsub(/([a-z\d])([A-Z])/, '\1_\2').tr('-', '_').downcase
    end

    TIME_PATTERN = /\A(\d{4})-(\d{2})-(\d{2})
                    (?:[T\s](\d{2}):(\d{2})(?::(\d{2})(?:[.,](\d+))?)?)?
                    \s*(Z|[+-]\d{2}(?::?\d{2})?)?\z/ix.freeze

    # Parses the timestamps the API sends. It accepts ISO 8601 with or without an
    # offset ("2024-03-15T10:20:30" is read as UTC), with a space instead of the
    # "T", and plain dates. Missing, "0001-01-01T00:00:00" and unparseable values
    # give nil instead of an error. The result is in UTC.
    def parse_time(value)
      return value.getutc if value.is_a?(::Time)
      return ::Time.utc(value.year, value.month, value.day) if value.is_a?(::Date) && !value.is_a?(::DateTime)
      return value.to_time.getutc if value.is_a?(::DateTime)
      return nil unless value.is_a?(String)

      m = TIME_PATTERN.match(value.strip)
      return nil unless m

      year, month, day, hour, min, sec = m.captures[0, 6].map(&:to_i)
      return nil if year <= 1

      frac = m[7] ? Rational(m[7].to_i, 10**m[7].size) : 0
      ::Time.new(year, month, day, hour, min, sec + frac, zone_offset(m[8])).getutc
    rescue ArgumentError, RangeError
      nil
    end

    def zone_offset(zone)
      return '+00:00' if zone.nil? || zone.casecmp?('Z')

      number = zone[1..].delete(':')
      "#{zone[0]}#{number[0, 2]}:#{number[2, 2] || '00'}"
    end

    # RFC 3339 in UTC, the form query strings use.
    def format_time(value)
      time = parse_time(value)
      time&.strftime('%Y-%m-%dT%H:%M:%SZ')
    end

    def to_int(value)
      case value
      when Integer then value
      when Float then value.finite? ? value.to_i : nil
      when String
        s = value.strip
        return nil if s.empty?

        begin
          Integer(s, 10)
        rescue ArgumentError
          f = to_float(s)
          f&.to_i
        end
      end
    end

    def to_float(value)
      case value
      when Numeric then value.to_f
      when String
        begin
          Float(value.strip)
        rescue ArgumentError
          nil
        end
      end
    end

    TRUE_STRINGS = %w[true 1 yes on y].freeze

    def to_bool(value)
      case value
      when true, false then value
      when nil then nil
      when Numeric then !value.zero?
      when String then TRUE_STRINGS.include?(value.strip.downcase)
      else true
      end
    end

    # Registry attributes: an object of strings. null, [] and other shapes give {}.
    def attributes(value)
      return {} unless value.is_a?(Hash)

      value.each_with_object({}) do |(k, v), out|
        out[k.to_s] = case v
                      when nil then ''
                      when String then v
                      when Symbol then v.to_s
                      else JSON.generate(v)
                      end
      end
    end

    # :v4 or :v6 for an IP address, nil for anything else.
    def ip_version(value)
      s = value.to_s.strip
      return nil if s.empty? || s.include?('/') || s.include?('%')

      ip = IPAddr.new(s)
      ip.ipv4? || ip.ipv4_mapped? ? :v4 : :v6
    rescue IPAddr::Error, ArgumentError
      nil
    end

    # Turns a request body into plain JSON data: enums become their wire value,
    # models their API hash, times RFC 3339 strings and symbols strings.
    def wire(value)
      case value
      when Hash then value.each_with_object({}) { |(k, v), h| h[k.to_s] = wire(v) }
      when Array then value.map { |v| wire(v) }
      when Enum then value.value
      when Model then wire(value.to_api)
      when ::Time, ::Date then format_time(value)
      when Symbol then value.to_s
      else value
      end
    end

    # A copy of a hash without blank values, with strings stripped. Use it for
    # the optional keys of a request body; 0 counts as "not set", false does not.
    def compact(hash)
      hash.each_with_object({}) do |(k, v), out|
        next if v.nil? || (v.is_a?(Numeric) && v.zero?) || (v.respond_to?(:empty?) && blank?(v))

        out[k] = v.is_a?(String) ? v.strip : v
      end
    end

    def truncate(text, max = 16 * 1024)
      return text if text.nil? || text.bytesize <= max

      "#{text.byteslice(0, max).scrub('')}…(truncated)"
    end
  end
end
