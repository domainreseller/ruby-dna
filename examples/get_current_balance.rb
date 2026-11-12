# frozen_string_literal: true

# Run from the repository root: ruby examples/get_current_balance.rb
# With the gem installed, `require 'domainnameapi'` is enough.
$LOAD_PATH.unshift File.expand_path('../lib', __dir__)
require 'domainnameapi'

# Credentials: your Reseller ID (UUID) + API Key from Panel -> API Settings.
# Panel login credentials will NOT work.
reseller_id = 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx' # Reseller ID (UUID)
api_key     = 'your-api-key'                         # API Key

dna = DomainNameApi::Client.new(reseller_id, api_key)
# Test (OTE) environment: DomainNameApi::Client.new(reseller_id, api_key, true)

# The account reports 'USD' (default) and 'TRY' balances; other currencies
# fail with 'ErrorCode' => 'BALANCE'.
result = dna.get_current_balance('USD')
pp result

# Sample output:
# { 'ErrorCode' => 0, 'OperationMessage' => 'Command completed succesfully.', 'OperationResult' => 'SUCCESS',
#   'Balance' => '601.64', 'CurrencyId' => 2, 'CurrencyInfo' => nil, 'CurrencyName' => 'USD', 'CurrencySymbol' => '$' }
