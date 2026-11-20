# frozen_string_literal: true

require_relative 'lib/domainnameapi/version'

Gem::Specification.new do |spec|
  spec.name          = 'domainnameapi'
  spec.version       = DomainNameApi::VERSION
  spec.authors       = ['DomainNameAPI']
  spec.email         = ['support@domainnameapi.com']

  spec.summary       = 'Ruby SDK for the Domain Name API reseller REST API.'
  spec.description   = 'Search, register, renew and transfer domains; manage DNS, DNSSEC, contacts, SSL ' \
                       'certificates, hosting, orders and the product catalogue through the Domain Name API ' \
                       'reseller REST API. Typed results, a request class per operation, safe retries and ' \
                       'pacing, modelled on the dna CLI. No runtime dependencies.'
  spec.homepage      = 'https://github.com/domainreseller/ruby-dna'
  spec.license       = 'Apache-2.0'
  spec.required_ruby_version = '>= 3.1'

  spec.metadata = {
    'source_code_uri' => spec.homepage,
    'changelog_uri' => "#{spec.homepage}/blob/main/CHANGELOG.md",
    'bug_tracker_uri' => "#{spec.homepage}/issues",
    'documentation_uri' => 'https://www.domainnameapi.com/docs/',
    'rubygems_mfa_required' => 'true'
  }

  spec.files = Dir['lib/**/*.rb'] + %w[README.md CHANGELOG.md LICENSE]
  spec.require_paths = ['lib']
end
