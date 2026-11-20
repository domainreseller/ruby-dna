# frozen_string_literal: true

module DomainNameApi
  # Version of this gem.
  VERSION = '2.0.0'

  # Sent with every request (see the +user_agent:+ option of Client). The API
  # sits behind Cloudflare, which rejects requests without a descriptive agent.
  USER_AGENT = "DomainNameAPI-Ruby/#{VERSION} (+https://github.com/domainreseller/ruby-dna)"
end
