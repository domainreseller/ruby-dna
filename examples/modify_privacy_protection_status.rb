# frozen_string_literal: true

# Run from the repository root: ruby examples/modify_privacy_protection_status.rb
# With the gem installed, `require 'domainnameapi'` is enough.
$LOAD_PATH.unshift File.expand_path('../lib', __dir__)
require 'domainnameapi'

# Credentials: your Reseller ID (UUID) + API Key from Panel -> API Settings.
# Panel login credentials will NOT work.
reseller_id = 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx' # Reseller ID (UUID)
api_key     = 'your-api-key'                         # API Key

dna = DomainNameApi::Client.new(reseller_id, api_key)
# Test (OTE) environment: DomainNameApi::Client.new(reseller_id, api_key, true)

# true/1/'1'/'on'/'true'/'yes' enable, anything else disables. The reason is
# accepted for compatibility but not sent (the gateway has no such field).
result = dna.modify_privacy_protection_status('example.com', true, 'Owner request')
pp result

# Sample output:
# { 'data' => { 'PrivacyProtectionStatus' => true }, 'result' => 'OK' }
