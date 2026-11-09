# frozen_string_literal: true

# Run from the repository root: ruby examples/get_contacts.rb
# With the gem installed, `require 'domainnameapi'` is enough.
$LOAD_PATH.unshift File.expand_path('../lib', __dir__)
require 'domainnameapi'

# Credentials: your Reseller ID (UUID) + API Key from Panel -> API Settings.
# Panel login credentials will NOT work.
reseller_id = 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx' # Reseller ID (UUID)
api_key     = 'your-api-key'                         # API Key

dna = DomainNameApi::Client.new(reseller_id, api_key)
# Test (OTE) environment: DomainNameApi::Client.new(reseller_id, api_key, true)

result = dna.get_contacts('example.com')
pp result

# Sample output:
# { 'data' => { 'contacts' => {
#   'Administrative' => { 'ID' => 'DNA-A-2', 'Status' => 'Active', 'FirstName' => 'Grace', 'LastName' => 'Hopper',
#     'Company' => '', 'EMail' => 'grace@example.com', 'Type' => 'Administrative',
#     'Address' => { 'Line1' => '...', 'City' => 'Washington', 'Country' => 'US', 'ZipCode' => '20001', ... },
#     'Phone' => { 'Phone' => { 'Number' => '2025550100', 'CountryCode' => '1' }, 'Fax' => { ... } },
#     'Additional' => {} },
#   'Billing' => { ... }, 'Registrant' => { ... }, 'Technical' => { ... } } }, 'result' => 'OK' }
