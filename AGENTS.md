# AGENTS.md

Guidance for people and AI coding agents working on this repository.

## What this is

`ruby-dna` is the Ruby SDK for the Domain Name API reseller REST API (gem `domainnameapi`, module
`DomainNameApi`). It mirrors the [`dna` CLI](https://github.com/domainreseller/cli) and the v2 Go
([go-dna](https://github.com/domainreseller/go-dna)) and .NET ([dotnet-dna](https://github.com/domainreseller/dotnet-dna))
SDKs: the same operations, the same groups, the same environment variables and the same safety classes. It has
nothing to do with php-dna or the SOAP API.

## Commands

```bash
bundle install
bundle exec rake test     # all tests, with warnings on; none touches the network
gem build domainnameapi.gemspec
```

## Layout

| file | content |
|---|---|
| `lib/domainnameapi/client.rb` | `Client`, `from_env`, environments, options, the send loop (retries, pacing, tracing, correlation IDs) |
| `lib/domainnameapi/request.rb` | `Safety`, `Endpoint`, `Validator`, `Query`, `BaseRequest`, `PagedRequest` |
| `lib/domainnameapi/model.rb` | `Model` (the field DSL and tolerant decoding), `Page`, `Price` |
| `lib/domainnameapi/enum.rb`, `enums.rb` | the `Enum` base class and every enum |
| `lib/domainnameapi/errors.rb` | error classes, kinds, codes and the normalisation of API error responses |
| `lib/domainnameapi/transport.rb` | `NetHTTPTransport`, `PreparedRequest`, `Response`, `Quota`, `TraceEvent`, `Pacer` |
| `lib/domainnameapi/service.rb` | the `Service` base class (request building, pagination, operation errors) |
| `account.rb`, `contacts.rb`, `domains.rb`, `domain_*.rb`, `dns.rb`, `dnssec.rb`, `ssl.rb`, `hosting.rb`, `orders.rb`, `products.rb` | one file per CLI group: models, request classes, service methods |
| `test/fixtures/openapi.json` | the API's OpenAPI document, the source of truth (the same one the CLI embeds) |

## Adding or changing an operation

1. Update `test/fixtures/openapi.json` (see README, "Development") and run the tests. `SpecTest` fails for any
   operation without a request class.
2. Add a request class named after the CLI command (`dna domain renew-check` → `DomainRenewCheckRequest`). It
   inherits from `BaseRequest` (`PagedRequest` for lists), declares `endpoint` (method, path, safety), `returns`
   and its `attribute`s, and overrides `query`, `body` and `validate` as needed. Attributes are snake_case and
   accept symbols for enums; the wire names live only in `query` and `body`.
3. Add the service method. Required inputs are positional, the rest keywords; operations with many optional
   inputs also take the request object. Turn `"success": false` answers into an `OperationError`.
4. Add the case to `SpecTest.cases` (every attribute set) and to `test_every_service_method`, plus a behaviour
   test in `test/services_test.rb`.
5. New integer enums go in `enums.rb` and in `EnumsTest#test_spec_enums`.

## Rules

- **Safety class** is a product decision and matches the CLI: `:billable` charges the balance, `:destructive`
  deletes or is hard to undo, `:write` is free and reversible, `:read` has no side effects even when the method
  is POST or PUT. Set `idempotent: true` only when sending the request twice is harmless.
- **Never retry a billable or non-idempotent request after a network error.** Do not weaken the retry rules in
  `client.rb`.
- **No telemetry.** Nothing may leave the user's process except the API requests they make.
- **Standard library only.** No runtime dependencies; Ruby 3.1 or newer.
- **Models are forgiving, requests are strict.** Response fields decode to nil, `[]`, `false` or `{}` instead of
  failing; requests validate before sending.
- **Do not shadow core methods** with field or attribute names (`object_id`, `hash`, `send`, `class`, ...).
- Tests never call the real API; use `DnaTest.fake_client` from `test/test_helper.rb`.
- English for code, comments and docs. Error messages say what happened and what to do.
- `README.md` is the source; keep the eight `README-XX.md` translations in sync when it changes.
- Commits: imperative subject line. Do not add `Co-Authored-By` trailers for AI tools.
