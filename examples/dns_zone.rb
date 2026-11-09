# frozen_string_literal: true

# Run from the repository root: ruby examples/dns_zone.rb
# With the gem installed, `require 'domainnameapi'` is enough.
$LOAD_PATH.unshift File.expand_path('../lib', __dir__)
require 'domainnameapi'

# Credentials: your Reseller ID (UUID) + API Key from Panel -> API Settings.
# Panel login credentials will NOT work.
reseller_id = 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx' # Reseller ID (UUID)
api_key     = 'your-api-key'                         # API Key

dna = DomainNameApi::Client.new(reseller_id, api_key)
# Test (OTE) environment: DomainNameApi::Client.new(reseller_id, api_key, true)

domain = 'example.com'

# List records (names come back fully qualified: 'www.example.com.').
pp dna.get_resource_records(domain)

# Supported types: A, AAAA, ALIAS, CAA, CNAME, DS, MX, NAPTR, PTR, SRV, TLSA, TXT.
# Names are relative ('www'); '' or '@' is the apex. Writes are applied immediately
# unless apply = false (then call apply_resource_records).

# Replace a whole name+type set in one call (the gateway's own model).
pp dna.set_resource_record_set(domain, 'www', 'A', ['192.0.2.10', '192.0.2.11'], 3600)

# Panel-style single values (read-merge-write, safe to retry).
pp dna.add_resource_record_value(domain, '', 'MX', '10 mail.example.com.')
pp dna.replace_resource_record_value(domain, '', 'MX', '10 mail.example.com.', '20 mail.example.com.')
pp dna.remove_resource_record_value(domain, '', 'MX', '20 mail.example.com.')

# Low-level calls.
pp dna.add_resource_record(domain, 'txt-test', 'TXT', 'hello', 300, false)
pp dna.edit_resource_record(domain, 'txt-test', 'txt-test', 'TXT', 'hello again', 300, false)
pp dna.apply_resource_records(domain)
pp dna.delete_resource_record(domain, 'txt-test.example.com.', 'hello again', 'TXT')

# Remove every value under a name+type.
pp dna.delete_resource_record_set(domain, 'www', 'A')

# Sample output:
# get_resource_records:
# { 'result' => 'OK', 'data' => { 'records' => [
#   { 'Name' => 'www.example.com.', 'Type' => 'A', 'TTL' => 3600, 'Content' => '192.0.2.10', 'Disabled' => false } ] } }
# set_resource_record_set:
# { 'result' => 'OK', 'data' => { 'Name' => 'www', 'Type' => 'A', 'TTL' => 3600, 'Contents' => ['192.0.2.10', '192.0.2.11'] } }
