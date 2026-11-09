# frozen_string_literal: true

require 'json'

module DomainNameApi
  # PHP value semantics used by php-dna (empty(), casts, number_format(),
  # http_build_query(), ...). The library mirrors php-dna's results exactly,
  # so these helpers reproduce what PHP does rather than what Ruby would do.
  # Internal API.
  module Php
    module_function

    TRIM_CHARS = " \t\n\r\0\x0B"
    NUMERIC_RE = /\A[ \t\n\r\v\f]*[+-]?(\d+(\.\d*)?|\.\d+)([eE][+-]?\d+)?[ \t\n\r\v\f]*\z/.freeze
    LEADING_NUMERIC_RE = /\A[ \t\n\r\v\f]*[+-]?(\d+(\.\d*)?|\.\d+)([eE][+-]?\d+)?/.freeze

    # A PHP array: either a Ruby Hash (associative) or Array (list).
    def array?(value)
      value.is_a?(Hash) || value.is_a?(Array)
    end

    # PHP empty(): null, false, 0, 0.0, "", "0" and empty arrays.
    def empty?(value)
      case value
      when nil, false then true
      when Integer, Float then value.zero?
      when String then value.empty? || value == '0'
      when Hash, Array then value.empty?
      else false
      end
    end

    # PHP truthiness ((bool) cast).
    def truthy?(value)
      !empty?(value)
    end

    # $array[$key] with PHP's ?? semantics: nil when the container is not an
    # array or the key is absent. Several keys walk nested arrays.
    def get(container, *keys)
      keys.each do |key|
        container = fetch_one(container, key)
        return nil if container.nil?
      end
      container
    end

    def fetch_one(container, key)
      case container
      when Hash
        return container[key] if container.key?(key)

        skey = key.is_a?(Symbol) ? key.to_s : key
        return container[skey] if container.key?(skey)
        return container[key.to_s] if key.is_a?(Integer) && container.key?(key.to_s)
        return container[key.to_i] if key.is_a?(String) && key =~ /\A(0|-?[1-9]\d*)\z/ && container.key?(key.to_i)

        nil
      when Array
        index = if key.is_a?(Integer)
                  key
                elsif key.is_a?(String) && key =~ /\A(0|[1-9]\d*)\z/
                  key.to_i
                end
        index.nil? || index.negative? ? nil : container[index]
      end
    end

    # PHP isset($a[$k]...): present and not null.
    def isset?(container, *keys)
      !get(container, *keys).nil?
    end

    # foreach ($array as $v): the values of a Hash or Array.
    def values(value)
      case value
      when Hash then value.values
      when Array then value
      else []
      end
    end

    # foreach ($array as $k => $v) pairs; list indexes become integer keys.
    def pairs(value)
      case value
      when Hash then value.to_a
      when Array then value.each_with_index.map { |v, i| [i, v] }
      else []
      end
    end

    # (array) cast.
    def to_array(value)
      case value
      when nil then {}
      when Hash, Array then value
      else [value]
      end
    end

    # A Hash view of a PHP array (list indexes become string keys).
    def to_hash(value)
      case value
      when Hash then stringify_keys(value)
      when Array then value.each_with_index.to_h { |v, i| [i.to_s, v] }
      else {}
      end
    end

    # Deep copy with String keys (Ruby callers may pass Symbol keys).
    def stringify_keys(value)
      case value
      when Hash then value.each_with_object({}) { |(k, v), h| h[k.is_a?(Symbol) ? k.to_s : k] = stringify_keys(v) }
      when Array then value.map { |v| stringify_keys(v) }
      else value
      end
    end

    # (string) cast.
    def to_s(value)
      case value
      when nil, false then ''
      when true then '1'
      when String then value
      when Float then float_to_s(value)
      when Integer then value.to_s
      when Symbol then value.to_s
      when Hash, Array then 'Array'
      else value.to_s
      end
    end

    # (string) of a float, PHP 8 style (precision=14).
    def float_to_s(value)
      return 'NAN' if value.nan?
      return(value.positive? ? 'INF' : '-INF') if value.infinite?
      return '-0' if value.zero? && (1.0 / value).negative?
      return '0' if value.zero?

      str = format('%.14G', value)
      if str.include?('E')
        mantissa, exp = str.split('E')
        mantissa = mantissa.sub(/(\.\d*?)0+\z/, '\1').sub(/\.\z/, '')
        mantissa += '.0' unless mantissa.include?('.')
        sign = exp.start_with?('-') ? '-' : '+'
        "#{mantissa}E#{sign}#{exp.sub(/\A[+-]/, '').sub(/\A0+(?=\d)/, '')}"
      else
        str.include?('.') ? str.sub(/0+\z/, '').sub(/\.\z/, '') : str
      end
    end

    # (int) cast.
    def to_i(value)
      case value
      when nil, false then 0
      when true then 1
      when Integer then value
      when Float then value.nan? || value.infinite? ? 0 : value.truncate
      when String
        m = LEADING_NUMERIC_RE.match(value)
        return 0 unless m
        return m[0].strip.to_i if m[2].nil? && m[3].nil? && !m[0].include?('.')

        f = m[0].strip.to_f
        f.nan? || f.infinite? ? 0 : f.truncate
      when Hash, Array then value.empty? ? 0 : 1
      else 0
      end
    end

    # (float) cast.
    def to_f(value)
      case value
      when nil, false then 0.0
      when true then 1.0
      when Integer, Float then value.to_f
      when String
        m = LEADING_NUMERIC_RE.match(value)
        m ? m[0].strip.to_f : 0.0
      when Hash, Array then value.empty? ? 0.0 : 1.0
      else 0.0
      end
    end

    # is_numeric().
    def numeric?(value)
      case value
      when Integer, Float then true
      when String then NUMERIC_RE.match?(value)
      else false
      end
    end

    # trim() with PHP's default character list (or a custom one).
    def trim(value, chars = TRIM_CHARS)
      rtrim(ltrim(value, chars), chars)
    end

    def ltrim(value, chars = TRIM_CHARS)
      str = to_s(value)
      i = 0
      i += 1 while i < str.length && chars.include?(str[i])
      str[i..] || ''
    end

    def rtrim(value, chars = TRIM_CHARS)
      str = to_s(value)
      j = str.length
      j -= 1 while j.positive? && chars.include?(str[j - 1])
      str[0, j] || ''
    end

    # strtolower()/strtoupper()/ucfirst(): ASCII only, like PHP 8.
    def lower(value)
      to_s(value).downcase(:ascii)
    end

    def upper(value)
      to_s(value).upcase(:ascii)
    end

    def ucfirst(value)
      str = to_s(value)
      str.empty? ? str : str[0].upcase(:ascii) + str[1..]
    end

    # strcasecmp($a, $b) === 0
    def casecmp_eq?(a, b)
      lower(a) == lower(b)
    end

    # number_format($value, $decimals, '.', '')
    def number_format(value, decimals)
      f = to_f(value)
      return f.to_s if f.nan? || f.infinite?

      rounded = Rational(f.to_s.sub(/e/, 'E')).round(decimals, half: :up)
      negative = rounded.negative?
      rounded = rounded.abs
      scaled = (rounded * (10**decimals)).to_i
      int_part = scaled / (10**decimals)
      frac_part = scaled % (10**decimals)
      str = int_part.to_s
      str += ".#{frac_part.to_s.rjust(decimals, '0')}" if decimals.positive?
      negative && scaled.positive? ? "-#{str}" : str
    end

    # http_build_query($data): nulls skipped, true/false as 1/0, nested
    # arrays as key[0]=..., RFC 1738 encoding (space as +).
    def http_build_query(data, prefix = nil)
      parts = []
      pairs(data).each do |key, value|
        next if value.nil?

        name = prefix ? "#{prefix}[#{key}]" : key.to_s
        if array?(value)
          nested = http_build_query(value, name)
          parts << nested unless nested.empty?
        else
          parts << "#{urlencode(name)}=#{urlencode(query_scalar(value))}"
        end
      end
      parts.join('&')
    end

    def query_scalar(value)
      case value
      when true then '1'
      when false then '0'
      else to_s(value)
      end
    end

    # urlencode(): everything except [A-Za-z0-9_.-] is %XX, space is +.
    def urlencode(value)
      to_s(value).b.gsub(/[^A-Za-z0-9_.\-]/n) do |c|
        c == ' ' ? '+' : format('%%%02X', c.ord)
      end
    end

    # json_decode($body, true): nil for empty or invalid JSON.
    def json_decode(body)
      return nil unless body.is_a?(String)
      body = body.dup.force_encoding(Encoding::UTF_8) unless body.encoding == Encoding::UTF_8
      return nil unless body.valid_encoding?
      return nil if body.strip.empty?

      JSON.parse(body)
    rescue JSON::ParserError, EncodingError
      nil
    end

    # json_encode() of a value already built in PHP's shape.
    def json_encode(value)
      JSON.generate(value)
    rescue StandardError
      JSON.generate(scrub_utf8(value))
    end

    def scrub_utf8(value)
      case value
      when String then value.dup.force_encoding(Encoding::UTF_8).scrub("�")
      when Hash then value.each_with_object({}) { |(k, v), h| h[scrub_utf8(k)] = scrub_utf8(v) }
      when Array then value.map { |v| scrub_utf8(v) }
      else value
      end
    end

    # filter_var($ip, FILTER_VALIDATE_IP, FILTER_FLAG_IPV4)
    IPV4_OCTET = '(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)'
    IPV4_RE = /\A#{IPV4_OCTET}(\.#{IPV4_OCTET}){3}\z/.freeze

    def ipv4?(value)
      value.is_a?(String) || value.is_a?(Integer) ? IPV4_RE.match?(to_s(value)) : false
    end

    # filter_var($value, FILTER_VALIDATE_BOOLEAN)
    def filter_bool(value)
      %w[1 true on yes].include?(trim(value).downcase)
    end
  end
end
