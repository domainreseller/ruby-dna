# frozen_string_literal: true

# Run from the repository root: ruby examples/register_with_contact_info_tr.rb
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

# .tr domains need TRABIS attributes. Individual owner:
individual = {
  'TRABISDOMAINCATEGORY' => 1,
  'TRABISCITIZIENID'     => '11111111111'
}

# Company owner:
commercial = {
  'TRABISDOMAINCATEGORY' => 0,
  'TRABISTAXOFFICE'      => 'Istanbul VD',
  'TRABISTAXNUMBER'      => '1234567890'
}

# Legacy keys (TRABISNAMESURNAME, TRABISCOUNTRYID, TRABISCITYID, ...) are accepted
# and dropped; the category becomes Owner/Corporate and TRABISCITIZIENID
# is sent as TRABISCITIZENID.
result = dna.register_with_contact_info(
  'example.com.tr',
  1,
  { 'Administrative' => contact, 'Billing' => contact, 'Technical' => contact, 'Registrant' => contact },
  ['ns1.example.com', 'ns2.example.com'],
  true,
  false,
  individual # or commercial
)
pp result
pp commercial

# Sample output:
# { 'data' => { 'DomainName' => 'example.com.tr', 'Status' => 'Active', ... }, 'result' => 'OK' }
