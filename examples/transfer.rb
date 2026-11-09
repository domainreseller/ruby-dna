# frozen_string_literal: true

# Run from the repository root: ruby examples/transfer.rb
# With the gem installed, `require 'domainnameapi'` is enough.
$LOAD_PATH.unshift File.expand_path('../lib', __dir__)
require 'domainnameapi'

# Credentials: your Reseller ID (UUID) + API Key from Panel -> API Settings.
# Panel login credentials will NOT work.
reseller_id = 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx' # Reseller ID (UUID)
api_key     = 'your-api-key'                         # API Key

dna = DomainNameApi::Client.new(reseller_id, api_key)
# Test (OTE) environment: DomainNameApi::Client.new(reseller_id, api_key, true)

# Domain, EPP/auth code, period in years.
result = dna.transfer('example.com', 'ABC123XYZ456', 1)
pp result

# Sample output:
# { 'data' => { 'DomainName' => 'example.com', 'Status' => 'WaitingForIncomingTransfer', ... }, 'result' => 'OK' }
