# frozen_string_literal: true

require_relative 'domainnameapi/version'
require_relative 'domainnameapi/util'
require_relative 'domainnameapi/errors'
require_relative 'domainnameapi/enum'
require_relative 'domainnameapi/enums'
require_relative 'domainnameapi/model'
require_relative 'domainnameapi/request'
require_relative 'domainnameapi/transport'
require_relative 'domainnameapi/service'
require_relative 'domainnameapi/account'
require_relative 'domainnameapi/contacts'
require_relative 'domainnameapi/domains'
require_relative 'domainnameapi/domain_settings'
require_relative 'domainnameapi/domain_transfers'
require_relative 'domainnameapi/domain_contacts'
require_relative 'domainnameapi/domain_documents'
require_relative 'domainnameapi/domain_forwarding'
require_relative 'domainnameapi/dns'
require_relative 'domainnameapi/dnssec'
require_relative 'domainnameapi/ssl'
require_relative 'domainnameapi/hosting'
require_relative 'domainnameapi/orders'
require_relative 'domainnameapi/products'
require_relative 'domainnameapi/client'

# Ruby SDK for the Domain Name API reseller REST API: domains, DNS, DNSSEC,
# contacts, SSL certificates, hosting, orders, the product catalogue and your
# balance.
#
#   require 'domainnameapi'
#
#   client = DomainNameApi::Client.new(reseller_id: ENV['DNA_RESELLER_ID'], api_key: ENV['DNA_API_KEY'],
#                                      environment: :ote)
#   a = client.domains.search('example.com')
#   puts "#{a.domain_name} is available for #{a.price} #{a.currency}" if a.available?
#
# The services mirror the dna CLI (https://github.com/domainreseller/cli):
# client.domains.info is `dna domain info`, client.dns.add is `dna dns add`.
# Every operation is a BaseRequest subclass that validates itself before
# anything is sent; Client#call sends your own subclasses too.
module DomainNameApi
end
