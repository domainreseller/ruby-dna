<div align="center">
  <a href="README-TR.md">TR <img style="padding-top: 8px" src="https://raw.githubusercontent.com/yammadev/flag-icons/master/png/TR.png" alt="TR" height="20" /></a>
  <a href="README.md"> | EN <img style="padding-top: 8px" src="https://raw.githubusercontent.com/yammadev/flag-icons/master/png/US.png" alt="EN" height="20" /></a>
  <a href="README-DE.md"> | DE <img style="padding-top: 8px" src="https://raw.githubusercontent.com/yammadev/flag-icons/master/png/DE.png" alt="DE" height="20" /></a>
  <a href="README-SA.md"> | SA <img style="padding-top: 8px" src="https://raw.githubusercontent.com/yammadev/flag-icons/master/png/SA.png" alt="AR" height="20" /></a>
  <a href="README-NL.md"> | NL <img style="padding-top: 8px" src="https://raw.githubusercontent.com/yammadev/flag-icons/master/png/NL.png" alt="NL" height="20" /></a>
  <a href="README-AZ.md"> | AZ <img style="padding-top: 8px" src="https://raw.githubusercontent.com/yammadev/flag-icons/master/png/AZ.png" alt="AZ" height="20" /></a>
  <a href="README-CN.md"> | CN <img style="padding-top: 8px" src="https://raw.githubusercontent.com/yammadev/flag-icons/master/png/CN.png" alt="CN" height="20" /></a>
  <a href="README-FR.md"> | FR <img style="padding-top: 8px" src="https://raw.githubusercontent.com/yammadev/flag-icons/master/png/FR.png" alt="FR" height="20" /></a>
  <a href="README-IT.md"> | IT <img style="padding-top: 8px" src="https://raw.githubusercontent.com/yammadev/flag-icons/master/png/IT.png" alt="IT" height="20" /></a>
</div>

# ruby-dna: the Ruby SDK for the Domain Name API

