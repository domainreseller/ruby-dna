<div align="center">
  <a href="README-TR.md"   >   TR <img style="padding-top: 8px" src="https://raw.githubusercontent.com/yammadev/flag-icons/master/png/TR.png" alt="TR" height="20" /></a>
  <a href="README.md"> | EN <img style="padding-top: 8px" src="https://raw.githubusercontent.com/yammadev/flag-icons/master/png/US.png" alt="EN" height="20" /></a>
   <a href="README-DE.md"> | DE <img style="padding-top: 8px" src="https://raw.githubusercontent.com/yammadev/flag-icons/master/png/DE.png" alt="DE" height="20" /></a>
  <a href="README-SA.md"> | SA <img style="padding-top: 8px" src="https://raw.githubusercontent.com/yammadev/flag-icons/master/png/SA.png" alt="AR" height="20" /></a>
  <a href="README-NL.md"> | NL <img style="padding-top: 8px" src="https://raw.githubusercontent.com/yammadev/flag-icons/master/png/NL.png" alt="NL" height="20" /></a>
  <a href="README-AZ.md"> | AZ <img style="padding-top: 8px" src="https://raw.githubusercontent.com/yammadev/flag-icons/master/png/AZ.png" alt="AZ" height="20" /></a>
  <a href="README-CN.md"> | CN <img style="padding-top: 8px" src="https://raw.githubusercontent.com/yammadev/flag-icons/master/png/CN.png" alt="CN" height="20" /></a>
  <a href="README-FR.md"> | FR <img style="padding-top: 8px" src="https://raw.githubusercontent.com/yammadev/flag-icons/master/png/FR.png" alt="FR" height="20" /></a>
  <a href="README-IT.md"> | IT <img style="padding-top: 8px" src="https://raw.githubusercontent.com/yammadev/flag-icons/master/png/IT.png" alt="IT" height="20" /></a>
</div>

# ruby-dna — DomainNameAPI client for Ruby

