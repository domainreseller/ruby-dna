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

# ruby-dna: de Ruby SDK voor de Domain Name API

[![CI](https://github.com/domainreseller/ruby-dna/actions/workflows/ci.yml/badge.svg)](https://github.com/domainreseller/ruby-dna/actions/workflows/ci.yml)
[![License](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](LICENSE)

Ruby-client voor de reseller-REST-API van de [Domain Name API](https://www.domainnameapi.com): domeinen
zoeken, registreren, verlengen en verhuizen, DNS, DNSSEC, contacten, SSL-certificaten, hosting, bestellingen, de
productcatalogus en je saldo.

- **Alle 67 API-operaties**, op dezelfde manier gegroepeerd als in de [`dna` CLI](https://github.com/domainreseller/cli):
  `dna domain info` is `client.domains.info`, `dna dns add` is `client.dns.add`.
- **Echte objecten, geen hashes**: `domain.status.pending_delete?`, `domain.expiration_date` is een `Time`,
  `availability.available?`, `tld.register_price(1)`.
- **Elke operatie is een request-klasse** die erft van `DomainNameApi::BaseRequest` en zichzelf valideert voordat er
  iets wordt verstuurd. Eigen requests schrijf je op dezelfde manier.
- **Standaard veilig**: kostenplichtige requests worden nooit blind herhaald, `read_only: true` blokkeert
  wijzigingen, de client remt zichzelf af onder de rate limits en kan veilig tussen threads worden gedeeld.
- **Geen afhankelijkheden.** Ruby 3.1 of nieuwer, alleen de standaardbibliotheek.

```ruby
client = DomainNameApi::Client.new(reseller_id: reseller_id, api_key: api_key, environment: :ote)

a = client.domains.search('example.com')
puts "#{a.domain_name} is available for #{a.price} #{a.currency}" if a.available?
```

## Inhoud

- [Installatie](#installatie)
- [Inloggegevens en omgevingen](#inloggegevens-en-omgevingen)
- [Services](#services)
- [Gebruik](#gebruik)
- [Resultaten, modellen en enums](#resultaten-modellen-en-enums)
- [Requests en BaseRequest](#requests-en-baserequest)
- [Fouten](#fouten)
- [Veiligheid en betrouwbaarheid](#veiligheid-en-betrouwbaarheid)
- [Client-opties](#client-opties)
- [Je code testen](#je-code-testen)
- [Migreren van v1](#migreren-van-v1)
- [Ontwikkeling](#ontwikkeling)

## Installatie

> ⬇️ Gebruik een getagde versie uit [Releases](https://github.com/domainreseller/ruby-dna/releases/latest). De
> groene knop **Code → Download ZIP** geeft je de ontwikkelbranch.

Met Bundler:

```ruby
# Gemfile
gem 'domainnameapi', git: 'https://github.com/domainreseller/ruby-dna.git', tag: 'v2.0.0'
```

Of installeer het `.gem`-bestand dat bij de release is gevoegd:

```bash
gem install ./domainnameapi-2.0.0.gem
```

```ruby
require 'domainnameapi'
```

Uitvoerbare programma's staan in [examples](examples): `quickstart`, `register`, `expiring`, `dns`, `ssl` en
`custom_request`.

```bash
DNA_RESELLER_ID=... DNA_API_KEY=... DNA_ENV=ote ruby examples/quickstart.rb example.com
```

## Inloggegevens en omgevingen

Je hebt twee API-inloggegevens nodig uit het resellerpaneel (**API settings**). De inloggegevens van het paneel werken niet.

| Inloggegevens | Ziet eruit als                         |
|---------------|----------------------------------------|
| Reseller ID   | `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx` |
| API key       | een lange geheime tekenreeks           |

Er zijn twee omgevingen. **Begin met OTE**, de testomgeving: die heeft eigen gegevens en een eigen API-sleutel,
en niets wat je daar doet kost geld of raakt live domeinen.

```ruby
# Testomgeving (OTE)
client = DomainNameApi::Client.new(reseller_id: reseller_id, api_key: ote_api_key, environment: :ote)

# Productie (de standaard): echte registraties, echte afschrijvingen
client = DomainNameApi::Client.new(reseller_id: reseller_id, api_key: api_key)
```

`environment:` accepteert ook de strings die panelen opslaan: `'production'`, `'ote'`, `'test'`, en testmodus-vlaggen
(`'true'`, `'1'`, `true`). `Client.from_env` leest dezelfde variabelen als de `dna` CLI:

| Variabele         | Betekenis                                                     |
|-------------------|---------------------------------------------------------------|
| `DNA_RESELLER_ID` | reseller ID                                                   |
| `DNA_API_KEY`     | API-sleutel van de gekozen omgeving                           |
| `DNA_ENV`         | `production` (standaard) of `ote`                             |
| `DNA_TEST_MODE`   | `true` kiest OTE (zoals in de andere DomainNameAPI-SDK's)     |
| `DNA_BASE_URL`    | een eigen basis-URL, bijv. een proxy                          |

```ruby
client = DomainNameApi::Client.from_env(user_agent: 'my-panel/1.4')
```

Een verkeerde sleutel of omgeving mislukt bij de eerste request met een `APIError` waarvan `auth?` true is en waarvan
`hint` zegt waar je op moet letten; `client.account.get` is de goedkoopste manier om dit te controleren.

## Services

| Service            | CLI-groep     | Methoden                                                                                                                                                          |
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

Vereiste invoer is positioneel (`info('example.com')`), al het andere is een keyword-argument
(`renew('example.com', years: 1)`). Operaties met veel optionele invoer nemen keywords of een request-object:
`register(domain_name: ..., years: 1, ...)` en `register(DomainNameApi::DomainRegisterRequest.new(...))` zijn
gelijkwaardig. `ssl.purchase` is `dna ssl initialize` van de CLI (`initialize` is gereserveerd in Ruby).

## Gebruik

Alle snippets gaan uit van een `client`.

### Zoeken

```ruby
a = client.domains.search('example.com')
a.available?            # a.price, a.currency, a.premium?, a.document_required?, a.reason

client.domains.bulk_search('example.com', 'example.net', 'example.org').each do |r|
  puts "#{r.domain_name} #{r.status} #{r.price}"
end
```

`bulk_search` splitst lijsten met meer dan 30 domeinen op in meerdere requests. Prijzen gebruiken de valuta van het
account, de client-optie `currency: 'TRY'` of `search('example.com', currency: 'USD')`.

### Registreren

Met contact-handles (maak er een aan met `contacts.create`):

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
  handles: handle # één handle voor alle vier de rollen, of { registrant: 'DNA-1', admin: 'DNA-2', tech: ..., billing: ... }
)
result.status           # result.domain_id, result.expiration_date
```

Met inline contacten:

```ruby
client.domains.register_with_contacts(
  domain_name: 'example.com',
  name_servers: %w[ns1.example.net ns2.example.net],
  contacts: owner # één Contact voor alle vier de rollen, of { registrant: owner, admin: admin, tech: admin, billing: admin }
)
```

Contacten kunnen `DomainNameApi::Contact`-objecten zijn of Hashes met dezelfde velden. Ze worden vóór het versturen
opgeschoond: velden worden getrimd, het land wordt omgezet naar hoofdletters en telefoonvelden behouden alleen hun cijfers
(`'+90 (555) 123-45-67'` werkt). Sommige TLD's vereisen registry-attributen: je vindt ze met
`client.products.tld('com.tr').required_attributes` en geeft ze mee als `tld_attributes:`.

Als de API antwoordt maar weigert (`"success": false`), gooit de methode een `DomainNameApi::OperationError` met de
melding van de API.

### Verlengen, verhuizen, herstellen

```ruby
check = client.domains.renew_check('example.com', years: 1)   # check.renewable?, check.premium_price
client.domains.renew('example.com', years: 1)

tc = client.domains.transfer_check('example.com', 'auth-code') # tc.transferable?, tc.auth_code_valid?
client.domains.transfer('example.com', auth_code: 'auth-code')
client.domains.transfer_status('example.com').status

client.domains.restore('example.com') # tijdens de redemption-periode
```

### Domeindetails en de domeinlijst

```ruby
d = client.domains.info('example.com')
d.status                # => #<DomainNameApi::DomainStatus Active (0)>
d.expiration_date       # => 2027-03-15 10:20:30 UTC
d.remaining_days, d.locked?, d.privacy_protection?, d.name_servers, d.auth_code, d.hosts
d.contact(:registrant)&.email

# Eén pagina
page = client.domains.list(limit: 50, sort: 'expirationDate')
page.total_count
page.each { |domain| puts domain.domain_name }

# Elk domein; de pagina's worden gaandeweg opgehaald
client.domains.all(statuses: [:active]) do |domain|
  puts "#{domain.domain_name} #{domain.expiration_date}"
end
client.domains.all.first(10) # zonder blok een Enumerator: haalt één pagina op
```

### Vergrendeling, privacy, nameservers, child-nameservers

```ruby
client.domains.lock('example.com')
client.domains.unlock('example.com')
client.domains.set_privacy('example.com', true)
code = client.domains.update_auth_code('example.com')

client.domains.set_name_servers('example.com', %w[ns1.example.net ns2.example.net])
client.domains.set_name_servers('example.com', %w[ns1.other.net ns2.other.net], dnssec_mode: :disable) # voor getekende domeinen

client.domains.add_host('example.com', 'ns1.example.com', '192.0.2.10', '2001:db8::10') # IP-versie wordt herkend
client.domains.update_host('example.com', 'ns1.example.com', ip_addresses: ['192.0.2.20'])
client.domains.delete_host('example.com', 'ns1.example.com')
```

### Contacten van een domein

```ruby
client.domains.set_contact_handles('example.com', admin: 'DNA-2', tech: 'DNA-2') # andere rollen blijven ongewijzigd
client.domains.update_contacts('example.com', billing: billing_contact)

details = client.contacts.get('DNA-1')               # het contact en de verificatiestatus ervan
result = client.contacts.update('DNA-1', contact)    # werkt elk domein bij dat de handle gebruikt
result.affected_domains.each { |a| puts "#{a.domain_name} #{a.new_handle}" }
client.contacts.resend_verification('DNA-1')          # false als er niets te verifiëren is
```

### DNS-zone

```ruby
client.dns.add('example.com', name: 'www', type: :a, values: '192.0.2.10', ttl: 600)
client.dns.update('example.com', record_name: 'www', type: :a, values: %w[192.0.2.20 192.0.2.21]) # vervangt de set
client.dns.delete('example.com', name: 'www', type: :a, value: '192.0.2.20')

client.dns.list('example.com').each do |set|
  puts "#{set.name} #{set.type} #{set.ttl} #{set.values.join(', ')}"
end

client.dns.apply('example.com') # zet het domein om naar de nameservers van het platform
```

Namen kunnen relatief (`'www'`), de apex (`''` of `'@'`) of volledig gekwalificeerd zijn. Recordtypen zijn symbolen of
strings in elke schrijfwijze (`:txt` en `'txt'` worden verstuurd als `TXT`). De validatie vangt af wat de API zou
weigeren: een CNAME op de apex, een CAA-waarde zonder drie delen, een MX-waarde zonder prioriteit, een A-record met een
IPv6-adres. De testomgeving beantwoordt elke zone-aanroep met HTTP 500, dus zonecode kan alleen in productie worden uitgeprobeerd.

### DNSSEC

```ruby
results = client.dnssec.add('example.com', '2371 13 2 1F987CC6583E92DF0890718C42...') # zoals je DNS-provider het toont
info = client.dnssec.get('example.com') # info.status.signed?, info.ds_records
client.dnssec.disable('example.com')
```

`DomainNameApi::DS.parse` leest het presentatieformaat en volledige regels uit zonebestanden; `DS.new(key_tag: ...,
algorithm: :ecdsa_p256_sha256, digest_type: :sha256, digest: '...')` werkt ook.

### URL-doorstuurfunctie

```ruby
client.domains.set_forwarding('example.com', 'https://www.example.org')              # 301-omleiding
client.domains.set_forwarding('example.com', 'https://www.example.org', type: :frame) # gemaskeerd
f = client.domains.forwarding('example.com') # nil als het domein er geen heeft
client.domains.delete_forwarding('example.com')
```

### Registrydocumenten (.tr)

```ruby
doc = DomainNameApi::DocumentUpload.from_file(:identity_card, 'id.pdf')
client.domains.upload_documents('example.com.tr', doc)
client.domains.documents('example.com.tr').each { |d| puts "#{d.name} #{d.status}" }
```

Bestanden worden voor je base64-gecodeerd; formaat (PDF, JPG, PNG, DOC, DOCX, ODT) en grootte (10 MB per bestand, 50 MB per
request) worden vóór het uploaden gecontroleerd.

### SSL-certificaten

```ruby
csr = client.ssl.generate_csr(domain_name: 'example.com', country: 'TR', state: 'Istanbul', locality: 'Istanbul',
                              organization: 'Example Ltd', organization_unit: 'IT')
# schrijft af van het saldo (CLI: dna ssl initialize)
order = client.ssl.purchase('example.com', package_code: 'PositiveSSL')
id = order.certificate_id # bewaar het: elke latere aanroep heeft het nodig
client.ssl.configure(certificate_id: id, csr: csr.csr, approver_mail: 'admin@example.com',
                     authentication_type: :email, web_server_type: :apache, contact: ssl_contact)
client.ssl.status(id).issued? # blijf pollen tot true
File.write('example.com.crt', client.ssl.content(id).chain)
```

Een domein kan meerdere certificaten hebben. Een bestaand certificaat wordt daarom aangeduid met zijn
`certificate_id` (een GUID), nooit met de domeinnaam: `purchase` en `renew` geven het terug en `list` vindt het.
Een domeinnaam op de plek van een id gooit een `InputError` voordat er iets wordt verstuurd. Configureer een
certificaat binnen 15 dagen na aankoop of verlenging.

```ruby
client.ssl.list(domain_name: 'example.com').each { |c| puts "#{c.certificate_id} #{c.status}" } # nieuwste eerst
client.ssl.all { |c| puts "#{c.domain_name} #{c.subscription_expires_at}" } # elk certificaat, pagina voor pagina

client.ssl.approvers(certificate_id: id)                                      # voor een bestaand certificaat
client.ssl.approvers(domain_name: 'example.com', package_code: 'PositiveSSL') # vóór een aankoop

renewal = client.ssl.renew(id) # schrijft af van het saldo; mogelijk vanaf 30 dagen voor het einde van het abonnement
client.ssl.configure(certificate_id: renewal.certificate_id, csr: new_csr.csr, approver_mail: 'admin@example.com',
                     authentication_type: :email, web_server_type: :apache, contact: ssl_contact)
```

Om te verlengen roep je `renew` aan en daarna `configure` voor het nieuwe certificaat dat wordt teruggegeven.
Roep niet opnieuw `purchase` aan: dat is een losstaande nieuwe bestelling tegen de aankoopprijs, en het oude
certificaat krijgt nooit de status `Renewed`.

### Hosting

```ruby
client.hosting.packages.each { |p| puts p.service_plans.map(&:service_plan) }
created = client.hosting.create('example.com', service_plan: 'Linux-Starter') # schrijft af van het saldo

st = client.hosting.wait(created.service_id, timeout: 30 * 60) # pollt tot de hosting actief is
puts st.panel_address, st.username, st.password
```

Roep `create` nooit opnieuw aan voor een hosting die nog wordt ingericht: dat schrijft twee keer af.

### Saldo, prijzen en bestellingen

```ruby
account = client.account.get
account.balance('USD')
profile = client.account.profile # profile.company_name, profile.account_currency, profile.status.active?

client.account.all_transactions(from: Date.new(2026, 11, 1)) do |tx|
  puts "#{tx.creation_time} #{tx.type} #{tx.change}"
end

tld = client.products.tld('com.tr')
tld&.register_price(1)&.to_s   # => "12.50 USD"

client.products.info('com', order_type: :renew, years: 2) # prijs van een .com-verlenging van 2 jaar
client.orders.get('ORDER-CODE')
```

## Resultaten, modellen en enums

Elk resultaat is een `DomainNameApi::Model`: snake_case-readers, `?`-predicaten voor vlaggen, `Time`-objecten voor
datums, geneste modellen en lijsten.

```ruby
d = client.domains.info('example.com')
d.locked?                 # ook d.locked
d.hosts.first.ip_addresses.first.address
d.to_h                    # een gewone Hash met snake_case-sleutels
d.raw                     # het JSON-object zoals de API het stuurde, voor velden die deze gem niet modelleert
```

Numerieke waarden en vaste stringwaarden zijn enums (`DomainStatus`, `RecordType`, `ContactType`, `DocumentType`, ...):

```ruby
d.status.pending_delete?                       # een predicaat per enumwaarde
d.status == DomainNameApi::DomainStatus::ACTIVE
d.status == :active                            # symbolen, namen en getallen kunnen ook worden vergeleken
d.status.to_s                                  # => "Active"
d.status.to_i                                  # => 0
DomainNameApi::DomainStatus.members            # alle waarden
```

Requests accepteren enums, symbolen, namen in elke schrijfwijze of getallen: `statuses: [:active, 'PendingDelete', 7]`.

Het decoderen is tolerant: datums zonder tijdzone, `null`, `[]` in plaats van `{}`, getallen die als strings worden
verstuurd, rollen in elke schrijfwijze (`"registrant"`, `"ADMINISTRATIVE"`) en waarden die deze gem nog niet kent, worden
allemaal gedecodeerd in plaats van de aanroep te laten mislukken (`status.known?` is false voor die laatste).

## Requests en BaseRequest

Elke API-operatie is een request-klasse: `DomainInfoRequest`, `DNSAddRequest`, `SSLConfigureRequest`, ..., vernoemd
naar het CLI-commando (`dna domain renew` is `DomainRenewRequest`). Ze erven allemaal van
`DomainNameApi::BaseRequest`, dat de basis levert: een `endpoint`- en `attribute`-DSL op klasseniveau, initialisatie
met keywords, validatiehulpen, padsjablonen en query- en body-builders. Lijst-requests erven van
`PagedRequest`, dat `skip`, `limit` en `sort` toevoegt. Een request uit deze gem ziet er zo uit:

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

De servicemethoden bouwen deze requests voor je. `client.call` verstuurt elke request, ook eigen klassen, bijvoorbeeld
om alleen de velden te lezen die je nodig hebt of om een endpoint aan te roepen dat deze gem nog niet omvat:

```ruby
class Expiry < DomainNameApi::Model
  field :expiration_date, :time
  field :remaining_days, :integer, from: 'remainingDay'
end

class ExpiryRequest < DomainNameApi::BaseRequest
  endpoint :get, '/api/v1/domains/info', safety: :read
  returns Expiry            # laat weg om de geparste JSON te krijgen
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

| Te overschrijven methode | Standaard          | Doel                                                                        |
|--------------------------|--------------------|-----------------------------------------------------------------------------|
| `query`                  | `nil`              | een `Query` (`params.string(...)`), een Hash of een Array van paren         |
| `body`                   | `nil`              | een Hash of Array met de namen van de API; enums, modellen en tijden worden omgezet |
| `validate`               | niets te controleren | meld problemen met `required`, `check`, `between`, `max_length`, `enum`   |
| `decode(data)`           | gebruikt `returns` | zet de geparste JSON om in je resultaat                                     |

Placeholders in het pad worden gevuld vanuit de attributen en geëscaped: `endpoint :get, '/api/v1/contacts/{handle}'`.

Je request krijgt alles wat de ingebouwde requests krijgen: inloggegevens, retries, pacing, foutnormalisatie,
correlation-ID's, tracing en read-only-afdwinging. `client.execute(request)` geeft de volledige `Response` terug
(status, headers, ruwe body, correlation-ID, quota, pogingen) met het gedecodeerde resultaat in `value`.
`client.prepare(request)` valideert en bouwt de exacte HTTP-request zonder die te versturen, om een kostenplichtige
request te loggen of te controleren voordat hij de deur uit gaat (de API-sleutel wordt gemaskeerd in `inspect`).

## Fouten

| Fout                             | Wanneer                                                    | Nuttige methoden                                                               |
|----------------------------------|------------------------------------------------------------|--------------------------------------------------------------------------------|
| `DomainNameApi::InputError`      | de validatie heeft de request afgewezen; **er is niets verstuurd** | `request`, `fields`                                                    |
| `DomainNameApi::APIError`        | de API antwoordde met een niet-2xx-status                  | `status`, `code`, `api_message`, `details`, `fields`, `data`, `correlation_id`, `hint` |
| `DomainNameApi::OperationError`  | de API antwoordde 2xx met `"success": false`               | `code`, `api_message`, `correlation_id`                                        |
| `DomainNameApi::NetworkError`    | de request is niet voltooid (DNS, TLS, timeout, reset)     | `original`, `timeout?`                                                         |
| `DomainNameApi::ReadOnlyError`   | een read-only-client blokkeerde een wijziging; er is niets verstuurd | `safety`                                                             |

Ze erven allemaal van `DomainNameApi::Error`, dat de gebruikelijke vragen beantwoordt: `kind` (`:auth`,
`:not_found`, `:validation`, `:rejected`, `:conflict`, `:rate_limited`, `:server`, `:network`, `:invalid_input`,
`:read_only`), `not_found?`, `auth?`, `rate_limited?`, `insufficient_balance?`, `outcome_unknown?`,
`retryable?` en `code?(code)`.

```ruby
begin
  client.domains.renew('example.com', years: 1)
rescue DomainNameApi::Error => e
  if e.outcome_unknown?
    # De verlenging is mogelijk doorgegaan. Controleer het domein voordat je het opnieuw probeert.
  elsif e.insufficient_balance?
  elsif e.not_found?
  elsif e.code?(DomainNameApi::ErrorCode::PRIVACY_NOT_SUPPORTED)
  elsif e.is_a?(DomainNameApi::APIError)
    logger.error("#{e.code} #{e.api_message} #{e.hint} #{e.correlation_id}")
  end
end
```

Vertak op `code`, niet op de melding: meldingen zijn gelokaliseerd. API-codes zien eruit als
`Dna.DomainService:Domain:10007`; de gebruikelijke zijn constanten in `DomainNameApi::ErrorCode`, de rest staat in de
[foutenreferentie](https://www.domainnameapi.com/docs/reference/errors.md). Vermeld de `correlation_id` wanneer je
contact opneemt met de support.

## Veiligheid en betrouwbaarheid

- **Veiligheidsklassen.** Elke request is `:read`, `:write`, `:destructive` of `:billable` (`request.safety`,
  `request.billable?`). Sommige POST- en PUT-requests zijn leesacties (`DomainSearchRequest`, `SSLStatusRequest`).
- **Read-only-modus.** `read_only: true` blokkeert alles wat geen leesactie is, voor rapportagejobs en om
  productie veilig te verkennen.
- **Retries.** 429-responses worden altijd herhaald, met inachtneming van `Retry-After`: de API weigert ze voordat hij
  iets doet. Netwerkfouten en 502/503/504 worden alleen herhaald voor leesacties en idempotente schrijfacties, zodat een registratie
  of verlenging nooit twee keer wordt verstuurd. Controleer na een mislukte kostenplichtige request `e.outcome_unknown?`.
- **Pacing.** De client spreidt requests om onder de limieten per sleutel te blijven (5 requests/seconde, 2 zoekopdrachten/seconde,
  één zone-aanroep per seconde). Zet het uit met `pacing: false` als je zelf afremt.
- **Quota.** `client.execute(request).quota` geeft de soft-quota-headers vrij. Boven de limiet vertraagt de API
  responses (tot 5 s) in plaats van ze te weigeren; de standaard-timeout van 60 s laat daar ruimte voor.
- **Correlation-ID's.** Elke request draagt een `X-Correlation-ID`. Stel er zelf een in om API-aanroepen aan je logs te koppelen:
  `DomainNameApi.with_correlation_id(job.id) { ... }` of `client.call(request, correlation_id: job.id)`.
- **Observability.** `logger: Logger.new($stdout)` logt elke uitwisseling; `on_trace: ->(event) { ... }` geeft je
  elke request, response en retry als een `TraceEvent`, voor metrics of foutrapportage. De API-sleutel zit er nooit
  in; bodies kunnen contactgegevens bevatten, dus maskeer ze voordat je ze opslaat.
- **Threads.** Een client kan veilig tussen threads worden gedeeld. Maak er één aan en hergebruik hem.
- **Verder verlaat niets je proces.** Geen telemetrie, geen diensten van derden.

## Client-opties

| Optie                        | Effect                                                                              |
|------------------------------|-------------------------------------------------------------------------------------|
| `environment: :ote`          | gebruik de testomgeving (standaard `:production`)                                   |
| `base_url: 'https://...'`    | verstuur requests naar een proxy of een testserver                                  |
| `timeout: 60`                | seconden per HTTP-poging                                                            |
| `open_timeout: 10`           | seconden voor het opzetten van de verbinding                                        |
| `user_agent: 'app/1.0'`      | zet je product vóór de User-Agent                                                   |
| `currency: 'TRY'`            | valuta van zoek- en catalogusprijzen                                                |
| `retries: 2`                 | aantal retries                                                                      |
| `max_retry_wait: 30`         | de langste `Retry-After` waarop de client wacht                                     |
| `pacing: false`              | zet pacing aan de clientzijde uit                                                   |
| `read_only: true`            | blokkeer elke request die geen leesactie is                                         |
| `logger: Logger.new($stdout)`| log uitwisselingen: requests op debug-, retries op warn- en fouten op error-niveau  |
| `on_trace: ->(event) {}`     | observeer elke request, response en retry                                           |
| `transport: my_transport`    | je eigen HTTP-laag (proxy, connection pool, ...): elk object met `call(request)`    |

`DomainNameApi::NetHTTPTransport.new(proxy: 'http://proxy:8080', ca_file: 'corp-ca.pem')` is het standaardtransport
met een proxy of je eigen CA-bundle. Redirects worden nooit gevolgd: de API antwoordt 302 bij een onbekende
of opgeschorte reseller ID, wat een authenticatiefout wordt.

## Je code testen

Geef een transport mee dat antwoordt zoals de API; verder hoeft er niets te worden gemockt:

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

`request` is een `DomainNameApi::PreparedRequest` (`http_method`, `url`, `headers`, `body`), dus de fake kan ook
controleren wat er is verstuurd. WebMock en VCR werken ook, omdat het standaardtransport `Net::HTTP` is.

## Migreren van v1

v2 is een nieuw ontwerp: getypeerde resultaten in plaats van Hashes met String-sleutels, exceptions in plaats van
`{'result' => 'ERROR'}`-enveloppen en de volledige API in plaats van de methodenset van php-dna. De gemnaam blijft
`domainnameapi`; pin `tag: 'v1.0.1'` vast om v1 te behouden tot je overstapt.

| v1                                                   | v2                                                                       |
|------------------------------------------------------|--------------------------------------------------------------------------|
| `Client.new(id, key, true)`                          | `Client.new(reseller_id: id, api_key: key, environment: :ote)`           |
| `res['result'] == 'OK'`                              | geen exception                                                           |
| `get_reseller_details`, `get_current_balance`        | `account.get` (+ `account.balance('USD')`)                               |
| `check_availability`                                 | `domains.search`, `domains.bulk_search`                                  |
| `get_list`                                           | `domains.list`, `domains.all`                                            |
| `get_tld_list`                                       | `products.tlds`, `products.all_tlds`, `products.tld`                     |
| `get_details`, `get_contacts`, `sync_from_registry`  | `domains.info`                                                           |
| `register_with_contact_info`                         | `domains.register_with_contacts` (of `contacts.create` + `domains.register`) |
| `renew`, `transfer`, `check_transfer`                | `domains.renew`, `domains.transfer`, `domains.transfer_check`            |
| `modify_name_server`                                 | `domains.set_name_servers`                                               |
| `enable_theft_protection_lock` / `disable_...`       | `domains.lock` / `domains.unlock`                                        |
| `modify_privacy_protection_status`                   | `domains.set_privacy`                                                    |
| `save_contacts`                                      | `domains.update_contacts`, `domains.set_contact_handles`                 |
| `add_child_name_server`, `modify_child_name_server`, `delete_child_name_server` | `domains.add_host`, `domains.update_host`, `domains.delete_host` |
| `get_resource_records`                               | `dns.list`                                                               |
| `add_resource_record`, `add_resource_record_value`   | `dns.add`                                                                |
| `edit_resource_record`, `set_resource_record_set`, `replace_resource_record_value` | `dns.update`                               |
| `delete_resource_record`, `remove_resource_record_value`, `delete_resource_record_set` | `dns.delete` (eenmaal per waarde)      |
| `apply_resource_records`                             | `dns.apply`                                                              |
| `get_forwarding`, `set_forwarding`, `delete_forwarding` | `domains.forwarding`, `domains.set_forwarding`, `domains.delete_forwarding` |
| `cancel_transfer`, `approve_transfer`, `reject_transfer` | niet in de gepubliceerde API; verstuur een [eigen request](#requests-en-baserequest) als je account ze heeft |
| `is_tr_tld`, `validate_contact`                      | `name.end_with?('.tr')`; validatie draait bij elke request               |
| `get_request_data`, `get_response_data`, ...         | `on_trace:`, `logger:`, `client.execute(request)`                        |
| telemetrie (`set_error_reporting_enabled`, Sentry)   | verwijderd: niets verlaat je proces; stuur `on_trace`-events door naar je eigen rapportage |
| `set_ssl_verification(false)`                        | `transport: NetHTTPTransport.new(ca_file: ...)` met je eigen CA-bundle   |

## Ontwikkeling

```bash
bundle install
bundle exec rake test   # unittests; geen enkele raakt het netwerk
```

`test/fixtures/openapi.json` is het OpenAPI-document van de API. De tests controleren elke request-klasse ertegen
(methode, pad, querynamen, body-velden, verplichte velden), de JSON-namen van elk response-model tegen de response-schema's
en elke enum-waarde, en falen als de API een operatie krijgt zonder request-klasse. Zo werk je het bij:

```bash
curl -fsSL -A "ruby-dna-spec-update" -o test/fixtures/openapi.json https://api.domainresellerapi.com/swagger/v1/swagger.json
bundle exec rake test
```

Zie [AGENTS.md](AGENTS.md) voor de conventies van deze repository.

## Support

- API-documentatie: <https://www.domainnameapi.com/docs/>
- CLI en MCP-server: <https://github.com/domainreseller/cli>
- Website: <https://www.domainnameapi.com>

## Licentie

Apache License 2.0. Zie [LICENSE](LICENSE).
