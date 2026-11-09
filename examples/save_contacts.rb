# frozen_string_literal: true

# Run from the repository root: ruby examples/save_contacts.rb
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

result = dna.save_contacts('example.com', {
  'Administrative' => contact, 'Billing' => contact, 'Technical' => contact, 'Registrant' => contact
})
pp result

# Sample output:
# { 'result' => 'OK', 'data' => { 'contacts' => {} } }
