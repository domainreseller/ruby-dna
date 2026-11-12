# frozen_string_literal: true

require_relative 'lib/domainnameapi/version'

Gem::Specification.new do |spec|
  spec.name          = 'domainnameapi'
  spec.version       = DomainNameApi::VERSION
  spec.authors       = ['DomainNameAPI']
  spec.email         = ['support@domainnameapi.com']

  spec.summary       = 'Ruby client for the DomainNameAPI domain reseller REST API.'
  spec.description   = 'Register, renew, transfer and manage domains, contacts, child nameservers, ' \
                       'DNS zones and URL forwarding through the DomainNameAPI REST gateway. ' \
                       'A faithful port of php-dna with zero runtime dependencies.'
  spec.homepage      = 'https://github.com/domainreseller/ruby-dna'
  spec.license       = 'Apache-2.0'
  spec.required_ruby_version = '>= 2.7'

  spec.metadata = {
    'homepage_uri'    => spec.homepage,
    'source_code_uri' => spec.homepage,
    'changelog_uri'   => "#{spec.homepage}/blob/main/CHANGELOG.md",
    'bug_tracker_uri' => "#{spec.homepage}/issues"
  }

  spec.files = Dir['lib/**/*.rb'] + %w[README.md CHANGELOG.md LICENSE]
  spec.require_paths = ['lib']
end
