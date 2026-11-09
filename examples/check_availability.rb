# frozen_string_literal: true

# Run from the repository root: ruby examples/check_availability.rb
# With the gem installed, `require 'domainnameapi'` is enough.
$LOAD_PATH.unshift File.expand_path('../lib', __dir__)
require 'domainnameapi'

# Credentials: your Reseller ID (UUID) + API Key from Panel -> API Settings.
# Panel login credentials will NOT work.
reseller_id = 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx' # Reseller ID (UUID)
api_key     = 'your-api-key'                         # API Key

dna = DomainNameApi::Client.new(reseller_id, api_key)
# Test (OTE) environment: DomainNameApi::Client.new(reseller_id, api_key, true)

# Check names x extensions; period in years, command 'create' (or 'transfer'/'renew').
result = dna.check_availability(%w[example testdomain], %w[com net], 1, 'create')
pp result

# Sample output:
# [
#   { 'TLD' => 'com', 'DomainName' => 'example', 'Status' => 'notavailable', 'Command' => 'create',
#     'Period' => 1, 'IsFee' => false, 'Price' => '11.9900', 'Currency' => 'USD', 'Reason' => 'Domain exists' },
#   { 'TLD' => 'com', 'DomainName' => 'testdomain', 'Status' => 'available', ... }
# ]
