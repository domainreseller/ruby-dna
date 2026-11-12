# frozen_string_literal: true

# Run from the repository root: ruby examples/delete_child_name_server.rb
# With the gem installed, `require 'domainnameapi'` is enough.
$LOAD_PATH.unshift File.expand_path('../lib', __dir__)
require 'domainnameapi'

# Credentials: your Reseller ID (UUID) + API Key from Panel -> API Settings.
# Panel login credentials will NOT work.
reseller_id = 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx' # Reseller ID (UUID)
api_key     = 'your-api-key'                         # API Key

dna = DomainNameApi::Client.new(reseller_id, api_key)
# Test (OTE) environment: DomainNameApi::Client.new(reseller_id, api_key, true)

result = dna.delete_child_name_server('example.com', 'ns1.example.com')
pp result

# Sample output:
# { 'result' => 'OK', 'data' => { 'NameServer' => 'ns1.example.com' } }
