# frozen_string_literal: true

# Register a domain: search, create a contact handle, register with it.
# This charges your balance in production, so it only runs against OTE.
#
#   DNA_ENV=ote ruby examples/register.rb example-sdk-test.com
$LOAD_PATH.unshift File.expand_path('../lib', __dir__)
require 'domainnameapi'

domain = ARGV[0] || 'example-sdk-test.com'
client = DomainNameApi::Client.from_env
abort 'Refusing to register in production from an example; set DNA_ENV=ote.' unless client.ote?

a = client.domains.search(domain)
abort "#{domain} is not available: #{a.status} #{a.reason}" unless a.available?
puts "#{domain}: #{a.price} #{a.currency}"

owner = DomainNameApi::Contact.new(
  first_name: 'Ada', last_name: 'Lovelace', email: 'ada@example.com',
  address: '1 Example Street', city: 'Istanbul', state: 'Istanbul', postal_code: '34000',
  country: 'TR', phone_country_code: '+90', phone: '(555) 123 45 67'
)
handle = client.contacts.create(owner)
puts "contact handle: #{handle}"

begin
  result = client.domains.register(
    domain_name: domain, years: 1,
    name_servers: %w[ns1.example.net ns2.example.net],
    handles: DomainNameApi::ContactHandles.same(handle)
  )
  puts "registered: #{result.status}, expires #{result.expiration_date}"
rescue DomainNameApi::OperationError => e
  puts "the API refused: #{e.api_message}"
rescue DomainNameApi::Error => e
  # After a timeout the registration may have gone through: never retry blindly.
  warn "check #{domain} with client.domains.info before trying again" if e.outcome_unknown?
  raise
end
