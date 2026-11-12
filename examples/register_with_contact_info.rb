# frozen_string_literal: true

# Run from the repository root: ruby examples/register_with_contact_info.rb
# With the gem installed, `require 'domainnameapi'` is enough.
$LOAD_PATH.unshift File.expand_path('../lib', __dir__)
require 'domainnameapi'

# Credentials: your Reseller ID (UUID) + API Key from Panel -> API Settings.
# Panel login credentials will NOT work.
reseller_id = 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx' # Reseller ID (UUID)
api_key     = 'your-api-key'                         # API Key

dna = DomainNameApi::Client.new(reseller_id, api_key)
# Test (OTE) environment: DomainNameApi::Client.new(reseller_id, api_key, true)

contact = {
  'FirstName'        => 'Ahmet',
  'LastName'         => 'Yilmaz',
  'Company'          => '',
  'EMail'            => 'ahmet.yilmaz@example.com',
  'AddressLine1'     => 'Ornek Sokak No: 123',
  'AddressLine2'     => 'Daire 4',
  'AddressLine3'     => '',
  'City'             => 'Istanbul',
  'Country'          => 'TR',
  'Fax'              => '2121234567',
  'FaxCountryCode'   => '90',
  'Phone'            => '5551234567',
  'PhoneCountryCode' => 90,
  'Type'             => 'Contact',
  'ZipCode'          => '34000',
  'State'            => 'Istanbul'
}

result = dna.register_with_contact_info(
  'example.com',
  1,
  { 'Administrative' => contact, 'Billing' => contact, 'Technical' => contact, 'Registrant' => contact },
  ['ns1.example.com', 'ns2.example.com'],
  true,  # theft protection lock
  false  # privacy protection
)
pp result

# Sample output:
# { 'data' => { 'ID' => 123456, 'Status' => 'Active', 'DomainName' => 'example.com', ...,
#   'Dates' => { 'Start' => '2026-11-09T12:00:00', 'Expiration' => '2027-11-09T12:00:00', 'RemainingDays' => 365 },
#   'NameServers' => ['ns1.example.com', 'ns2.example.com'], ... }, 'result' => 'OK' }
