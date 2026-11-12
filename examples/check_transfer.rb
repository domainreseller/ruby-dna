# frozen_string_literal: true

# Run from the repository root: ruby examples/check_transfer.rb
# With the gem installed, `require 'domainnameapi'` is enough.
$LOAD_PATH.unshift File.expand_path('../lib', __dir__)
require 'domainnameapi'

# Credentials: your Reseller ID (UUID) + API Key from Panel -> API Settings.
# Panel login credentials will NOT work.
reseller_id = 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx' # Reseller ID (UUID)
api_key     = 'your-api-key'                         # API Key

dna = DomainNameApi::Client.new(reseller_id, api_key)
# Test (OTE) environment: DomainNameApi::Client.new(reseller_id, api_key, true)

# Is the domain transferable with this auth code? result is 'OK' only when it is.
result = dna.check_transfer('example.com', 'ABC123XYZ456')
pp result

# Sample output:
# { 'result' => 'OK', 'data' => { 'TransferAvailabilityStatus' => true, 'AuthCodeIsRequired' => true,
#   'AuthCodeIsValid' => true, 'UserTransferRequired' => false, 'TransferLock' => false,
#   'Message' => '', 'MessageKey' => '', 'Additional' => {} } }
