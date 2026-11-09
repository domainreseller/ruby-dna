# frozen_string_literal: true

# Run from the repository root: ruby examples/get_details.rb
# With the gem installed, `require 'domainnameapi'` is enough.
$LOAD_PATH.unshift File.expand_path('../lib', __dir__)
require 'domainnameapi'

# Credentials: your Reseller ID (UUID) + API Key from Panel -> API Settings.
# Panel login credentials will NOT work.
reseller_id = 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx' # Reseller ID (UUID)
api_key     = 'your-api-key'                         # API Key

dna = DomainNameApi::Client.new(reseller_id, api_key)
# Test (OTE) environment: DomainNameApi::Client.new(reseller_id, api_key, true)

result = dna.get_details('example.com')
pp result

# Sample output:
# { 'data' => { 'ID' => 123456, 'Status' => 'Active', 'DomainName' => 'example.com', 'AuthCode' => 'Ab1!xyZ9',
#   'LockStatus' => 'true', 'PrivacyProtectionStatus' => 'false', 'IsChildNameServer' => 'false',
#   'Contacts' => { 'Billing' => { 'ID' => 'DNA-B-4' }, 'Technical' => { 'ID' => 'DNA-T-3' },
#                   'Administrative' => { 'ID' => 'DNA-A-2' }, 'Registrant' => { 'ID' => 'DNA-R-1' } },
#   'Dates' => { 'Start' => '2024-03-15T10:20:30', 'Expiration' => '2027-03-15T10:20:30', 'RemainingDays' => 126 },
#   'NameServers' => ['ns1.example.net', 'ns2.example.net'], 'Additional' => {}, 'ChildNameServers' => [] },
#   'result' => 'OK' }