Register, renew and transfer domains, manage contacts, nameservers, child nameservers, DNS zones and URL forwarding through the DomainNameAPI REST API. `ruby-dna` is a faithful port of [php-dna](https://github.com/domainreseller/php-dna): the same methods, the same requests on the wire and the same return values, verified against php-dna's conformance fixtures.

## 📦 Download — always use Releases!

⬇️ **Get the latest tested version here: https://github.com/domainreseller/ruby-dna/releases/latest**

> ⚠️ Do **not** use the green **Code → Download ZIP** button — that downloads the raw development branch. Release packages are versioned, tested and production-ready.

## Installation and Integration Guide

### Minimum Requirements

- Ruby 2.7 or higher (Recommended 3.3+)
- No runtime dependencies: only the standard library (`net/http`, `json`, `openssl`).

### A) Bundler

```ruby
# Gemfile
gem 'domainnameapi', git: 'https://github.com/domainreseller/ruby-dna.git', tag: 'v1.0.0'
```

```bash
bundle install
```

### B) Gem file from the release

Download `domainnameapi-1.0.0.gem` from the [latest release](https://github.com/domainreseller/ruby-dna/releases/latest), then:

```bash
gem install ./domainnameapi-1.0.0.gem
```

### C) Manual usage

Download the release archive, copy the `lib` folder into your project and look at the examples in the [examples](examples) folder:

```ruby
$LOAD_PATH.unshift File.expand_path('lib', __dir__)
require 'domainnameapi'
```

## 🔑 API Credentials — Reseller ID & API Key

The library talks to the DomainNameAPI REST API and needs exactly two credentials, passed to the constructor:

| Parameter | Value |
|---|---|
| First | Reseller ID — UUID like `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx` |
| Second | API Key |

> 💡 Find your **Reseller ID** and **API Key** in your DomainNameAPI panel under **API Settings**.
> ⚠️ These are **API credentials** — your panel login details will **not** work here.

## Quick start

```ruby
require 'domainnameapi'

reseller_id = 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx'
api_key     = 'your-api-key'

# Live environment
dna = DomainNameApi::Client.new(reseller_id, api_key)

# Test (OTE) environment
dna = DomainNameApi::Client.new(reseller_id, api_key, true)

result = dna.get_details('example.com')
if result['result'] == 'OK'
  puts result['data']['Dates']['Expiration']
else
  puts "#{result['error']['Code']}: #{result['error']['Message']}"
end
```

Method names are the snake_case form of php-dna's (`getDetails` → `get_details`, `registerWithContactInfo` → `register_with_contact_info`), with the same parameter order and defaults. Results are plain Ruby Hashes and Arrays with **String keys**, exactly the structure php-dna returns (including string flags such as `'LockStatus' => 'true'` and formatted prices such as `'11.9900'`). Credentials are trimmed, and the test-mode flag also accepts strings: `"true"`, `"1"`, `"on"` and `"yes"` mean test mode, anything else means live.

## Error handling

Methods never raise for API or network problems. A failed call returns an error envelope:

```ruby
{
  'result' => 'ERROR',
  'error'  => {
    'Code'    => 'API_404',
    'Message' => 'The domain name you requested could not be found',
    'Details' => '...'
  }
}
```

- `Code` is `API_<HTTP status>` for gateway errors (`API_400`, `API_401`, `API_429`, `API_500`, ...). A `301`/`302` answer means bad credentials (`Invalid API credentials`).
- When the gateway sends its own error code, the envelope also carries it as `GatewayCode` (e.g. `'GatewayCode' => 'Dna.DomainService:Domain:10007'`), so you can tell one `API_404` from another.
- An empty error body becomes a readable message such as `HTTP 429 - Too Many Requests`. The raw response body is never used as the message when the gateway's message is boilerplate; a stable text naming the gateway code is used instead.
- Field validation errors are flattened into `Details`, e.g. `Admin PostalCode - 'PostalCode' is required`.
- Network failures are errors, never an empty success. A timeout reads `Could not reach the DomainNameAPI service: the connection timed out. (...)`; other transport failures read `Curl error during request: ...`. Their codes are `CURL_<n>` with curl's numbers (`CURL_28` timeout, `CURL_6` DNS, `CURL_7` connection refused, `CURL_35`/`CURL_60` TLS, `CURL_56` reset); `API_<n>` is reserved for HTTP statuses.
- A registration, transfer or renewal that the gateway answers with HTTP 200 but `"success": false` is a refusal, not a success: it returns the error envelope with code `REGISTER_DOMAIN`, `TRANSFER_DOMAIN` or `RENEW_DOMAIN` and the gateway's message.
- `get_current_balance` keeps its own envelope: `'OperationResult' => 'FAILED'` with `ErrorCode` and `OperationMessage`.
- `check_availability` returns a plain list on success and the error envelope on failure.

Only programmer errors raise (for example `set_resource_record_set` with `contents` that is not a list raises `TypeError`).

Timeouts are 30 seconds per call and 10 seconds to connect. Calls to the DNS zone endpoints are kept at least one second apart, because the gateway answers `HTTP 429` to bursts.

### Diagnostics

```ruby
dna.get_request_data         # { 'url' => ..., 'method' => 'GET', 'payload' => {...} } of the last call
dna.get_response_data        # last decoded response body (or { 'raw_response' => body })
dna.get_response_headers     # { 'url', 'http_code', 'headers', 'total_time' }
dna.get_parsed_response_data # last parsed body, or the last error { 'Code', 'Message', 'Details' }
dna.get_last_function        # e.g. 'request:GET domains/info'
dna.get_service_url          # https://api.domainresellerapi.com/api/v1
dna.set_service_url('https://ote.domainresellerapi.com/api/v1')
```

## Test mode

Pass `true` as the third constructor argument to use the OTE test gateway (`https://ote.domainresellerapi.com/api/v1`). Live calls go to `https://api.domainresellerapi.com/api/v1`. Test mode uses separate test credentials.

## Error reporting (telemetry)

When an API call fails, the library can send an error report to DomainNameAPI's own error tracker (Sentry). A small random share of successful calls (4%, plus every call slower than 1 second) can be sent as a performance record. This helps DomainNameAPI find and fix problems. Error reporting is **on by default**.

> ℹ️ In version 1.0.0 the Sentry project for ruby-dna does not exist yet, so the built-in DSN is empty and **nothing is sent**. Reports start once a release ships the DSN. `DomainNameApi::Client.new(id, key, false, sentry_dsn: '...')` sets one explicitly.

**What is sent:**

- error code and message
- called endpoint path and HTTP method
- call duration
- library name (`DomainNameAPI-Ruby`), library version and Ruby version
- reseller ID and domain name
- the server's public IP address (looked up via `api.ipify.org`, in the background)
- the operating-system user name the process runs as
- the API request and response, including the domain's contact details; only credentials are masked — EPP/auth codes, API keys, passwords and tokens are replaced with `***`

**What is never sent:** EPP/auth codes, API keys, passwords or tokens in readable form; method arguments in stack traces.

Expected, high-volume errors (domain not found, insufficient balance, invalid credentials, ...) are not reported. Reports are posted from a background thread with short timeouts: they never slow down or break your call.

**Why and how long:** the data is used only for usage measurement and early diagnosis of problems, and is kept for 30 days on DomainNameAPI's own Sentry server, after which it is deleted automatically.

**How to turn it off:**

```ruby
dna = DomainNameApi::Client.new(reseller_id, api_key)
dna.set_error_reporting_enabled(false)
```

**Minimal mode** sends only the error code and message, endpoint, timing, versions and the reseller ID — no request/response data, domain, server IP or user name:

```ruby
dna.set_telemetry_minimal(true)
```

> 🔒 **Security:** TLS certificate verification is on. On a host with an outdated CA bundle it can be switched off with `dna.set_ssl_verification(false)` — this is not recommended; updating the CA bundle is the better fix.

## Usage

All examples assume `dna = DomainNameApi::Client.new(reseller_id, api_key)`. Runnable scripts for every method are in [examples](examples).

### Account

#### Reseller details

```ruby
dna.get_reseller_details
```

<details>
<summary>Sample output</summary>

```ruby
{
  'result'   => 'OK',
  'id'       => 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx',
  'active'   => true,
  'name'     => 'example-reseller',
  'balance'  => '601.64',
  'currency' => 'USD',
  'symbol'   => '$',
  'balances' => [
    { 'balance' => '601.64',  'currency' => 'USD', 'symbol' => '$' },
    { 'balance' => '1250.50', 'currency' => 'TL',  'symbol' => 'TL' }
  ]
}
```

</details>

#### Current balance

`get_current_balance(currency = 'USD')` — the account reports `'USD'` and `'TRY'` balances. For any other currency (`'EUR'`, `'GBP'`, ...) the call fails with `'ErrorCode' => 'BALANCE'` instead of answering `0.00`.

```ruby
dna.get_current_balance('USD')
```

<details>
<summary>Sample output</summary>

```ruby
{
  'ErrorCode'        => 0,
  'OperationMessage' => 'Command completed succesfully.',
  'OperationResult'  => 'SUCCESS',
  'Balance'          => '601.64',
  'CurrencyId'       => 2,
  'CurrencyInfo'     => nil,
  'CurrencyName'     => 'USD',
  'CurrencySymbol'   => '$'
}
# get_current_balance('EUR')
{
  'ErrorCode'        => 'BALANCE',
  'OperationMessage' => 'No EUR balance is reported for this account. Available: USD, TRY.',
  'OperationResult'  => 'FAILED',
  'Balance'          => '0.00',
  'CurrencyId'       => 3,
  'CurrencyInfo'     => nil,
  'CurrencyName'     => 'EUR',
  'CurrencySymbol'   => '€'
}
```

</details>

<hr style="border: 4px solid #000; border-style: dashed;">

### Search and lists

#### Domain availability check

`check_availability(domains, extensions, period, command = 'create')` — `DomainName` in the result is the name without its trailing `.tld`.

```ruby
dna.check_availability(['hello', 'world123x0'], ['com', 'net'], 1, 'create')
```

<details>
<summary>Sample output</summary>

```ruby
[
  { 'TLD' => 'com', 'DomainName' => 'hello', 'Status' => 'notavailable', 'Command' => 'create',
    'Period' => 1, 'IsFee' => false, 'Price' => '10.8100', 'Currency' => 'USD', 'Reason' => 'Domain exists' },
  { 'TLD' => 'com', 'DomainName' => 'world123x0', 'Status' => 'available', 'Command' => 'create',
    'Period' => 1, 'IsFee' => false, 'Price' => '10.8100', 'Currency' => 'USD', 'Reason' => nil }
]
```

</details>

#### Domain list

`get_list(extra_parameters = {})` — `PageNumber` (0-based), `PageSize`, `OrderColumn`, `OrderDirection` and the gateway's own filters (e.g. `DomainName`).

```ruby
dna.get_list('OrderColumn' => 'Id', 'OrderDirection' => 'ASC', 'PageNumber' => 0, 'PageSize' => 1000)
```

<details>
<summary>Sample output</summary>

```ruby
{
  'data' => {
    'Domains' => [
      {
        'ID' => 564346, 'Status' => 'Active', 'DomainName' => 'example.com', 'AuthCode' => '',
        'LockStatus' => 'true', 'PrivacyProtectionStatus' => 'false', 'IsChildNameServer' => 'false',
        'Contacts' => { 'Billing' => { 'ID' => '' }, 'Technical' => { 'ID' => '' },
                        'Administrative' => { 'ID' => '' }, 'Registrant' => { 'ID' => '' } },
        'Dates' => { 'Start' => '2024-03-15T10:00:00', 'Expiration' => '2027-03-15T10:00:00', 'RemainingDays' => 126 },
        'NameServers' => ['ns1.example.com', 'ns2.example.com'],
        'Additional' => {},
        'ChildNameServers' => []
      }
    ]
  },
  'result'     => 'OK',
  'TotalCount' => 1
}
```

</details>

#### TLD list

`get_tld_list(count = 20)`

```ruby
dna.get_tld_list(100)
```

<details>
<summary>Sample output</summary>

```ruby
{
  'data' => [
    {
      'id' => 1, 'status' => 'Active', 'maxchar' => 63, 'maxperiod' => 10, 'minchar' => 1, 'minperiod' => 1,
      'tld' => 'com',
      'pricing' => {
        'registration' => { '1' => '10.8100' },
        'renew'        => { '1' => '11.0100' },
        'transfer'     => { '1' => '10.6100' },
        'restore'      => { '1' => '99.9000' }
      },
      'currencies' => { 'registration' => 'USD', 'renew' => 'USD', 'transfer' => 'USD', 'restore' => 'USD' }
    }
  ],
  'result' => 'OK'
}
```

</details>

<hr style="border: 4px solid #000; border-style: dashed;">

### Domain

#### Domain registration

`register_with_contact_info(domain, period, contacts, name_servers = [], epp_lock = true, privacy_lock = false, additional_attributes = {})`

Contacts use php-dna's keys. Both the flat shape below and the nested one returned by `get_contacts` (`Address => { Line1, City, ... }`, `Phone => { Phone => { Number, CountryCode } }`) are accepted; missing fields are completed and names, phones and countries are normalized (see `validate_contact`). With no nameservers, `ns1.domainnameapi.com` and `ns2.domainnameapi.com` are used.

```ruby
contact = {
  'FirstName'        => 'John',
  'LastName'         => 'Doe',
  'Company'          => 'Example Corp',
  'EMail'            => 'john.doe@example.com',
  'AddressLine1'     => '123 Lorem Street',
  'AddressLine2'     => 'Suite 456',
  'AddressLine3'     => '',
  'City'             => 'Springfield',
  'Country'          => 'US',
  'Fax'              => '1234567890',
  'FaxCountryCode'   => '1',
  'Phone'            => '9876543210',
  'PhoneCountryCode' => 1,
  'Type'             => 'Contact',
  'ZipCode'          => '12345',
  'State'            => 'IL'
}

dna.register_with_contact_info(
  'example.com',
  1,
  { 'Administrative' => contact, 'Billing' => contact, 'Technical' => contact, 'Registrant' => contact },
  ['ns1.example.com', 'ns2.example.com'],
  true,
  false
)
```

For `.tr` domains pass the TRABIS attributes as the 7th argument:

```ruby
# Individual owner
{ 'TRABISDOMAINCATEGORY' => 1, 'TRABISCITIZIENID' => '12345678901' }
# Company owner
{ 'TRABISDOMAINCATEGORY' => 0, 'TRABISTAXOFFICE' => 'Istanbul VD', 'TRABISTAXNUMBER' => '1234567890' }
```

The category is sent as `Owner`/`Corporate`, `TRABISCITIZIENID` as `TRABISCITIZENID`, and legacy keys (`TRABISNAMESURNAME`, `TRABISCOUNTRYID`, `TRABISCITYID`, ...) are dropped, because the gateway now reads them from the contact.

<details>
<summary>Sample output</summary>

```ruby
{
  'data' => {
    'ID' => 123456, 'Status' => 'Active', 'DomainName' => 'example.com', 'AuthCode' => 'Xy9#mK2$pL5@vN8',
    'LockStatus' => 'true', 'PrivacyProtectionStatus' => 'false', 'IsChildNameServer' => 'false',
    'Contacts' => { 'Billing' => { 'ID' => 987654 }, 'Technical' => { 'ID' => 987654 },
                    'Administrative' => { 'ID' => 987654 }, 'Registrant' => { 'ID' => 987654 } },
    'Dates' => { 'Start' => '2024-03-15T10:00:00', 'Expiration' => '2025-03-15T10:00:00', 'RemainingDays' => 365 },
    'NameServers' => ['ns1.example.com', 'ns2.example.com'],
    'Additional' => {},
    'ChildNameServers' => []
  },
  'result' => 'OK'
}
```

</details>

#### Domain renewal

```ruby
dna.renew('example.com', 1)
```

<details>
<summary>Sample output</summary>

```ruby
{ 'result' => 'OK', 'data' => { 'ExpirationDate' => '2025-03-15T10:00:00' } }
```

</details>

#### Domain details

```ruby
dna.get_details('example.com')
```

<details>
<summary>Sample output</summary>

```ruby
{
  'data' => {
    'ID' => 564346, 'Status' => 'Active', 'DomainName' => 'example.com', 'AuthCode' => 'DHQ!K52',
    'LockStatus' => 'true', 'PrivacyProtectionStatus' => 'false', 'IsChildNameServer' => 'true',
    'Contacts' => { 'Billing' => { 'ID' => 'DNA-B-4' }, 'Technical' => { 'ID' => 'DNA-T-3' },
                    'Administrative' => { 'ID' => 'DNA-A-2' }, 'Registrant' => { 'ID' => 'DNA-R-1' } },
    'Dates' => { 'Start' => '2025-05-26T16:08:37', 'Expiration' => '2027-05-26T16:08:37', 'RemainingDays' => 449 },
    'NameServers' => ['ns1.example.com', 'ns2.example.com'],
    'Additional' => {},
    'ChildNameServers' => [{ 'ns' => 'ns1.example.com', 'ip' => '1.2.3.4' }]
  },
  'result' => 'OK'
}
```

</details>

#### Sync from registry

Same call and output as `get_details`.

```ruby
dna.sync_from_registry('example.com')
```

#### Nameserver modification

Pass a list or a Hash (the values are used). Names are trimmed, lower-cased, stripped of a trailing dot and de-duplicated; the result reports that normalised list.

```ruby
dna.modify_name_server('example.com', ['ns1.example.com', 'ns2.example.com'])
```

<details>
<summary>Sample output</summary>

```ruby
{ 'result' => 'OK', 'data' => { 'NameServers' => ['ns1.example.com', 'ns2.example.com'] } }
```

</details>

#### Enable domain lock

```ruby
dna.enable_theft_protection_lock('example.com')
```

<details>
<summary>Sample output</summary>

```ruby
{ 'result' => 'OK', 'data' => { 'LockStatus' => true } }
```

</details>

#### Disable domain lock

```ruby
dna.disable_theft_protection_lock('example.com')
```

<details>
<summary>Sample output</summary>

```ruby
{ 'result' => 'OK', 'data' => { 'LockStatus' => false } }
```

</details>

#### Modify domain privacy

`modify_privacy_protection_status(domain, status, reason = 'Owner request')` — `status` may be `true`/`false` or a panel-style value: `1`, `'1'`, `'true'`, `'on'` and `'yes'` enable privacy, anything else disables it. The result reports the parsed boolean. `reason` is accepted for compatibility but not sent: the gateway has no such field.

```ruby
dna.modify_privacy_protection_status('example.com', true, 'Owner request')
```

<details>
<summary>Sample output</summary>

```ruby
{ 'data' => { 'PrivacyProtectionStatus' => true }, 'result' => 'OK' }
```

</details>

#### Get domain contacts

Contact types are matched case-insensitively (`admin`/`administrative`, `tech`/`technical`, `registrant`/`owner`, `billing`); other types the registry returns are kept after the four standard ones.

```ruby
dna.get_contacts('example.com')
```

<details>
<summary>Sample output</summary>

```ruby
{
  'data' => {
    'contacts' => {
      'Administrative' => {
        'ID' => 'DNA-A-2', 'Status' => 'Active', 'AuthCode' => '',
        'FirstName' => 'Grace', 'LastName' => 'Hopper', 'Company' => '', 'EMail' => 'grace@example.com',
        'Type' => 'Administrative',
        'Address' => { 'Line1' => 'Example Street 2', 'Line2' => '', 'Line3' => '', 'State' => 'DC',
                       'City' => 'Washington', 'Country' => 'US', 'ZipCode' => '20001' },
        'Phone' => { 'Phone' => { 'Number' => '2025550100', 'CountryCode' => '1' },
                     'Fax'   => { 'Number' => '2025550101', 'CountryCode' => '1' } },
        'Additional' => {}
      },
      'Billing' => { ... }, 'Registrant' => { ... }, 'Technical' => { ... }
      # any other contact type the registry returns follows these four
    }
  },
  'result' => 'OK'
}
```

</details>

#### Save domain contacts

```ruby
dna.save_contacts('example.com', {
  'Administrative' => contact,
  'Billing'        => contact,
  'Technical'      => contact,
  'Registrant'     => contact
})
```

<details>
<summary>Sample output</summary>

```ruby
{ 'result' => 'OK', 'data' => { 'contacts' => {} } }
```

</details>

<hr style="border: 4px solid #000; border-style: dashed;">

### Child nameservers

#### Add child nameserver

```ruby
dna.add_child_name_server('example.com', 'ns1.example.com', '1.2.3.4')
```

<details>
<summary>Sample output</summary>

```ruby
{ 'result' => 'OK', 'data' => { 'NameServer' => 'ns1.example.com', 'IPAdresses' => ['1.2.3.4'] } }
```

</details>

#### Delete child nameserver

```ruby
dna.delete_child_name_server('example.com', 'ns1.example.com')
```

<details>
<summary>Sample output</summary>

```ruby
{ 'result' => 'OK', 'data' => { 'NameServer' => 'ns1.example.com' } }
```

</details>

#### Update child nameserver

```ruby
dna.modify_child_name_server('example.com', 'ns1.example.com', '1.2.3.5')
```

<details>
<summary>Sample output</summary>

```ruby
{ 'result' => 'OK', 'data' => { 'NameServer' => 'ns1.example.com', 'IPAdresses' => ['1.2.3.5'] } }
```

</details>

<hr style="border: 4px solid #000; border-style: dashed;">

### Transfers

#### Domain transfer

`transfer(domain, epp_code, period)` — a transfer never sends contacts: the registrar handles them, so the request always carries an empty contact list and the method takes no contacts argument. Update contacts with `save_contacts` once the transfer has completed.

```ruby
dna.transfer('example.com', 'Xy9#mK2$', 3)
```

<details>
<summary>Sample output</summary>

```ruby
{
  'data' => { 'ID' => 0, 'Status' => 'WaitingForIncomingTransfer', 'DomainName' => 'example.com', ... },
  'result' => 'OK'
}
```

</details>

#### Check transfer

`result` is `'OK'` only when the registry reports the domain as transferable.

```ruby
dna.check_transfer('example.com', 'Xy9#mK2$')
```

<details>
<summary>Sample output</summary>

```ruby
{
  'result' => 'OK',
  'data' => {
    'TransferAvailabilityStatus' => true, 'AuthCodeIsRequired' => true, 'AuthCodeIsValid' => true,
    'UserTransferRequired' => false, 'TransferLock' => false, 'Message' => '', 'MessageKey' => '',
    'Additional' => {}
  }
}
```

</details>

#### Cancel, approve or reject a transfer

`cancel_transfer` cancels a pending incoming transfer; `approve_transfer` and `reject_transfer` answer a pending outgoing one.

```ruby
dna.cancel_transfer('example.com')
dna.approve_transfer('example.com')
dna.reject_transfer('example.com')
```

<details>
<summary>Sample output</summary>

```ruby
{ 'result' => 'OK', 'data' => { 'DomainName' => 'example.com', 'Status' => 'Cancelled' } } # 'Approved' / 'Rejected'
```

</details>

<hr style="border: 4px solid #000; border-style: dashed;">

### DNS zone

Supported record types: `A`, `AAAA`, `ALIAS`, `CAA`, `CNAME`, `DS`, `MX`, `NAPTR`, `PTR`, `SRV`, `TLSA`, `TXT` (other types are rejected before any call). Names are relative (`'www'`); `''` or `'@'` is the zone apex, and a full name such as `'www.example.com'` is reduced to its label. Changes are applied immediately; pass `apply = false` to stage several and call `apply_resource_records` once. TTL is 1–86400 seconds.

If the automatic apply fails, the method returns the apply error (the change stays staged, not live) instead of `OK`. The result reports the upper-cased type and the TTL that were actually sent.

The gateway stores a name + type as one **set**: writing a set replaces all of its values, and deleting one value deletes the whole set. The `*_resource_record_value` methods do the read-merge-write for you.

#### List records

```ruby
dna.get_resource_records('example.com')
```

<details>
<summary>Sample output</summary>

```ruby
{
  'result' => 'OK',
  'data' => {
    'records' => [
      { 'Name' => 'example.com.', 'Type' => 'MX', 'TTL' => 3600, 'Content' => '10 mail.example.com.', 'Disabled' => false },
      { 'Name' => 'www.example.com.', 'Type' => 'A', 'TTL' => 3600, 'Content' => '192.0.2.10', 'Disabled' => false }
    ]
  }
}
```

</details>

#### Replace a record set

`set_resource_record_set(domain, name, type, contents, ttl = 3600, apply = true)` — an empty list removes the set.

```ruby
dna.set_resource_record_set('example.com', 'www', 'A', ['192.0.2.10', '192.0.2.11'], 3600)
```

<details>
<summary>Sample output</summary>

```ruby
{ 'result' => 'OK', 'data' => { 'Name' => 'www', 'Type' => 'A', 'TTL' => 3600, 'Contents' => ['192.0.2.10', '192.0.2.11'] } }
```

</details>

#### Add, replace or remove one value

`add_resource_record_value(domain, name, type, value, ttl = nil, apply = true)`, `replace_resource_record_value(domain, name, type, old_value, new_value, ttl = nil, apply = true)`, `remove_resource_record_value(domain, name, type, value, apply = true)`. A `nil` TTL keeps the set's current TTL; adding a value that exists or removing one that does not is a no-op (`'Changed' => false`).

```ruby
dna.add_resource_record_value('example.com', '', 'MX', '10 mail.example.com.')
dna.replace_resource_record_value('example.com', '', 'MX', '10 mail.example.com.', '20 mail.example.com.')
dna.remove_resource_record_value('example.com', '', 'MX', '20 mail.example.com.')
```

<details>
<summary>Sample output</summary>

```ruby
{ 'result' => 'OK', 'data' => { 'Name' => '', 'Type' => 'MX', 'TTL' => 3600, 'Contents' => ['10 mail.example.com.'] } }
# value already present:
{ 'result' => 'OK', 'data' => { 'Name' => '', 'Type' => 'MX', 'Contents' => ['10 mail.example.com.'], 'Changed' => false } }
```

</details>

#### Delete a record set

`delete_resource_record_set(domain, name, type, apply = true, known_value = '')` — removes every value of the set; nothing to remove is a success with `'Removed' => false`.

```ruby
dna.delete_resource_record_set('example.com', 'www', 'A')
```

<details>
<summary>Sample output</summary>

```ruby
{ 'result' => 'OK', 'data' => { 'Name' => 'www.example.com.', 'Type' => 'A', 'Content' => '192.0.2.10' } }
```

</details>

#### Low-level record calls

```ruby
dna.add_resource_record('example.com', 'www', 'A', '192.0.2.10', 3600, true)
dna.edit_resource_record('example.com', 'www', 'www', 'A', '192.0.2.20', 3600, true)
dna.delete_resource_record('example.com', 'www.example.com.', '192.0.2.20', 'A', true)
dna.apply_resource_records('example.com')
```

<details>
<summary>Sample output</summary>

```ruby
{ 'result' => 'OK', 'data' => { 'Name' => 'www', 'Type' => 'A', 'TTL' => 3600, 'Content' => '192.0.2.10' } }   # add / edit
{ 'result' => 'OK', 'data' => { 'Name' => 'www.example.com.', 'Type' => 'A', 'Content' => '192.0.2.20' } }    # delete
{ 'result' => 'OK', 'data' => { 'DomainName' => 'example.com' } }                                              # apply
```

</details>

<hr style="border: 4px solid #000; border-style: dashed;">

### URL forwarding

Forward types: `'Standard'` (plain redirect) and `'Frame'` (masked). The gateway answers `Redirect information not found` when nothing is configured: `get_forwarding` then reports `'Enabled' => false` and `delete_forwarding` succeeds with `'Removed' => false`. Any other error, such as an unknown domain, is returned as an error.

```ruby
dna.set_forwarding('example.com', 'https://www.example.org', 'Standard')
dna.get_forwarding('example.com')
dna.delete_forwarding('example.com')
```

<details>
<summary>Sample output</summary>

```ruby
# set_forwarding
{ 'result' => 'OK', 'data' => { 'RedirectAddress' => 'https://www.example.org', 'ForwardType' => 'Standard' } }
# get_forwarding (nothing configured gives Enabled => false, not an error)
{ 'result' => 'OK', 'data' => { 'Enabled' => true, 'RedirectAddress' => 'https://www.example.org', 'ForwardType' => 'Standard' } }
# delete_forwarding (Removed => false when nothing was configured)
{ 'result' => 'OK', 'data' => { 'DomainName' => 'example.com', 'Removed' => true } }
```

</details>

<hr style="border: 4px solid #000; border-style: dashed;">

### Utilities (no network)

#### Is it a .tr domain?

```ruby
dna.is_tr_tld('example.com.tr') # => true
dna.is_tr_tld('example.com')    # => false
```

#### Validate a contact

Completes and normalizes a contact the way registration does: digits and punctuation are removed from names, a missing state becomes the city, country names become ISO codes and phone numbers are split into number and country code. A number written with its own `+` or `00` calling code keeps that code even when another `PhoneCountryCode` was given (`'+1 202 555 0100'` → `'2025550100'` / `'1'`).

```ruby
dna.validate_contact('FirstName' => 'J0hn', 'Phone' => '+90 532 374 33 88', 'Country' => 'Turkey')
```

<details>
<summary>Sample output</summary>

```ruby
{
  'FirstName' => 'Jhn', 'Phone' => '5323743388', 'Country' => 'TR', 'LastName' => 'Isimyok',
  'AddressLine1' => 'Addres yok', 'City' => 'ISTANBUL', 'State' => 'ISTANBUL', 'ZipCode' => '34000',
  'PhoneCountryCode' => '90', 'Fax' => '', 'FaxCountryCode' => ''
}
```

</details>

<hr style="border: 4px solid #000; border-style: dashed;">

### Settings

| Method | Effect |
|---|---|
| `set_error_reporting_enabled(false)` | Turn telemetry off |
| `set_telemetry_minimal(true)` | Send the minimal telemetry payload |
| `set_ssl_verification(false)` | Skip TLS certificate verification (not recommended) |
| `set_service_url(url)` | Use another gateway URL |
| `set_transport(callable)` | Replace the HTTP transport (see below) |

The HTTP transport is any object that responds to `call(request)`, where `request` is a Hash with `:method`, `:url`, `:headers`, `:body`, `:timeout`, `:connect_timeout` and `:verify_ssl`, and returns a `DomainNameApi::Response` (or a Hash with `:status`, `:body`, `:headers`). The default is `DomainNameApi::NetHttpTransport` (Net::HTTP). This is how the tests run without a network:

```ruby
fake = ->(request) { DomainNameApi::Response.new(status: 200, body: '{"resellerId":"abc"}', headers: {}) }
dna = DomainNameApi::Client.new(reseller_id, api_key, false, transport: fake)
```

<hr style="border: 4px solid #000; border-style: dashed;">

## Testing

The test suite uses only Minitest and never touches the network:

```bash
bundle install
bundle exec rake test
```

`test/conformance_test.rb` runs php-dna's 126 conformance fixtures (`test/fixtures/conformance/`): for each scenario it checks the requests sent (method, path, query, JSON body, auth headers) and the returned value against what php-dna produced. The other tests cover the HTTP layer, error mapping, telemetry masking, the Net::HTTP transport and the utilities.

<hr style="border: 4px solid #000; border-style: dashed;">

## Return and Error Codes with Descriptions

| Code | Description                                    | Detail                                                                                                                                                         |
|------|------------------------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------|
| 1000 | Command completed successfully                 | Operation successful.                                                                                                                                          |
| 1001 | Command completed successfully; action pending | Operation successful. However, the operation is currently queued for completion.                                                                               |
| 2003 | Required parameter missing                     | Parameter missing error. For example, no phone entry in contact information.                                                                                   |
| 2105 | Object is not eligible for renewal             | Domain status is not suitable for renewal, locked for update operations. Status should not be "clientupdateprohibited". May be due to other status conditions. |
| 2200 | Authentication error                           | Authorization error, security code is incorrect or domain is registered with another registrar.                                                                |
| 2302 | Object exists                                  | Domain name or nameserver information already exists in database. Cannot be registered.                                                                        |
| 2303 | Object does not exist                          | Domain name or nameserver information does not exist in database. New registration required.                                                                   |
| 2304 | Object status prohibits operation              | Domain status is not suitable for updates, locked for update operations. Status should not be "clientupdateprohibited". May be due to other status conditions. |

| CODE | DETAIL                                                                                                                               |
|------|--------------------------------------------------------------------------------------------------------------------------------------|
| 101  | System Error Detailed For ({0})!                                                                                                     |
| 102  | Multiple Errors Detailed For ({0})!                                                                                                  |
| 103  | Unknown Errors Detailed For ({0})!                                                                                                   |
| 200  | API command not found ({0})!                                                                                                         |
| 210  | API service not found ({0})!                                                                                                         |
| 211  | API service provider not set!                                                                                                        |
| 300  | Reseller not found!                                                                                                                  |
| 301  | Your current IP address is not authorized to access. Please make sure you are connecting from an authorized IP address and try again |
| 310  | TLD is not supported!                                                                                                                |
| 320  | API not found!                                                                                                                       |
| 321  | Currency is not supported!                                                                                                           |
| 330  | Required parameter(s) not set ({0}).                                                                                                 |
| –    | Make sure you send all contact objects full                                                                                          |
| 340  | Price definition not found ({0}[{1}]-{2}{3}).                                                                                        |
| 350  | Insufficient reseller balance. (Reseller Id : {0} - Current Balance : {1} {2}).                                                      |
| 350  | Accounting currency does not match or the balance is not sufficient.                                                                 |
| 360  | Invalid API request for field ({0}).                                                                                                 |
| 360  | API quota exceeded!                                                                                                                  |
| 361  | Throttled error!                                                                                                                     |
| 362  | Premium domain is not available to register right now.                                                                               |
| 363  | Operation cancelled because domain in auto-renewal period                                                                            |
| 364  | This domain is currently unavailable for transaction due to a problem with the registry                                              |

| CODE | DETAIL                                                                                      |
|------|---------------------------------------------------------------------------------------------|
| 400  | Invalid contact ({0}).                                                                      |
| 401  | Contact info can not sync.                                                                  |
| 402  | No access to contact information from registry.                                             |
| 403  | THE SYSTEM HAS MISSING INFORMATION. ENTER YOUR DEFAULT INFORMATION OR CONTACT SUPPORT TEAM. |
| 404  | DOMAIN CONTACT CANNOT UPDATE. PERMISSION FROM THE REGISTRY.                                 |
| 410  | Contact not found.                                                                          |
| 410  | Contact not found ({0}).                                                                    |
| 420  | Invalid Api command for contact {0}.                                                        |
| 430  | Contact api not found.                                                                      |
| 440  | Contact is not synced.                                                                      |
| 450  | Too many domain contacts!                                                                   |
| 451  | Failed to proceed with contact update.                                                      |

| CODE | DETAIL                                                                                                                               |
|------|--------------------------------------------------------------------------------------------------------------------------------------|
| 500  | Invalid domain id.                                                                                                                   |
| 500  | Invalid domain id ({0}).                                                                                                             |
| 501  | Domain could not synchronized({0})                                                                                                   |
| 502  | Internal transfer failed                                                                                                             |
| 503  | Domain registration is not available.                                                                                                |
| 504  | Domain information does not match. Before :{0}                                                                                       |
| 505  | Enter the Ip Address.                                                                                                                |
| 506  | Domain Transfer Has Been Started But Contact Info Not Read.                                                                          |
| 507  | Authorization error.                                                                                                                 |
| 510  | Domain not found.                                                                                                                    |
| 511  | Expired domains cannot be found.                                                                                                     |
| 512  | Domain is not renewable.                                                                                                             |
| 513  | Domain is not in updateable status. It must be active for to be updated                                                              |
| 514  | Redemption Period Expected.                                                                                                          |
| 520  | Invalid Api command for domain "{0}".                                                                                                |
| 530  | Invalid domain period. Period must be {0} to {1} years. Requested period is {2} years.                                               |
| 540  | Domain cannot be extended beyond {0} years from current date.                                                                        |
| 550  | Invalid domain name. Domain must be {0} to {1} characters length. Requested domain name is {2} characters.                           |
| 560  | Invalid name server count. Domain must have {0} to {1} name servers. Requested name server count is {2}.                             |
| 561  | No name server information found in the incoming request                                                                             |
| 570  | Idn not supported for tld "{0}".                                                                                                     |
| 571  | Period invalid.                                                                                                                      |
| 572  | Command invalid.                                                                                                                     |
| 573  | Domain names not found.                                                                                                              |
| 574  | TLD names not found.                                                                                                                 |
| 575  | Domain is not in updateable status. It must be active for name servers to be updated                                                 |
| 576  | Domain can be renewed in the last 1 month before the expire date                                                                     |
| 580  | Transfer not supported for tld "{0}".                                                                                                |
| 581  | Child name server not found                                                                                                          |
| 582  | Transfer started by other reseller.                                                                                                  |
| 583  | Transfer not initialized. Please contact the support team.                                                                           |
| 584  | Object status prohibits operation                                                                                                    |
| 590  | Auth code is required for this transfer.                                                                                             |
| 591  | Auth code is not valid.                                                                                                              |
| 592  | Transfer lock exists on domain.                                                                                                      |
| 593  | Domain cannot be transferred, Status Information and Transfer Lock must comply with the required criteria. (Status Information: #ok) |
| 594  | Domain name server address could not resolved ({0})                                                                                  |
| 595  | Contact information can not be read (whois.registrar.tld) Please make sure that privacy protection status open                       |
| 596  | Contact information could not verified                                                                                               |
| 597  | Tld Not Found                                                                                                                        |
| 598  | Unknown error occurred                                                                                                               |
| 599  | Domain Forward Not Found                                                                                                             |

## License

Apache License 2.0 — see [LICENSE](LICENSE).
