# frozen_string_literal: true

# Manage DNS records of a domain on the platform nameservers.
#
# The test environment answers every zone call with HTTP 500, so this runs
# against production: use a domain you do not mind changing.
#
#   DNA_ENV=production ruby examples/dns.rb example.com
$LOAD_PATH.unshift File.expand_path('../lib', __dir__)
require 'domainnameapi'

domain = ARGV[0] || abort('usage: ruby examples/dns.rb DOMAIN')
client = DomainNameApi::Client.from_env

client.dns.add(domain, name: 'sdk-test', type: :a, values: '192.0.2.10', ttl: 600)
client.dns.add(domain, name: 'sdk-test', type: :txt, values: 'hello from ruby-dna')
client.dns.update(domain, record_name: 'sdk-test', type: :a, values: %w[192.0.2.20 192.0.2.21])

client.dns.list(domain).each do |set|
  next unless set.matches?(domain, 'sdk-test', set.type)

  puts "#{set.name} #{set.type} #{set.ttl} #{set.values.join(' | ')}"
end

# Clean up, one value at a time.
%w[192.0.2.20 192.0.2.21].each { |ip| client.dns.delete(domain, name: 'sdk-test', type: :a, value: ip) }
client.dns.delete(domain, name: 'sdk-test', type: :txt, value: 'hello from ruby-dna')
puts 'removed the test records'

# client.dns.apply(domain) would switch the domain to the platform nameservers.
