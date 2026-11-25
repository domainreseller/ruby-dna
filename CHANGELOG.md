# Changelog

All notable changes to this project are documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.2.0] - 2026-11-26

### Added

- Every request carries `X-App` and `X-Version` headers that identify the application using the SDK. They
  default to `ruby` and the gem version; set them with the `app_name:` and `app_version:` client options or the
  `DNA_APP` and `DNA_APP_VERSION` environment variables (`Client.from_env`). The name is lowercased and keeps
  only `a-z`, `0-9`, `.`, `_` and `-`; the version keeps only digits and dots (`V2.0.20-beta` is sent as
  `2.0.20`). An empty name or version falls back to the default. The User-Agent is unchanged.

## [2.1.0] - 2026-11-22

**Breaking, and forced by the API.** Since 2026-11-20 the API (production and OTE) addresses an existing SSL
certificate by its `certificateId` instead of its domain name, because a domain can now have several
certificates. Version 2.0.0 still sends the domain name, so its `ssl.configure`, `status`, `get`, `content`,
`reissue` and `revoke` calls no longer work, and its `ssl.approvers` only works with a package code; staying on
2.0.0 does not avoid the change.

### Changed

- **Breaking:** `ssl.status`, `ssl.get`, `ssl.content`, `ssl.reissue` and `ssl.revoke` take the certificate id
  instead of the domain name: `client.ssl.status(certificate_id)`.
- **Breaking:** `ssl.configure` takes `certificate_id:` instead of `domain_name:`. The CSR's common name must
  match the certificate's domain.
- **Breaking:** `ssl.approvers` takes keywords only, in one of two forms: `approvers(certificate_id: id)` for an
  existing certificate, or `approvers(domain_name: 'example.com', package_code: 'PositiveSSL')` before a purchase.
  The package code is now required with a domain name, and the two forms cannot be mixed.
- **Breaking:** `SSLConfigureRequest`, `SSLStatusRequest`, `SSLGetRequest`, `SSLContentRequest`,
  `SSLReissueRequest` and `SSLRevokeRequest` have a `certificate_id` attribute and no `domain_name`;
  `SSLApproversRequest` has `certificate_id`, `domain_name` and `package_code`.
- A certificate id that is not a GUID raises `InputError` before anything is sent, with a message that says where
  to get the id. This catches code written for the old API that still passes a domain name.
- Renewing a certificate is `ssl.renew` followed by `ssl.configure` of the certificate it returns. A second
  `ssl.purchase` is an unrelated new order at the purchase price, and the old certificate never becomes `Renewed`.
- The API now gives 15 days (it was 7) to configure a certificate after `ssl.purchase` or `ssl.renew`.

What to change in your code:

1. Store the `certificate_id` of the `ssl.purchase` result. For certificates you already have, look it up once:
   `client.ssl.list(domain_name: 'example.com').first.certificate_id`.
2. Pass that id wherever you passed the domain name to `status`, `get`, `content`, `reissue` and `revoke`, and as
   `certificate_id:` to `configure`.
3. Call `approvers` with `certificate_id:`, or with `domain_name:` and `package_code:` before a purchase.
4. Renew with `renewal = client.ssl.renew(certificate_id)` and configure `renewal.certificate_id`.

### Added

- `ssl.renew(certificate_id)` (`SSLRenewRequest`, `POST /api/v1/ssls/renew`): renews a certificate and returns the
  new certificate to configure. It charges the balance, so it is `:billable` like `ssl.purchase`: never retried
  after a network error and blocked by `read_only: true`.
- `ssl.list` and `ssl.all` (`SSLListRequest`, `GET /api/v1/ssls`): your certificates, newest first, optionally of
  one domain, as `CertificateListItem` values; `ssl.all` fetches the pages as you go, like `domains.all`.
- `certificate_id` on `Certificate`, `CertificateStatus` and `CertificateContent`.
- `account.profile` (`AccountProfileRequest`, `GET /api/v1/resellers/me`): the reseller's `ResellerProfile` with
  the new `AccountCurrency` and `ResellerStatus` enums.
