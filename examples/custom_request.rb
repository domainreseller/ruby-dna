# frozen_string_literal: true

# Custom request: send a request class of your own through the client.
#
# Every operation of the gem is a subclass of DomainNameApi::BaseRequest. Yours
# can be too: declare the endpoint and attributes, override query, body or
# validate when needed, and send it with client.call. You get the client's
# credentials, retries, pacing, error handling, tracing and read-only mode.
#
#   ruby examples/custom_request.rb example.com
$LOAD_PATH.unshift File.expand_path('../lib', __dir__)
require 'domainnameapi'

# The part of the domain record this program needs.
class Expiry < DomainNameApi::Model
  field :domain_name
  field :expiration_date, :time
  field :remaining_days, :integer, from: 'remainingDay'
end

# Reads only the expiry fields of a domain.
class ExpiryRequest < DomainNameApi::BaseRequest
  endpoint :get, '/api/v1/domains/info', safety: :read
  returns Expiry
  attribute :domain_name

  def query
    params.string('DomainName', domain_name)
  end

  def validate
    required :domain_name
  end
end

domain = ARGV[0] || 'example.com'
trace = lambda do |event|
  next unless event.response?

  outcome = event.error ? event.error.class : event.status
  warn "#{event.http_method} #{event.url} -> #{outcome} in #{(event.duration * 1000).round} ms"
end
client = DomainNameApi::Client.from_env(on_trace: trace)

p client.prepare(ExpiryRequest.new(domain_name: domain)) # what would be sent; the API key is masked
expiry = client.call(ExpiryRequest.new(domain_name: domain))
puts "#{expiry.domain_name} expires #{expiry.expiration_date} (#{expiry.remaining_days} days)"
