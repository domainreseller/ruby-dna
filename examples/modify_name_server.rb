# frozen_string_literal: true

# Run from the repository root: ruby examples/modify_name_server.rb
# With the gem installed, `require 'domainnameapi'` is enough.
$LOAD_PATH.unshift File.expand_path('../lib', __dir__)
require 'domainnameapi'

# Credentials: your Reseller ID (UUID) + API Key from Panel -> API Settings.
# Panel login credentials will NOT work.
reseller_id = 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx' # Reseller ID (UUID)
api_key     = 'your-api-key'                         # API Key

dna = DomainNameApi::Client.new(reseller_id, api_key)
# Test (OTE) environment: DomainNameApi::Client.new(reseller_id, api_key, true)

# A list or a Hash of nameservers (the values are used).
result = dna.modify_name_server('example.com', 'ns1' => 'ns1.example.com', 'ns2' => 'ns2.example.com')
pp result

# Sample output:
# { 'result' => 'OK', 'data' => { 'NameServers' => ['ns1.example.com', 'ns2.example.com'] } }
