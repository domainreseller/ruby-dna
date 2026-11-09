# frozen_string_literal: true

require_relative 'test_helper'

# Runs every php-dna conformance fixture (test/fixtures/conformance/*.json):
# same requests on the wire, same return value. See php-dna conformance/README.md.
class ConformanceTest < Minitest::Test
  include DnaTestSupport

  FIXTURE_DIR = File.expand_path('fixtures/conformance', __dir__)
  BASE_URL = 'https://api.domainresellerapi.com/api/v1/'

  def self.snake(name)
    name.gsub(/([a-z\d])([A-Z])/, '\1_\2').downcase
  end

  Dir[File.join(FIXTURE_DIR, '*.json')].sort.each do |path|
    fixture = JSON.parse(File.read(path, encoding: 'UTF-8'))
    define_method("test_#{fixture['id'].gsub(/[^A-Za-z0-9]+/, '_')}") { run_fixture(fixture) }
  end

  def test_all_fixtures_present
    assert_equal 126, Dir[File.join(FIXTURE_DIR, '*.json')].size
  end

  private

  def run_fixture(fixture)
    transport = FakeTransport.new(fixture['responses'].map { |r| { status: r['status'], body: r['body'] } })
    client = new_client(transport)
    method = self.class.snake(fixture['call']).sub('is_tr_t_l_d', 'is_tr_tld')
    assert client.respond_to?(method), "client does not implement #{method}"

    output = client.public_send(method, *fixture['args'])

    assert_equal 0, transport.remaining, "#{fixture['id']}: not every response was consumed"
    assert_equal fixture['requests'].size, transport.requests.size, "#{fixture['id']}: request count"
    fixture['requests'].each_with_index do |expected, i|
      compare_request(fixture['id'], i, expected, transport.requests[i])
    end

    actual = JSON.parse(JSON.generate(output))
    expected = fixture['output']
    fixture['ignore'].each do |dot_path|
      value = dig_path(actual, dot_path)
      assert value.is_a?(Integer) && value >= 0, "#{fixture['id']}: #{dot_path} must be a non-negative integer, got #{value.inspect}"
      set_path(actual, dot_path, nil)
      set_path(expected, dot_path, nil)
    end
    assert same?(expected, actual),
           "#{fixture['id']}: output differs\nexpected: #{JSON.generate(expected)}\nactual:   #{JSON.generate(actual)}"
  end

  def compare_request(id, index, expected, actual)
    label = "#{id} request ##{index}"
    assert_equal expected['method'], actual[:method], "#{label}: method"
    url = actual[:url]
    assert url.start_with?(BASE_URL), "#{label}: url #{url}"
    path, query = url[BASE_URL.size..].split('?', 2)
    assert_equal expected['path'], path, "#{label}: path"
    assert same?(expected['query'], parse_query(query)),
           "#{label}: query\nexpected: #{expected['query'].inspect}\nactual:   #{parse_query(query).inspect}"
    body = actual[:body].nil? ? nil : JSON.parse(actual[:body])
    assert same?(expected['body'], body),
           "#{label}: body\nexpected: #{JSON.generate(expected['body'])}\nactual:   #{JSON.generate(body)}"
    expected['headers'].each do |name, value|
      assert_equal value, actual[:headers][name], "#{label}: header #{name}"
    end
    assert_equal "DomainNameAPI-Ruby/#{DomainNameApi::VERSION}", actual[:headers]['User-Agent']
  end

  # Comparison rules from conformance/README.md: [] equals {}, numbers by value.
  def same?(a, b)
    return true if empty_collection?(a) && empty_collection?(b)

    case a
    when Hash
      b.is_a?(Hash) && a.keys.sort == b.keys.sort && a.all? { |k, v| same?(v, b[k]) }
    when Array
      b.is_a?(Array) && a.size == b.size && a.each_with_index.all? { |v, i| same?(v, b[i]) }
    when Numeric
      b.is_a?(Numeric) && a == b
    else
      a == b
    end
  end

  def empty_collection?(value)
    (value.is_a?(Hash) || value.is_a?(Array)) && value.empty?
  end

  def dig_path(node, dot_path)
    dot_path.split('.').reduce(node) { |n, k| n.is_a?(Array) ? n[k.to_i] : n&.fetch(k, nil) }
  end

  def set_path(node, dot_path, value)
    *parents, last = dot_path.split('.')
    target = parents.reduce(node) { |n, k| n.is_a?(Array) ? n[k.to_i] : n[k] }
    target.is_a?(Array) ? target[last.to_i] = value : target[last] = value
  end
end
