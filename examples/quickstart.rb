# frozen_string_literal: true

# Quickstart: check the credentials, the balance and one domain.
#
#   export DNA_RESELLER_ID=... DNA_API_KEY=... DNA_ENV=ote
#   ruby examples/quickstart.rb example.com
#
# With the gem installed, `require 'domainnameapi'` is enough.
$LOAD_PATH.unshift File.expand_path('../lib', __dir__)
require 'domainnameapi'

domain = ARGV[0] || 'example.com'
client = DomainNameApi::Client.from_env

account = client.account.get # the cheapest way to check the credentials
puts "#{account.reseller_name} (#{client.environment}): #{format('%.2f', account.balance('USD'))} USD, " \
     "#{format('%.2f', account.balance('TRY'))} TRY"

a = client.domains.search(domain)
if a.available?
  puts "#{a.domain_name} is available for #{a.price} #{a.currency}#{' (premium)' if a.premium?}"
else
  puts "#{a.domain_name} is not available: #{a.status} #{a.reason}"
  begin
    d = client.domains.info(domain)
    puts "  yours: #{d.status}, expires #{d.expiration_date} (#{d.remaining_days} days), " \
         "locked=#{d.locked?}, nameservers=#{d.name_servers.join(', ')}"
  rescue DomainNameApi::Error => e
    raise unless e.not_found?

    puts '  (not in this account)'
  end
end
