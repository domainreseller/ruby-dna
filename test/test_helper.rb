# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path('../lib', __dir__)
require 'domainnameapi'
require 'minitest/autorun'
require 'json'
require 'uri'

# Test doubles and samples. No test talks to the real API.
module DnaTest
  RESELLER_ID = '00000000-0000-4000-8000-000000000001'
  API_KEY = 'test-api-key'

  # A transport that records requests and answers them in order with its
  # replies (repeating the last one). A reply is a Hash (:status, :body,
  # :headers) or an exception to raise.
  class FakeTransport
    attr_reader :requests

    def initialize(*replies)
      @replies = replies
      @requests = []
    end

    def call(request)
      @requests << request
      reply = @replies[@requests.size - 1] || @replies.last || { status: 200, body: '' }
      raise reply if reply.is_a?(Exception)
      raise reply.new('boom') if reply.is_a?(Class)

      DomainNameApi::HTTPResponse.new(status: reply[:status] || 200, headers: reply[:headers] || {},
                                      body: reply[:body].to_s)
    end

    def last
      raise Minitest::Assertion, 'no request reached the transport' if @requests.empty?

      @requests.last
    end

    def path(request = last)
      URI(request.url).path
    end

    def query(request = last)
      URI.decode_www_form(URI(request.url).query.to_s)
    end

    def query_hash(request = last)
      query(request).each_with_object({}) { |(k, v), h| (h[k] ||= []) << v }
    end

    def json(request = last)
      request.body.nil? ? nil : JSON.parse(request.body)
    end
  end

  module_function

  def ok(body = '')
    { status: 200, body: body.is_a?(String) ? body : JSON.generate(body) }
  end

  def status(code, body = '', headers = {})
    { status: code, body: body.is_a?(String) ? body : JSON.generate(body), headers: headers }
  end

  def api_error(status, code, message, data: [])
    { status: status,
      body: JSON.generate('error' => { 'code' => code, 'message' => message, 'details' => nil, 'data' => data,
                                       'validationErrors' => nil }) }
  end

  # A client for a FakeTransport, with pacing off and sleeping recorded
  # instead of done.
  def fake_client(*replies, **options)
    transport = FakeTransport.new(*replies)
    client = DomainNameApi::Client.new(reseller_id: RESELLER_ID, api_key: API_KEY, pacing: false,
                                       transport: transport, **options)
    sleeps = []
    client.define_singleton_method(:sleep_for) { |seconds| sleeps << seconds }
    client.define_singleton_method(:sleeps) { sleeps }
    [client, transport]
  end

  def sample_contact
    DomainNameApi::Contact.new(
      first_name: 'Ada', last_name: 'Lovelace', company_name: 'Example Ltd', email: 'ada@example.com',
      address: '1 Example Street', city: 'Istanbul', state: 'Istanbul', postal_code: '34000', country: 'TR',
      phone_country_code: '90', phone: '5551234567', fax_country_code: '90', fax: '2121234567', disclose_flag: false
    )
  end

  def sample_ssl_contact
    DomainNameApi::SSLContact.new(
      title: 'IT', first_name: 'Ada', last_name: 'Lovelace', company_name: 'Example Ltd', email: 'ada@example.com',
      address: '1 Example Street', city: 'Istanbul', state: 'Istanbul', postal_code: '34000', country: 'TR',
      phone_country_code: '90', phone: '5551234567', fax_country_code: '90', fax: '2121234567'
    )
  end
end
