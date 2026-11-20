# frozen_string_literal: true

require_relative 'test_helper'

class RequestTest < Minitest::Test
  include DomainNameApi
  include DnaTest

  # A request of your own, the way the README shows it.
  class NotesRequest < DomainNameApi::BaseRequest
    endpoint :post, '/api/v1/domains/{domain_name}/notes', safety: :write, idempotent: true
    attribute :domain_name
    attribute :note
    attribute :tags, default: []

    def body
      { 'note' => clean(note) }.merge(optional('tags' => clean_list(tags)))
    end

    def validate
      required :domain_name
      required :note
      max_length :note, 10
    end
  end

  class NotesListRequest < DomainNameApi::PagedRequest
    endpoint :get, '/api/v1/notes'
    attribute :domain_name

    def query
      params.string('DomainName', domain_name).page(skip: skip, limit: limit, sort: sort)
    end
  end

  class NoEndpointRequest < DomainNameApi::BaseRequest; end

  def test_attributes
    req = NotesRequest.new(domain_name: 'example.com', note: 'hi')
    assert_equal 'hi', req.note
    req.note = 'hello'
    assert_equal({ domain_name: 'example.com', note: 'hello', tags: [] }, req.to_h)
    refute_same NotesRequest.new.tags, NotesRequest.new.tags, 'defaults are copied'
    error = assert_raises(ArgumentError) { NotesRequest.new(domian_name: 'example.com') }
    assert_includes error.message, ':domian_name'
    assert_includes error.message, 'domain_name, note, tags'
    assert_includes req.inspect, 'NotesRequest POST /api/v1/domains/{domain_name}/notes'
  end

  def test_endpoint_and_path_template
    req = NotesRequest.new(domain_name: ' a b/c.com ', note: 'x')
    assert_equal '/api/v1/domains/a%20b%2Fc.com/notes', req.path
    assert_equal 'POST', req.http_method
    assert_equal :write, req.safety
    assert req.idempotent?
    refute req.billable?
    refute req.read?
    assert_equal 'POST /api/v1/domains/a%20b%2Fc.com/notes', req.endpoint.to_s
    assert NotesListRequest.new.read?
    assert NotesListRequest.new.idempotent?, 'reads are idempotent'
    assert_raises(NotImplementedError) { NoEndpointRequest.new.path }
    assert_raises(ArgumentError) { Class.new(BaseRequest) { endpoint :get, '/x', safety: :dangerous } }
  end

  def test_validation
    req = NotesRequest.new(note: 'far too long a note')
    refute req.valid?
    assert_equal ['domain_name: is required', 'note: must be at most 10 characters'], req.validation_errors.map(&:to_s)
    e = assert_raises(InputError) { req.validate! }
    assert_equal 'NotesRequest', e.request
    assert_same NotesRequest.new(domain_name: 'example.com', note: 'ok').then { |r| r.validate! && r }.class,
                NotesRequest

    raising = Class.new(BaseRequest) do
      endpoint :get, '/x'
      def validate
        raise ArgumentError, 'bad input'
      end
    end
    assert_equal ['bad input'], raising.new.validation_errors.map(&:to_s)
  end

  def test_paged_requests
    req = NotesListRequest.new(domain_name: 'example.com', skip: 10, limit: 5, sort: 'name')
    copy = req.with_page(skip: 20, limit: 50)
    assert_equal 10, req.skip
    assert_equal 20, copy.skip
    assert_equal 50, copy.limit
    assert_equal 'name', copy.sort
    assert_equal [%w[DomainName example.com], %w[SkipCount 20], %w[MaxResultCount 50], %w[Sorting name]],
                 Query.from(copy.query).to_a
    assert_equal ['skip: must not be negative', 'limit: must not be negative'],
                 NotesListRequest.new(skip: -1, limit: 'x').validation_errors.map(&:to_s)
  end

  def test_query_builder
    q = Query.new.string('A', ' x ').string('B', '').string('C', nil).number('D', 0).number('E', 2).number('F', 1.5)
             .boolean('G', false).boolean('H', nil).time('I', Time.utc(2026, 1, 2)).repeated('J', [1, 2, ' '])
             .joined('K', [DomainStatus::ACTIVE, DomainStatus::PENDING_DELETE]).always('L', '').string('M', ProductType::SSL)
    assert_equal [%w[A x], %w[E 2], %w[F 1.5], %w[G false], %w[I 2026-01-02T00:00:00Z], %w[J 1], %w[J 2], %w[K 0,7],
                  ['L', ''], %w[M 2]], q.to_a
    assert_equal 'x', q['A']
    assert q.key?('L')
    refute q.key?('B')
    assert_equal 'A=x&E=2', Query.new.string('A', 'x').number('E', 2).to_s

    assert_equal [%w[a 1], %w[b x], %w[b y], %w[e 0]],
                 Query.from('a' => 1, 'b' => %w[x y], 'c' => nil, 'e' => DomainStatus::ACTIVE).to_a
    assert_equal [%w[a 1]], Query.from([['a', 1]]).to_a
    assert Query.from(nil).empty?
    assert_raises(ArgumentError) { Query.from('a=1') }
  end

  def test_own_request_through_the_client
    client, api = fake_client(ok('{"saved":true}'))
    data = client.call(NotesRequest.new(domain_name: 'example.com', note: ' hi ', tags: ['a', ' ']))
    assert_equal({ 'saved' => true }, data)
    assert_equal '/api/v1/domains/example.com/notes', api.path
    assert_equal({ 'note' => 'hi', 'tags' => ['a'] }, api.json)

    client, api = fake_client(status(503), ok('{}'))
    client.call(NotesRequest.new(domain_name: 'example.com', note: 'hi'))
    assert_equal 2, api.requests.size, 'an idempotent write of your own is retried'
  end

  def test_body_conversion
    req = Class.new(BaseRequest) do
      endpoint :post, '/x', safety: :write
      def body
        { status: DomainStatus::ACTIVE, at: Time.utc(2026, 1, 1), price: Price.new(period: 1, currency: 'USD'),
          kind: :a, list: [RecordType::TXT] }
      end
    end
    client, api = fake_client(ok)
    client.call(req.new)
    assert_equal({ 'status' => 0, 'at' => '2026-01-01T00:00:00Z', 'price' => { 'period' => 1, 'currency' => 'USD' },
                   'kind' => 'a', 'list' => ['TXT'] }, api.json)
  end

  def test_compact
    assert_equal({ 'a' => 'x', 'f' => false, 'n' => 2 },
                 Util.compact('a' => ' x ', 'b' => ' ', 'c' => nil, 'd' => 0, 'e' => [], 'f' => false, 'n' => 2,
                              'h' => {}))
    assert_equal({ 'mode' => DNSSECMode::BLOCK }, Util.compact('mode' => DNSSECMode::BLOCK), 'enums are kept')
  end
end
