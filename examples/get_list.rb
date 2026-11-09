# frozen_string_literal: true

# Run from the repository root: ruby examples/get_list.rb
# With the gem installed, `require 'domainnameapi'` is enough.
$LOAD_PATH.unshift File.expand_path('../lib', __dir__)
require 'domainnameapi'

# Credentials: your Reseller ID (UUID) + API Key from Panel -> API Settings.
# Panel login credentials will NOT work.
reseller_id = 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx' # Reseller ID (UUID)
api_key     = 'your-api-key'                         # API Key

dna = DomainNameApi::Client.new(reseller_id, api_key)
# Test (OTE) environment: DomainNameApi::Client.new(reseller_id, api_key, true)

# Optional filters: PageNumber (0-based), PageSize, OrderColumn, OrderDirection, plus gateway filters.
result = dna.get_list('PageNumber' => 0, 'PageSize' => 100, 'OrderColumn' => 'ExpirationDate', 'OrderDirection' => 'ASC')
pp result

# Sample output:
# { 'data' => { 'Domains' => [ { 'ID' => 11, 'Status' => 'Active', 'DomainName' => 'example.com', ... } ] },
#   'result' => 'OK', 'TotalCount' => 1 }
