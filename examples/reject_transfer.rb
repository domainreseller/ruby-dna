# frozen_string_literal: true

# Run from the repository root: ruby examples/reject_transfer.rb
# With the gem installed, `require 'domainnameapi'` is enough.
$LOAD_PATH.unshift File.expand_path('../lib', __dir__)
require 'domainnameapi'

# Credentials: your Reseller ID (UUID) + API Key from Panel -> API Settings.
# Panel login credentials will NOT work.
reseller_id = 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx' # Reseller ID (UUID)
api_key     = 'your-api-key'                         # API Key

dna = DomainNameApi::Client.new(reseller_id, api_key)
# Test (OTE) environment: DomainNameApi::Client.new(reseller_id, api_key, true)

# Reject a pending OUTGOING transfer.
result = dna.reject_transfer('example.com')
pp result

# Sample output:
# { 'result' => 'OK', 'data' => { 'DomainName' => 'example.com', 'Status' => 'Rejected' } }
