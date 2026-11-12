# frozen_string_literal: true

# Run from the repository root: ruby examples/get_reseller_details.rb
# With the gem installed, `require 'domainnameapi'` is enough.
$LOAD_PATH.unshift File.expand_path('../lib', __dir__)
require 'domainnameapi'

# Credentials: your Reseller ID (UUID) + API Key from Panel -> API Settings.
# Panel login credentials will NOT work.
reseller_id = 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx' # Reseller ID (UUID)
api_key     = 'your-api-key'                         # API Key

dna = DomainNameApi::Client.new(reseller_id, api_key)
# Test (OTE) environment: DomainNameApi::Client.new(reseller_id, api_key, true)

result = dna.get_reseller_details
pp result

# Sample output:
# { 'result' => 'OK', 'id' => 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'active' => true, 'name' => 'example-reseller',
#   'balance' => '601.64', 'currency' => 'USD', 'symbol' => '$',
#   'balances' => [{ 'balance' => '601.64', 'currency' => 'USD', 'symbol' => '$' },
#                  { 'balance' => '1250.50', 'currency' => 'TL', 'symbol' => 'TL' }] }