- The SDK now covers all 67 operations of the API.

## [2.0.0] - 2026-11-20

A new SDK, designed for Ruby and for the REST API instead of ported from php-dna. It follows the `dna` CLI and
the v2 Go and .NET SDKs. See "Migrating from v1" in the README.

### Added

- All 64 operations of the REST API, grouped like the `dna` CLI: `client.account`, `contacts`, `domains`, `dns`,
  `dnssec`, `ssl`, `hosting`, `orders` and `products`. New compared to v1: contact handles and verification,
  registration with handles, renew check, restore, auth code update, registry documents, DNSSEC, SSL
  certificates, hosting, orders, balance transactions and product prices.
- Typed results (`DomainNameApi::Model` subclasses with snake_case readers, `?` predicates and `Time` dates),
  enums with predicates (`domain.status.pending_delete?`) and tolerant decoding of the API's quirks: dates
  without a timezone, `[]` instead of `{}`, numeric or named statuses, roles in any case. `Model#raw` keeps the
  JSON as received.
- A request class per operation (`DomainRegisterRequest`, `DNSAddRequest`, ...), each a subclass of
  `DomainNameApi::BaseRequest` (or `PagedRequest`) with an `endpoint` / `attribute` / `returns` DSL. Requests
  validate themselves before sending and have a safety class (`:read`, `:write`, `:destructive`, `:billable`).
  `Client#call` sends your own subclasses too; `Client#execute` returns the whole `Response`;
  `Client#prepare` builds a request without sending it.
- Typed errors under `DomainNameApi::Error` (`APIError`, `OperationError` for `"success": false`, `InputError`,
  `NetworkError`, `ReadOnlyError`) with `kind`, `not_found?`, `auth?`, `rate_limited?`, `insufficient_balance?`,
  `outcome_unknown?`, `retryable?`, `code?` and `APIError#hint`.
- Enumerators over paged lists that fetch pages as you go: `domains.all`, `account.all_transactions`,
  `products.all_tlds`.
- `Client.from_env` with the CLI's environment variables, `read_only:`, `currency:`, `logger:`, `on_trace:`,
  `DomainNameApi.with_correlation_id`, quota headers in `Response#quota`, `hosting.wait` and a pluggable
  `transport:`.
- Retries on 429 for every request and on network errors and 502/503/504 only for requests that are safe to
  repeat; client-side pacing under the rate limits; a client that is safe to share between threads.
- Tests that check every request class, response model and enum against the API's OpenAPI document.

### Removed

- The php-dna compatible API: `Client.new(id, key, test_mode)`, the String-keyed result Hashes, the
  `{'result' => 'ERROR'}` envelopes and the diagnostics getters (`get_request_data`, ...). Use `on_trace:` or
  `logger:` instead.
- Telemetry: the gem no longer sends anything to Sentry. Forward `on_trace` events to your own reporting.
- `cancel_transfer`, `approve_transfer` and `reject_transfer`, which called endpoints that are not part of the
  published API.
- Support for Ruby 2.7 and 3.0; Ruby 3.1 or newer is required.

## [1.0.1] - 2026-11-14

### Changed

- Error reporting now has its own Sentry project: `DEFAULT_SENTRY_DSN` points to DomainNameAPI's
  ruby-dna project, so telemetry is active by default as documented. Turn it off with
  `set_error_reporting_enabled(false)`; `sentry_dsn:` still overrides the target.

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

[Unreleased]: https://github.com/domainreseller/ruby-dna/compare/v2.2.0...HEAD
[2.2.0]: https://github.com/domainreseller/ruby-dna/releases/tag/v2.2.0
[2.1.0]: https://github.com/domainreseller/ruby-dna/releases/tag/v2.1.0
[2.0.0]: https://github.com/domainreseller/ruby-dna/releases/tag/v2.0.0
[1.0.1]: https://github.com/domainreseller/ruby-dna/releases/tag/v1.0.1
[1.0.0]: https://github.com/domainreseller/ruby-dna/releases/tag/v1.0.0
