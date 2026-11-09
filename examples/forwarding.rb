# frozen_string_literal: true

# Run from the repository root: ruby examples/forwarding.rb
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

# 'Standard' (plain redirect) or 'Frame' (masked).
pp dna.set_forwarding(domain, 'https://www.example.org', 'Standard')
pp dna.get_forwarding(domain)
pp dna.delete_forwarding(domain)

# Sample output:
# set_forwarding: { 'result' => 'OK', 'data' => { 'RedirectAddress' => 'https://www.example.org', 'ForwardType' => 'Standard' } }
# get_forwarding: { 'result' => 'OK', 'data' => { 'Enabled' => true, 'RedirectAddress' => 'https://www.example.org', 'ForwardType' => 'Standard' } }
# get_forwarding when nothing is set: { 'result' => 'OK', 'data' => { 'Enabled' => false, 'RedirectAddress' => '', 'ForwardType' => '' } }
# delete_forwarding: { 'result' => 'OK', 'data' => { 'DomainName' => 'example.com' } }
