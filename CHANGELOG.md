# Changelog

All notable changes to this project are documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-11-09

First release: a faithful Ruby port of [php-dna](https://github.com/domainreseller/php-dna) 4.0.4.

### Added

- `DomainNameApi::Client` with all 45 php-dna methods in snake_case, same parameter order and defaults:
  account and balance, availability search, domain and TLD lists, domain details, sync, contacts,
  nameservers, theft-protection lock, privacy, renewal, registration (including `.tr` TRABIS
  attribute normalization), child nameservers, transfers, DNS zone records and record sets,
  URL forwarding, `is_tr_tld`, `validate_contact` and the diagnostic getters/setters.
- Return values identical to php-dna (String-keyed Hashes, `'true'`/`'false'` flags, formatted
  prices), verified by the 126 php-dna conformance fixtures.
- Errors returned as envelopes, never raised: HTTP status mapping (`API_<status>`), credential
  redirects, readable messages for empty bodies, ABP boilerplate replacement and flattened
  validation errors; timeouts and other transport failures reported as errors.
- Standard-library HTTP transport (Net::HTTP, 30 s total / 10 s connect, TLS verification on,
  `User-Agent: DomainNameAPI-Ruby/1.0.0`), injectable for tests; one-second pacing of DNS zone calls.
- Sentry telemetry ported from php-dna (credential masking, ignored errors, performance sampling,
  minimal mode, background sending). The built-in DSN is empty until the ruby-dna Sentry project
  exists, so nothing is sent by default; `sentry_dsn:` sets one.
- Runnable examples for every method, Minitest suite, GitHub Actions CI for Ruby 2.7–3.4.
- README in English, Turkish, German, French, Italian, Dutch, Azerbaijani, Arabic and Simplified Chinese.

[1.0.0]: https://github.com/domainreseller/ruby-dna/releases/tag/v1.0.0
