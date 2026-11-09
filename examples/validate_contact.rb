# frozen_string_literal: true

# Run from the repository root: ruby examples/validate_contact.rb
# With the gem installed, `require 'domainnameapi'` is enough.
$LOAD_PATH.unshift File.expand_path('../lib', __dir__)
require 'domainnameapi'

# Credentials: your Reseller ID (UUID) + API Key from Panel -> API Settings.
# Panel login credentials will NOT work.
reseller_id = 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx' # Reseller ID (UUID)
api_key     = 'your-api-key'                         # API Key

dna = DomainNameApi::Client.new(reseller_id, api_key)
# Test (OTE) environment: DomainNameApi::Client.new(reseller_id, api_key, true)

# No network call: fills gaps and normalizes a contact the way register/save do.
pp dna.validate_contact('FirstName' => 'J0hn', 'Phone' => '+90 532 374 33 88', 'Country' => 'Turkey')

# Sample output:
# { 'FirstName' => 'Jhn', 'Phone' => '5323743388', 'Country' => 'TR', 'LastName' => 'Isimyok',
#   'AddressLine1' => 'Addres yok', 'City' => 'ISTANBUL', 'State' => 'ISTANBUL', 'ZipCode' => '34000',
#   'PhoneCountryCode' => '90', 'Fax' => '', 'FaxCountryCode' => '' }
