# Changelog

All notable changes to this project are documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-11-09

First release: a faithful Ruby port of [php-dna](https://github.com/domainreseller/php-dna)
(including its post-4.0.4 fixes), verified by php-dna's 134 conformance fixtures.

### Added

- `DomainNameApi::Client` with all 45 php-dna methods in snake_case, same parameter order and defaults:
  account and balance, availability search, domain and TLD lists, domain details, sync, contacts,
  nameservers, theft-protection lock, privacy, renewal, registration (including `.tr` TRABIS
  attribute normalization), child nameservers, transfers, DNS zone records and record sets,
  URL forwarding, `is_tr_tld`, `validate_contact` and the diagnostic getters/setters.
- Return values identical to php-dna (String-keyed Hashes, `'true'`/`'false'` flags, formatted
  prices), verified by the 134 php-dna conformance fixtures.
- Errors returned as envelopes, never raised: HTTP status mapping (`API_<status>`, plus the
  gateway's own code as `GatewayCode`), credential redirects, readable messages for empty bodies,
  ABP boilerplate replacement (never with the raw body) and flattened validation errors; timeouts
  and other transport failures reported as `CURL_<errno>` errors.
- Refusals are not reported as success: register, transfer and renew answered with
  `"success": false` return `REGISTER_DOMAIN` / `TRANSFER_DOMAIN` / `RENEW_DOMAIN` errors, DNS zone
  writes return the error of a failed automatic apply, and `get_current_balance` fails with
  `BALANCE` for currencies the account does not report (only USD and TRY are).
- `transfer(domain, epp_code, period)` never sends contacts; the registrar handles them.
- `modify_privacy_protection_status` accepts `1`/`'1'`/`'on'`/`'true'`/`'yes'` as enabled and does
  not send the reason (the gateway has no such field).
- URL forwarding: only `Redirect information not found` means "not configured" (`Enabled => false`,
  `delete_forwarding` → `Removed => false`); other errors, such as an unknown domain, are errors.
- `get_contacts` matches contact types case-insensitively and keeps non-standard types;
  `validate_contact` falls back to the city for a missing state and keeps a phone number's own
  `+`/`00` calling code; balances are formatted with two decimals; `check_availability` strips only
  the trailing `.tld`; `modify_name_server` reports the normalised list it sent; zone writes report
  the upper-cased type and the clamped TTL.
- Standard-library HTTP transport (Net::HTTP, 30 s total / 10 s connect, TLS verification on,
  `User-Agent: DomainNameAPI-Ruby/1.0.0`), injectable for tests; one-second pacing of DNS zone calls.
- Sentry telemetry ported from php-dna (credential masking, ignored errors, performance sampling,
  minimal mode, background sending). The built-in DSN is empty until the ruby-dna Sentry project
  exists, so nothing is sent by default; `sentry_dsn:` sets one.
- Runnable examples for every method, Minitest suite, GitHub Actions CI for Ruby 2.7–3.4.
- README in English, Turkish, German, French, Italian, Dutch, Azerbaijani, Arabic and Simplified Chinese.

[1.0.0]: https://github.com/domainreseller/ruby-dna/releases/tag/v1.0.0