[![CI](https://github.com/domainreseller/ruby-dna/actions/workflows/ci.yml/badge.svg)](https://github.com/domainreseller/ruby-dna/actions/workflows/ci.yml)
[![License](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](LICENSE)

Ruby client for the [Domain Name API](https://www.domainnameapi.com) reseller REST API: domain search,
registration, renewal and transfer, DNS, DNSSEC, contacts, SSL certificates, hosting, orders, the product
catalogue and your balance.

- **All 67 API operations**, grouped the same way as the [`dna` CLI](https://github.com/domainreseller/cli):
  `dna domain info` is `client.domains.info`, `dna dns add` is `client.dns.add`.
- **Real objects, not hashes**: `domain.status.pending_delete?`, `domain.expiration_date` is a `Time`,
  `availability.available?`, `tld.register_price(1)`.
- **Every operation is a request class** that inherits from `DomainNameApi::BaseRequest` and validates itself
  before anything is sent. Write your own the same way.
- **Safe by default**: billable requests are never retried blindly, `read_only: true` blocks changes, the client
  paces itself under the rate limits and is safe to share between threads.
- **No dependencies.** Ruby 3.1 or newer, standard library only.

```ruby
client = DomainNameApi::Client.new(reseller_id: reseller_id, api_key: api_key, environment: :ote)

a = client.domains.search('example.com')
puts "#{a.domain_name} is available for #{a.price} #{a.currency}" if a.available?
```

## Contents

- [Install](#install)
- [Credentials and environments](#credentials-and-environments)
- [Services](#services)
- [Usage](#usage)
- [Results, models and enums](#results-models-and-enums)
- [Requests and BaseRequest](#requests-and-baserequest)
- [Errors](#errors)
- [Safety and reliability](#safety-and-reliability)
- [Client options](#client-options)
- [Testing your code](#testing-your-code)
- [Migrating from v1](#migrating-from-v1)
- [Development](#development)

## Install

> ⬇️ Use a tagged version from [Releases](https://github.com/domainreseller/ruby-dna/releases/latest). The
> green **Code → Download ZIP** button gives you the development branch.

With Bundler:

```ruby
# Gemfile
gem 'domainnameapi', git: 'https://github.com/domainreseller/ruby-dna.git', tag: 'v2.2.0'
```

Or install the `.gem` file attached to the release:

```bash
gem install ./domainnameapi-2.2.0.gem
```

```ruby
require 'domainnameapi'
```

Runnable programs are in [examples](examples): `quickstart`, `register`, `expiring`, `dns`, `ssl` and
`custom_request`.

```bash
DNA_RESELLER_ID=... DNA_API_KEY=... DNA_ENV=ote ruby examples/quickstart.rb example.com
```

## Credentials and environments

You need two API credentials from the reseller panel (**API settings**). Panel login details do not work.

| Credential  | Looks like                             |
|-------------|----------------------------------------|
| Reseller ID | `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx` |
| API key     | a long secret string                   |

There are two environments. **Start with OTE**, the test environment: it has its own data and its own API key,
and nothing you do there costs money or touches live domains.

```ruby
# Test environment (OTE)
client = DomainNameApi::Client.new(reseller_id: reseller_id, api_key: ote_api_key, environment: :ote)

# Production (the default): real registrations, real charges
client = DomainNameApi::Client.new(reseller_id: reseller_id, api_key: api_key)
```

`environment:` also accepts the strings panels store: `'production'`, `'ote'`, `'test'`, and test-mode flags
(`'true'`, `'1'`, `true`). `Client.from_env` reads the same variables as the `dna` CLI:

| Variable          | Meaning                                                       |
|-------------------|---------------------------------------------------------------|
| `DNA_RESELLER_ID` | reseller ID                                                   |
| `DNA_API_KEY`     | API key of the selected environment                           |
| `DNA_ENV`         | `production` (default) or `ote`                               |
| `DNA_TEST_MODE`   | `true` selects OTE (as in the other DomainNameAPI SDKs)       |
| `DNA_BASE_URL`    | a custom base URL, e.g. a proxy                               |
| `DNA_APP`         | your application, sent as `X-App` (default `ruby`)            |
| `DNA_APP_VERSION` | its version, sent as `X-Version` (default: the gem version)   |

```ruby
client = DomainNameApi::Client.from_env(user_agent: 'my-panel/1.4')
```

A wrong key or environment fails on the first request with an `APIError` whose `auth?` is true and whose `hint`
says what to check; `client.account.get` is the cheapest way to try.

## Services

| Service            | CLI group     | Methods                                                                                                                                                           |
|--------------------|---------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `client.account`   | `dna account` | `get`, `profile`, `transactions`, `all_transactions`                                                                                                              |
| `client.contacts`  | `dna contact` | `get`, `create`, `update`, `verification`, `resend_verification`                                                                                                  |
| `client.domains`   | `dna domain`  | `search`, `bulk_search`, `list`, `all`, `info`, `register`, `register_with_contacts`, `renew`, `renew_check`, `restore`, `transfer`, `transfer_check`, `transfer_status`, `lock`, `unlock`, `set_privacy`, `update_auth_code`, `set_name_servers`, `add_host`, `update_host`, `delete_host`, `update_contacts`, `set_contact_handles`, `documents`, `upload_documents`, `forwarding`, `set_forwarding`, `delete_forwarding` |
| `client.dns`       | `dna dns`     | `list`, `add`, `update`, `delete`, `apply`                                                                                                                        |
| `client.dnssec`    | `dna dnssec`  | `get`, `add`, `remove`, `disable`                                                                                                                                 |
| `client.ssl`       | `dna ssl`     | `generate_csr`, `check_csr`, `purchase`, `configure`, `status`, `get`, `content`, `reissue`, `approvers`, `revoke`, `renew`, `list`, `all`                        |
| `client.hosting`   | `dna hosting` | `packages`, `plans`, `create`, `wait`, `get`, `get_by_token`, `status`                                                                                            |
| `client.orders`    | `dna order`   | `get`                                                                                                                                                             |
| `client.products`  | `dna product` | `list`, `info`, `tlds`, `all_tlds`, `tld`, `ssls`                                                                                                                 |

Required inputs are positional (`info('example.com')`), everything else is a keyword
(`renew('example.com', years: 1)`). Operations with many optional inputs take keywords or a request object:
`register(domain_name: ..., years: 1, ...)` and `register(DomainNameApi::DomainRegisterRequest.new(...))` are the
same. `ssl.purchase` is the CLI's `dna ssl initialize` (`initialize` is reserved in Ruby).

## Usage

All snippets assume a `client`.

### Search

```ruby
a = client.domains.search('example.com')
a.available?            # a.price, a.currency, a.premium?, a.document_required?, a.reason

client.domains.bulk_search('example.com', 'example.net', 'example.org').each do |r|
  puts "#{r.domain_name} #{r.status} #{r.price}"
end
```

`bulk_search` splits lists longer than 30 domains into several requests. Prices use the account's currency, the
client's `currency: 'TRY'` option, or `search('example.com', currency: 'USD')`.

### Register

With contact handles (create one with `contacts.create`):

```ruby
handle = client.contacts.create(
  DomainNameApi::Contact.new(
    first_name: 'Ada', last_name: 'Lovelace', email: 'ada@example.com',
    address: '1 Example Street', city: 'Istanbul', state: 'Istanbul', postal_code: '34000',
    country: 'TR', phone_country_code: '90', phone: '5551234567'
  )
)

result = client.domains.register(
  domain_name: 'example.com', years: 1,
  name_servers: %w[ns1.example.net ns2.example.net],
  handles: handle # one handle for all four roles, or { registrant: 'DNA-1', admin: 'DNA-2', tech: ..., billing: ... }
)
result.status           # result.domain_id, result.expiration_date
```

With inline contacts:

```ruby
client.domains.register_with_contacts(
  domain_name: 'example.com',
  name_servers: %w[ns1.example.net ns2.example.net],
  contacts: owner # one Contact for all four roles, or { registrant: owner, admin: admin, tech: admin, billing: admin }
)
```

Contacts can be `DomainNameApi::Contact` objects or Hashes of the same fields. They are tidied before sending:
fields are trimmed, the country is upper-cased and phone fields keep only their digits
(`'+90 (555) 123-45-67'` works). Some TLDs need registry attributes: find them with
`client.products.tld('com.tr').required_attributes` and pass them as `tld_attributes:`.

If the API answers but refuses (`"success": false`), the method raises `DomainNameApi::OperationError` with the
API's message.

### Renew, transfer, restore

```ruby
check = client.domains.renew_check('example.com', years: 1)   # check.renewable?, check.premium_price
client.domains.renew('example.com', years: 1)

tc = client.domains.transfer_check('example.com', 'auth-code') # tc.transferable?, tc.auth_code_valid?
client.domains.transfer('example.com', auth_code: 'auth-code')
client.domains.transfer_status('example.com').status

client.domains.restore('example.com') # during the redemption period
```

### Domain details and the domain list

```ruby
d = client.domains.info('example.com')
d.status                # => #<DomainNameApi::DomainStatus Active (0)>
d.expiration_date       # => 2027-03-15 10:20:30 UTC
d.remaining_days, d.locked?, d.privacy_protection?, d.name_servers, d.auth_code, d.hosts
d.contact(:registrant)&.email

# One page
page = client.domains.list(limit: 50, sort: 'expirationDate')
page.total_count
page.each { |domain| puts domain.domain_name }

# Every domain; pages are fetched as you go
client.domains.all(statuses: [:active]) do |domain|
  puts "#{domain.domain_name} #{domain.expiration_date}"
end
client.domains.all.first(10) # an Enumerator without a block: fetches one page
```

### Lock, privacy, nameservers, child nameservers

```ruby
client.domains.lock('example.com')
client.domains.unlock('example.com')
client.domains.set_privacy('example.com', true)
code = client.domains.update_auth_code('example.com')

client.domains.set_name_servers('example.com', %w[ns1.example.net ns2.example.net])
client.domains.set_name_servers('example.com', %w[ns1.other.net ns2.other.net], dnssec_mode: :disable) # signed domains

client.domains.add_host('example.com', 'ns1.example.com', '192.0.2.10', '2001:db8::10') # IP version detected
client.domains.update_host('example.com', 'ns1.example.com', ip_addresses: ['192.0.2.20'])
client.domains.delete_host('example.com', 'ns1.example.com')
```

### Contacts of a domain

```ruby
client.domains.set_contact_handles('example.com', admin: 'DNA-2', tech: 'DNA-2') # other roles stay
client.domains.update_contacts('example.com', billing: billing_contact)

details = client.contacts.get('DNA-1')               # the contact and its verification state
result = client.contacts.update('DNA-1', contact)    # updates every domain using the handle
result.affected_domains.each { |a| puts "#{a.domain_name} #{a.new_handle}" }
client.contacts.resend_verification('DNA-1')          # false when there is nothing to verify
```

### DNS zone

```ruby
client.dns.add('example.com', name: 'www', type: :a, values: '192.0.2.10', ttl: 600)
client.dns.update('example.com', record_name: 'www', type: :a, values: %w[192.0.2.20 192.0.2.21]) # replaces the set
client.dns.delete('example.com', name: 'www', type: :a, value: '192.0.2.20')

client.dns.list('example.com').each do |set|
  puts "#{set.name} #{set.type} #{set.ttl} #{set.values.join(', ')}"
end

client.dns.apply('example.com') # switch the domain to the platform nameservers
```

Names can be relative (`'www'`), the apex (`''` or `'@'`) or fully qualified. Record types are symbols or strings
in any case (`:txt` and `'txt'` are sent as `TXT`). Validation catches what the API would reject: a CNAME at the
apex, a CAA value without three parts, an MX value without a priority, an A record with an IPv6 address. The test
environment answers every zone call with HTTP 500, so zone code can only be tried in production.

### DNSSEC

```ruby
results = client.dnssec.add('example.com', '2371 13 2 1F987CC6583E92DF0890718C42...') # as your DNS provider shows it
info = client.dnssec.get('example.com') # info.status.signed?, info.ds_records
client.dnssec.disable('example.com')
```

`DomainNameApi::DS.parse` reads the presentation format and whole zone-file lines; `DS.new(key_tag: ...,
algorithm: :ecdsa_p256_sha256, digest_type: :sha256, digest: '...')` works too.

### URL forwarding

```ruby
client.domains.set_forwarding('example.com', 'https://www.example.org')              # 301 redirect
client.domains.set_forwarding('example.com', 'https://www.example.org', type: :frame) # masked
f = client.domains.forwarding('example.com') # nil when the domain has none
client.domains.delete_forwarding('example.com')
```

### Registry documents (.tr)

```ruby
doc = DomainNameApi::DocumentUpload.from_file(:identity_card, 'id.pdf')
client.domains.upload_documents('example.com.tr', doc)
client.domains.documents('example.com.tr').each { |d| puts "#{d.name} #{d.status}" }
```

Files are base64-encoded for you; format (PDF, JPG, PNG, DOC, DOCX, ODT) and size (10 MB per file, 50 MB per
request) are checked before upload.

### SSL certificates

```ruby
csr = client.ssl.generate_csr(domain_name: 'example.com', country: 'TR', state: 'Istanbul', locality: 'Istanbul',
                              organization: 'Example Ltd', organization_unit: 'IT')
# charges the balance (CLI: dna ssl initialize)
order = client.ssl.purchase('example.com', package_code: 'PositiveSSL')
id = order.certificate_id # store it: every later call takes it
client.ssl.configure(certificate_id: id, csr: csr.csr, approver_mail: 'admin@example.com',
                     authentication_type: :email, web_server_type: :apache, contact: ssl_contact)
client.ssl.status(id).issued? # poll until true
File.write('example.com.crt', client.ssl.content(id).chain)
```

A domain can have several certificates, so an existing certificate is addressed by its `certificate_id` (a GUID),
never by its domain name: `purchase` and `renew` return it, and `list` finds it. A domain name where an id is
expected raises `InputError` before anything is sent. Configure a certificate within 15 days of buying or renewing
it.

```ruby
client.ssl.list(domain_name: 'example.com').each { |c| puts "#{c.certificate_id} #{c.status}" } # newest first
client.ssl.all { |c| puts "#{c.domain_name} #{c.subscription_expires_at}" } # every certificate, page by page

client.ssl.approvers(certificate_id: id)                                      # of an existing certificate
client.ssl.approvers(domain_name: 'example.com', package_code: 'PositiveSSL') # before a purchase

renewal = client.ssl.renew(id) # charges the balance; possible from 30 days before the subscription ends
client.ssl.configure(certificate_id: renewal.certificate_id, csr: new_csr.csr, approver_mail: 'admin@example.com',
                     authentication_type: :email, web_server_type: :apache, contact: ssl_contact)
```

To renew, call `renew` and then `configure` the new certificate it returns. Do not `purchase` again: that is an
unrelated new order at the purchase price, and the old certificate never becomes `Renewed`.

### Hosting

```ruby
client.hosting.packages.each { |p| puts p.service_plans.map(&:service_plan) }
created = client.hosting.create('example.com', service_plan: 'Linux-Starter') # charges the balance

st = client.hosting.wait(created.service_id, timeout: 30 * 60) # polls until active
puts st.panel_address, st.username, st.password
```

Never call `create` again for a hosting that is still provisioning: that charges twice.

### Balance, prices and orders

```ruby
account = client.account.get
account.balance('USD')
profile = client.account.profile # profile.company_name, profile.account_currency, profile.status.active?

client.account.all_transactions(from: Date.new(2026, 11, 1)) do |tx|
  puts "#{tx.creation_time} #{tx.type} #{tx.change}"
end

tld = client.products.tld('com.tr')
tld&.register_price(1)&.to_s   # => "12.50 USD"

client.products.info('com', order_type: :renew, years: 2) # price of a 2-year .com renewal
client.orders.get('ORDER-CODE')
```

## Results, models and enums

Every result is a `DomainNameApi::Model`: snake_case readers, `?` predicates for flags, `Time` objects for dates,
nested models and lists.

```ruby
d = client.domains.info('example.com')
d.locked?                 # also d.locked
d.hosts.first.ip_addresses.first.address
d.to_h                    # a plain Hash with snake_case keys
d.raw                     # the JSON object as the API sent it, for fields this gem does not model
```

Numeric and fixed-string values are enums (`DomainStatus`, `RecordType`, `ContactType`, `DocumentType`, ...):

```ruby
d.status.pending_delete?                       # a predicate per member
d.status == DomainNameApi::DomainStatus::ACTIVE
d.status == :active                            # symbols, names and numbers compare too
d.status.to_s                                  # => "Active"
d.status.to_i                                  # => 0
DomainNameApi::DomainStatus.members            # all of them
```

Requests accept enums, symbols, names in any case or numbers: `statuses: [:active, 'PendingDelete', 7]`.

Decoding is forgiving: dates without a timezone, `null`, `[]` instead of `{}`, numbers sent as strings, roles in
any case (`"registrant"`, `"ADMINISTRATIVE"`) and values this gem does not know yet all decode instead of failing
the call (`status.known?` is false for the last).

## Requests and BaseRequest

Every API operation is a request class: `DomainInfoRequest`, `DNSAddRequest`, `SSLConfigureRequest`, ... named
after the CLI command (`dna domain renew` is `DomainRenewRequest`). They all inherit from
`DomainNameApi::BaseRequest`, which supplies the plumbing: a class-level `endpoint` and `attribute` DSL, keyword
initialisation, validation helpers, path templates and query/body builders. List requests inherit from
`PagedRequest`, which adds `skip`, `limit` and `sort`. A request from this gem looks like this:

```ruby
class DomainRenewRequest < BaseRequest
  endpoint :post, '/api/v1/domains/renew', safety: :billable
  returns DomainOperationResult
  attribute :domain_name
  attribute :years

  def body
    domain_body.merge(optional('period' => years))
  end

  def validate
    required :domain_name
    check years.to_i.between?(1, 10), :years, 'must be between 1 and 10'
  end
end
```

The service methods build these for you. `client.call` sends any request, including classes of your own, for
example to read only the fields you need or to call an endpoint this gem does not wrap yet:

```ruby
class Expiry < DomainNameApi::Model
  field :expiration_date, :time
  field :remaining_days, :integer, from: 'remainingDay'
end

class ExpiryRequest < DomainNameApi::BaseRequest
  endpoint :get, '/api/v1/domains/info', safety: :read
  returns Expiry            # leave it out to get the parsed JSON
  attribute :domain_name

  def query
    params.string('DomainName', domain_name)
  end

  def validate
    required :domain_name
  end
end

expiry = client.call(ExpiryRequest.new(domain_name: 'example.com'))
expiry.expiration_date
```

| Override       | Default         | Purpose                                                                     |
|----------------|-----------------|-----------------------------------------------------------------------------|
| `query`        | `nil`           | a `Query` (`params.string(...)`), a Hash or an Array of pairs                |
| `body`         | `nil`           | a Hash or Array with the API's names; enums, models and times are converted |
| `validate`     | nothing to check| report problems with `required`, `check`, `between`, `max_length`, `enum`   |
| `decode(data)` | uses `returns`  | turn the parsed JSON into your result                                        |

Path placeholders are filled from attributes and escaped: `endpoint :get, '/api/v1/contacts/{handle}'`.

Your request gets everything the built-in ones get: credentials, retries, pacing, error normalisation,
correlation IDs, tracing and read-only enforcement. `client.execute(request)` returns the whole `Response`
(status, headers, raw body, correlation ID, quota, attempts) with the decoded result in `value`.
`client.prepare(request)` validates and builds the exact HTTP request without sending it, to log or review a
billable request before it goes out (the API key is masked in `inspect`).

## Errors

| Error                            | When                                                       | Useful methods                                                                 |
|----------------------------------|------------------------------------------------------------|--------------------------------------------------------------------------------|
| `DomainNameApi::InputError`      | validation rejected the request; **nothing was sent**      | `request`, `fields`                                                            |
| `DomainNameApi::APIError`        | the API answered with a non-2xx status                     | `status`, `code`, `api_message`, `details`, `fields`, `data`, `correlation_id`, `hint` |
| `DomainNameApi::OperationError`  | the API answered 2xx with `"success": false`               | `code`, `api_message`, `correlation_id`                                        |
| `DomainNameApi::NetworkError`    | the request did not complete (DNS, TLS, timeout, reset)    | `original`, `timeout?`                                                         |
| `DomainNameApi::ReadOnlyError`   | a read-only client blocked a change; nothing was sent      | `safety`                                                                       |

All of them inherit from `DomainNameApi::Error`, which answers the common questions: `kind` (`:auth`,
`:not_found`, `:validation`, `:rejected`, `:conflict`, `:rate_limited`, `:server`, `:network`, `:invalid_input`,
`:read_only`), `not_found?`, `auth?`, `rate_limited?`, `insufficient_balance?`, `outcome_unknown?`,
`retryable?` and `code?(code)`.

```ruby
begin
  client.domains.renew('example.com', years: 1)
rescue DomainNameApi::Error => e
  if e.outcome_unknown?
    # The renewal may have gone through. Check the domain before trying again.
  elsif e.insufficient_balance?
  elsif e.not_found?
  elsif e.code?(DomainNameApi::ErrorCode::PRIVACY_NOT_SUPPORTED)
  elsif e.is_a?(DomainNameApi::APIError)
    logger.error("#{e.code} #{e.api_message} #{e.hint} #{e.correlation_id}")
  end
end
```

Branch on `code`, not on the message: messages are localised. API codes look like
`Dna.DomainService:Domain:10007`; the common ones are constants in `DomainNameApi::ErrorCode`, the rest are in the
[error reference](https://www.domainnameapi.com/docs/reference/errors.md). Quote the `correlation_id` when
contacting support.

## Safety and reliability

- **Safety classes.** Every request is `:read`, `:write`, `:destructive` or `:billable` (`request.safety`,
  `request.billable?`). Some POST and PUT requests are reads (`DomainSearchRequest`, `SSLStatusRequest`).
- **Read-only mode.** `read_only: true` blocks everything that is not a read, for reporting jobs and for
  exploring production safely.
- **Retries.** 429 answers are always retried, honouring `Retry-After`: the API rejects them before doing
  anything. Network errors and 502/503/504 are retried only for reads and idempotent writes, so a registration
  or renewal is never sent twice. After a failed billable request, check `e.outcome_unknown?`.
- **Pacing.** The client spaces requests to stay under the per-key limits (5 requests/second, 2 searches/second,
  one zone call per second). Turn it off with `pacing: false` if you pace yourself.
- **Quota.** `client.execute(request).quota` exposes the soft-quota headers. Over the limit the API slows
  responses down (up to 5 s) instead of rejecting them; the default 60 s timeout leaves room for that.
- **Correlation IDs.** Each request carries an `X-Correlation-ID`. Set your own to tie API calls to your logs:
  `DomainNameApi.with_correlation_id(job.id) { ... }` or `client.call(request, correlation_id: job.id)`.
- **Observability.** `logger: Logger.new($stdout)` logs every exchange; `on_trace: ->(event) { ... }` hands you
  every request, response and retry as a `TraceEvent`, for metrics or error reporting. The API key is never in
  them; bodies can hold contact data, so mask them before storing.
- **Threads.** A client is safe to share between threads. Create one and reuse it.
- **Nothing else leaves your process.** No telemetry, no third-party services.

## Client options

| Option                       | Effect                                                                              |
|------------------------------|-------------------------------------------------------------------------------------|
| `environment: :ote`          | use the test environment (default `:production`)                                    |
| `base_url: 'https://...'`    | send requests to a proxy or a test server                                           |
| `timeout: 60`                | seconds per HTTP attempt                                                            |
| `open_timeout: 10`           | seconds to connect                                                                  |
| `user_agent: 'app/1.0'`      | put your product in front of the User-Agent                                         |
| `app_name: 'whmcs'`          | your application, sent as the `X-App` header (default `ruby`)                       |
| `app_version: '8.13.1'`      | its version, sent as the `X-Version` header (default: the gem version)              |
| `currency: 'TRY'`            | currency of search and catalogue prices                                             |
| `retries: 2`                 | retry count                                                                         |
| `max_retry_wait: 30`         | the longest `Retry-After` the client waits for                                      |
| `pacing: false`              | turn client-side pacing off                                                         |
| `read_only: true`            | block every non-read request                                                        |
| `logger: Logger.new($stdout)`| log exchanges: requests at debug, retries at warn, failures at error level          |
| `on_trace: ->(event) {}`     | observe every request, response and retry                                           |
| `transport: my_transport`    | your own HTTP layer (proxy, connection pool, ...): any object with `call(request)`  |

`DomainNameApi::NetHTTPTransport.new(proxy: 'http://proxy:8080', ca_file: 'corp-ca.pem')` is the default
transport with a proxy or your own CA bundle. Redirects are never followed: the API answers 302 for an unknown
or suspended reseller ID, which becomes an authentication error.

### Identifying your integration

Every request carries two headers that tell the API which application sends it: `X-App` (default `ruby`)
and `X-Version` (default: the gem version). Set them to your panel or module and its version:

```ruby
client = DomainNameApi::Client.new(reseller_id: reseller_id, api_key: api_key,
                                   app_name: 'WiseCP', app_version: 'V2.0.20-beta')
# X-App: wisecp, X-Version: 2.0.20
```

The name is lowercased and only `a-z`, `0-9`, `.`, `_` and `-` are kept; the version keeps only digits and
dots. An empty name falls back to `ruby`, an empty version to the gem version. `Client.from_env` reads them
from `DNA_APP` and `DNA_APP_VERSION`. The User-Agent does not change.

## Testing your code

Pass a transport that answers like the API; nothing else needs mocking:

```ruby
class FakeAPI
  def call(request)
    DomainNameApi::HTTPResponse.new(
      status: 200, headers: {},
      body: '{"success":true,"info":{"domainName":"example.com","status":"AVAILABLE","price":11.99,"currency":"USD"}}'
    )
  end
end

client = DomainNameApi::Client.new(reseller_id: 'r', api_key: 'k', transport: FakeAPI.new, pacing: false)
client.domains.search('example.com').available? # => true
```

`request` is a `DomainNameApi::PreparedRequest` (`http_method`, `url`, `headers`, `body`), so the fake can also
assert what was sent. WebMock and VCR work too, since the default transport is `Net::HTTP`.

## Migrating from v1

v2 is a new design: typed results instead of String-keyed Hashes, exceptions instead of `{'result' => 'ERROR'}`
envelopes, and the full API instead of the php-dna method set. The gem name stays `domainnameapi`; pin
`tag: 'v1.0.1'` to keep v1 until you switch.

| v1                                                   | v2                                                                       |
|------------------------------------------------------|--------------------------------------------------------------------------|
| `Client.new(id, key, true)`                          | `Client.new(reseller_id: id, api_key: key, environment: :ote)`           |
| `res['result'] == 'OK'`                              | no exception                                                             |
| `get_reseller_details`, `get_current_balance`        | `account.get` (+ `account.balance('USD')`)                               |
| `check_availability`                                 | `domains.search`, `domains.bulk_search`                                  |
| `get_list`                                           | `domains.list`, `domains.all`                                            |
| `get_tld_list`                                       | `products.tlds`, `products.all_tlds`, `products.tld`                     |
| `get_details`, `get_contacts`, `sync_from_registry`  | `domains.info`                                                           |
| `register_with_contact_info`                         | `domains.register_with_contacts` (or `contacts.create` + `domains.register`) |
| `renew`, `transfer`, `check_transfer`                | `domains.renew`, `domains.transfer`, `domains.transfer_check`            |
| `modify_name_server`                                 | `domains.set_name_servers`                                               |
| `enable_theft_protection_lock` / `disable_...`       | `domains.lock` / `domains.unlock`                                        |
| `modify_privacy_protection_status`                   | `domains.set_privacy`                                                    |
| `save_contacts`                                      | `domains.update_contacts`, `domains.set_contact_handles`                 |
| `add_child_name_server`, `modify_child_name_server`, `delete_child_name_server` | `domains.add_host`, `domains.update_host`, `domains.delete_host` |
| `get_resource_records`                               | `dns.list`                                                               |
| `add_resource_record`, `add_resource_record_value`   | `dns.add`                                                                |
| `edit_resource_record`, `set_resource_record_set`, `replace_resource_record_value` | `dns.update`                               |
| `delete_resource_record`, `remove_resource_record_value`, `delete_resource_record_set` | `dns.delete` (once per value)          |
| `apply_resource_records`                             | `dns.apply`                                                              |
| `get_forwarding`, `set_forwarding`, `delete_forwarding` | `domains.forwarding`, `domains.set_forwarding`, `domains.delete_forwarding` |
| `cancel_transfer`, `approve_transfer`, `reject_transfer` | not in the published API; send a [request of your own](#requests-and-baserequest) if your account has them |
| `is_tr_tld`, `validate_contact`                      | `name.end_with?('.tr')`; validation runs on every request                |
| `get_request_data`, `get_response_data`, ...         | `on_trace:`, `logger:`, `client.execute(request)`                        |
| telemetry (`set_error_reporting_enabled`, Sentry)    | removed: nothing leaves your process; forward `on_trace` events to your own reporting |
| `set_ssl_verification(false)`                        | `transport: NetHTTPTransport.new(ca_file: ...)` with your own CA bundle  |

## Development

```bash
bundle install
bundle exec rake test   # unit tests; none touches the network
```

`test/fixtures/openapi.json` is the API's OpenAPI document. The tests check every request class against it
(method, path, query names, body fields, required fields), every response model's JSON names against the response
schemas and every enum value, and fail when the API gains an operation without a request class. To update it:

```bash
curl -fsSL -A "ruby-dna-spec-update" -o test/fixtures/openapi.json https://api.domainresellerapi.com/swagger/v1/swagger.json
bundle exec rake test
```

See [AGENTS.md](AGENTS.md) for the conventions of this repository.

## Support

- API documentation: <https://www.domainnameapi.com/docs/>
- CLI and MCP server: <https://github.com/domainreseller/cli>
- Website: <https://www.domainnameapi.com>

## License

Apache License 2.0. See [LICENSE](LICENSE).
