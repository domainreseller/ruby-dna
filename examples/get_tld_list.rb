# frozen_string_literal: true

# Run from the repository root: ruby examples/get_tld_list.rb
# With the gem installed, `require 'domainnameapi'` is enough.
$LOAD_PATH.unshift File.expand_path('../lib', __dir__)
require 'domainnameapi'

# Credentials: your Reseller ID (UUID) + API Key from Panel -> API Settings.
# Panel login credentials will NOT work.
reseller_id = 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx' # Reseller ID (UUID)
api_key     = 'your-api-key'                         # API Key

dna = DomainNameApi::Client.new(reseller_id, api_key)
# Test (OTE) environment: DomainNameApi::Client.new(reseller_id, api_key, true)

# Number of TLDs to fetch (default 20).
result = dna.get_tld_list(2)
pp result

# Sample output:
# { 'data' => [ { 'id' => 1, 'status' => 'Active', 'maxchar' => 63, 'maxperiod' => 10, 'minchar' => 1,
#   'minperiod' => 1, 'tld' => 'aero',
#   'pricing' => { 'registration' => { '1' => '44.9900', '2' => '94.9100' }, 'renew' => { '1' => '49.9200' } },
#   'currencies' => { 'registration' => 'USD', 'renew' => 'USD' } } ], 'result' => 'OK' }
