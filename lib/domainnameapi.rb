# frozen_string_literal: true

require_relative 'domainnameapi/version'
require_relative 'domainnameapi/php'
require_relative 'domainnameapi/transport'
require_relative 'domainnameapi/telemetry'
require_relative 'domainnameapi/rest'
require_relative 'domainnameapi/client'

# Ruby client for the DomainNameAPI domain reseller REST API.
#
#   require 'domainnameapi'
#   dna = DomainNameApi::Client.new('xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'your-api-key')
#   dna.get_details('example.com')
module DomainNameApi
end
