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

# ruby-dna: das Ruby-SDK für die Domain Name API

[![CI](https://github.com/domainreseller/ruby-dna/actions/workflows/ci.yml/badge.svg)](https://github.com/domainreseller/ruby-dna/actions/workflows/ci.yml)
[![License](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](LICENSE)

Ruby-Client für die Reseller-REST-API der [Domain Name API](https://www.domainnameapi.com): Domainsuche,
Registrierung, Verlängerung und Transfer, DNS, DNSSEC, Kontakte, SSL-Zertifikate, Hosting, Bestellungen, der
Produktkatalog und Ihr Guthaben.

- **Alle 67 API-Operationen**, genauso gruppiert wie in der [`dna`-CLI](https://github.com/domainreseller/cli):
  `dna domain info` entspricht `client.domains.info`, `dna dns add` entspricht `client.dns.add`.
- **Echte Objekte statt Hashes**: `domain.status.pending_delete?`, `domain.expiration_date` ist ein `Time`,
  `availability.available?`, `tld.register_price(1)`.
- **Jede Operation ist eine Request-Klasse**, die von `DomainNameApi::BaseRequest` erbt und sich selbst validiert,
  bevor etwas gesendet wird. Eigene Requests schreiben Sie auf dieselbe Weise.
- **Sicher von Haus aus**: kostenpflichtige Requests werden nie blind wiederholt, `read_only: true` blockiert
  Änderungen, der Client drosselt sich selbst unter den Rate Limits und kann sicher zwischen Threads geteilt werden.
- **Keine Abhängigkeiten.** Ruby 3.1 oder neuer, nur die Standardbibliothek.

```ruby
client = DomainNameApi::Client.new(reseller_id: reseller_id, api_key: api_key, environment: :ote)

a = client.domains.search('example.com')
puts "#{a.domain_name} is available for #{a.price} #{a.currency}" if a.available?
```

## Inhalt

- [Installation](#installation)
- [Zugangsdaten und Umgebungen](#zugangsdaten-und-umgebungen)
- [Services](#services)
- [Verwendung](#verwendung)
- [Ergebnisse, Modelle und Enums](#ergebnisse-modelle-und-enums)
- [Requests und BaseRequest](#requests-und-baserequest)
- [Fehler](#fehler)
- [Sicherheit und Zuverlässigkeit](#sicherheit-und-zuverlässigkeit)
- [Client-Optionen](#client-optionen)
- [Den eigenen Code testen](#den-eigenen-code-testen)
- [Migration von v1](#migration-von-v1)
- [Entwicklung](#entwicklung)

## Installation

> ⬇️ Verwenden Sie eine getaggte Version aus den [Releases](https://github.com/domainreseller/ruby-dna/releases/latest).
> Der grüne Button **Code → Download ZIP** liefert Ihnen den Entwicklungszweig.

Mit Bundler:

```ruby
# Gemfile
gem 'domainnameapi', git: 'https://github.com/domainreseller/ruby-dna.git', tag: 'v2.0.0'
```

Oder installieren Sie die dem Release angehängte `.gem`-Datei:

```bash
gem install ./domainnameapi-2.0.0.gem
```

```ruby
require 'domainnameapi'
```

Lauffähige Programme finden Sie in [examples](examples): `quickstart`, `register`, `expiring`, `dns`, `ssl` und
`custom_request`.

```bash
DNA_RESELLER_ID=... DNA_API_KEY=... DNA_ENV=ote ruby examples/quickstart.rb example.com
```

## Zugangsdaten und Umgebungen

Sie benötigen zwei API-Zugangsdaten aus dem Reseller-Panel (**API settings**). Die Anmeldedaten des Panels funktionieren nicht.

| Zugangsdaten | Sieht so aus                           |
|--------------|----------------------------------------|
| Reseller ID  | `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx` |
| API key      | eine lange geheime Zeichenfolge        |

Es gibt zwei Umgebungen. **Beginnen Sie mit OTE**, der Testumgebung: Sie hat eigene Daten und einen eigenen API-Schlüssel,
und nichts, was Sie dort tun, kostet Geld oder berührt Live-Domains.

```ruby
# Testumgebung (OTE)
client = DomainNameApi::Client.new(reseller_id: reseller_id, api_key: ote_api_key, environment: :ote)

# Produktion (Standard): echte Registrierungen, echte Abbuchungen
client = DomainNameApi::Client.new(reseller_id: reseller_id, api_key: api_key)
```

`environment:` akzeptiert auch die Zeichenfolgen, die Panels speichern: `'production'`, `'ote'`, `'test'`, sowie
Testmodus-Flags (`'true'`, `'1'`, `true`). `Client.from_env` liest dieselben Variablen wie die `dna`-CLI:

| Variable          | Bedeutung                                                     |
|-------------------|---------------------------------------------------------------|
| `DNA_RESELLER_ID` | Reseller ID                                                   |
| `DNA_API_KEY`     | API-Schlüssel der gewählten Umgebung                          |
| `DNA_ENV`         | `production` (Standard) oder `ote`                            |
| `DNA_TEST_MODE`   | `true` wählt OTE (wie in den anderen DomainNameAPI-SDKs)      |
| `DNA_BASE_URL`    | eine eigene Basis-URL, z. B. ein Proxy                        |

```ruby
client = DomainNameApi::Client.from_env(user_agent: 'my-panel/1.4')
```

Ein falscher Schlüssel oder eine falsche Umgebung schlägt beim ersten Request mit einem `APIError` fehl, dessen `auth?`
true liefert und dessen `hint` angibt, was zu prüfen ist; `client.account.get` ist die günstigste Möglichkeit zur Prüfung.

## Services

| Service            | CLI-Gruppe    | Methoden                                                                                                                                                          |
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

Erforderliche Eingaben sind Positionsargumente (`info('example.com')`), alles andere ist ein Keyword-Argument
(`renew('example.com', years: 1)`). Operationen mit vielen optionalen Eingaben nehmen Keywords oder ein Request-Objekt:
`register(domain_name: ..., years: 1, ...)` und `register(DomainNameApi::DomainRegisterRequest.new(...))` sind
gleichwertig. `ssl.purchase` entspricht `dna ssl initialize` der CLI (`initialize` ist in Ruby reserviert).

## Verwendung

Alle Snippets setzen einen `client` voraus.

### Suche

```ruby
a = client.domains.search('example.com')
a.available?            # a.price, a.currency, a.premium?, a.document_required?, a.reason

client.domains.bulk_search('example.com', 'example.net', 'example.org').each do |r|
  puts "#{r.domain_name} #{r.status} #{r.price}"
end
```

`bulk_search` teilt Listen mit mehr als 30 Domains auf mehrere Requests auf. Preise verwenden die Währung des Kontos,
die Client-Option `currency: 'TRY'` oder `search('example.com', currency: 'USD')`.

### Registrieren

Mit Kontakt-Handles (eines erstellen Sie mit `contacts.create`):

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
  handles: handle # ein Handle für alle vier Rollen oder { registrant: 'DNA-1', admin: 'DNA-2', tech: ..., billing: ... }
)
result.status           # result.domain_id, result.expiration_date
```

Mit Inline-Kontakten:

```ruby
client.domains.register_with_contacts(
  domain_name: 'example.com',
  name_servers: %w[ns1.example.net ns2.example.net],
  contacts: owner # ein Contact für alle vier Rollen oder { registrant: owner, admin: admin, tech: admin, billing: admin }
)
```

Kontakte können `DomainNameApi::Contact`-Objekte oder Hashes mit denselben Feldern sein. Sie werden vor dem Senden
bereinigt: Felder werden getrimmt, das Land wird in Großbuchstaben umgewandelt und Telefonfelder behalten nur ihre Ziffern
(`'+90 (555) 123-45-67'` funktioniert). Einige TLDs benötigen Registry-Attribute: Sie finden sie mit
`client.products.tld('com.tr').required_attributes` und übergeben sie als `tld_attributes:`.

Antwortet die API, lehnt die Operation aber ab (`"success": false`), löst die Methode einen
`DomainNameApi::OperationError` mit der Meldung der API aus.

### Verlängern, transferieren, wiederherstellen

```ruby
check = client.domains.renew_check('example.com', years: 1)   # check.renewable?, check.premium_price
client.domains.renew('example.com', years: 1)

tc = client.domains.transfer_check('example.com', 'auth-code') # tc.transferable?, tc.auth_code_valid?
client.domains.transfer('example.com', auth_code: 'auth-code')
client.domains.transfer_status('example.com').status

client.domains.restore('example.com') # während der Redemption-Phase
```

### Domain-Details und Domainliste

```ruby
d = client.domains.info('example.com')
d.status                # => #<DomainNameApi::DomainStatus Active (0)>
d.expiration_date       # => 2027-03-15 10:20:30 UTC
d.remaining_days, d.locked?, d.privacy_protection?, d.name_servers, d.auth_code, d.hosts
d.contact(:registrant)&.email

# Eine Seite
page = client.domains.list(limit: 50, sort: 'expirationDate')
page.total_count
page.each { |domain| puts domain.domain_name }

# Alle Domains; die Seiten werden nach Bedarf abgerufen
client.domains.all(statuses: [:active]) do |domain|
  puts "#{domain.domain_name} #{domain.expiration_date}"
end
client.domains.all.first(10) # ohne Block ein Enumerator: ruft eine Seite ab
```

### Sperre, Datenschutz, Nameserver, Child-Nameserver

```ruby
client.domains.lock('example.com')
client.domains.unlock('example.com')
client.domains.set_privacy('example.com', true)
code = client.domains.update_auth_code('example.com')

client.domains.set_name_servers('example.com', %w[ns1.example.net ns2.example.net])
client.domains.set_name_servers('example.com', %w[ns1.other.net ns2.other.net], dnssec_mode: :disable) # für signierte Domains

client.domains.add_host('example.com', 'ns1.example.com', '192.0.2.10', '2001:db8::10') # IP-Version wird erkannt
client.domains.update_host('example.com', 'ns1.example.com', ip_addresses: ['192.0.2.20'])
client.domains.delete_host('example.com', 'ns1.example.com')
```

### Kontakte einer Domain

```ruby
client.domains.set_contact_handles('example.com', admin: 'DNA-2', tech: 'DNA-2') # andere Rollen bleiben erhalten
client.domains.update_contacts('example.com', billing: billing_contact)

details = client.contacts.get('DNA-1')               # der Kontakt und sein Verifizierungsstatus
result = client.contacts.update('DNA-1', contact)    # aktualisiert jede Domain, die das Handle verwendet
result.affected_domains.each { |a| puts "#{a.domain_name} #{a.new_handle}" }
client.contacts.resend_verification('DNA-1')          # false, wenn es nichts zu verifizieren gibt
```

### DNS-Zone

```ruby
client.dns.add('example.com', name: 'www', type: :a, values: '192.0.2.10', ttl: 600)
client.dns.update('example.com', record_name: 'www', type: :a, values: %w[192.0.2.20 192.0.2.21]) # ersetzt das Set
client.dns.delete('example.com', name: 'www', type: :a, value: '192.0.2.20')

client.dns.list('example.com').each do |set|
  puts "#{set.name} #{set.type} #{set.ttl} #{set.values.join(', ')}"
end

client.dns.apply('example.com') # stellt die Domain auf die Nameserver der Plattform um
```

Namen können relativ (`'www'`), der Apex (`''` oder `'@'`) oder vollqualifiziert sein. Record-Typen sind Symbole oder
Strings in beliebiger Schreibweise (`:txt` und `'txt'` werden als `TXT` gesendet). Die Validierung fängt ab, was die API
ablehnen würde: einen CNAME am Apex, einen CAA-Wert ohne drei Teile, einen MX-Wert ohne Priorität, einen A-Record mit einer
IPv6-Adresse. Die Testumgebung beantwortet jeden Zonenaufruf mit HTTP 500, Zonen-Code lässt sich daher nur in der Produktion ausprobieren.

### DNSSEC

```ruby
results = client.dnssec.add('example.com', '2371 13 2 1F987CC6583E92DF0890718C42...') # so, wie Ihr DNS-Anbieter ihn anzeigt
info = client.dnssec.get('example.com') # info.status.signed?, info.ds_records
client.dnssec.disable('example.com')
```

`DomainNameApi::DS.parse` liest das Präsentationsformat und ganze Zeilen aus Zonendateien; `DS.new(key_tag: ...,
algorithm: :ecdsa_p256_sha256, digest_type: :sha256, digest: '...')` funktioniert ebenfalls.

### URL-Weiterleitung

```ruby
client.domains.set_forwarding('example.com', 'https://www.example.org')              # 301-Weiterleitung
client.domains.set_forwarding('example.com', 'https://www.example.org', type: :frame) # maskiert
f = client.domains.forwarding('example.com') # nil, wenn die Domain keine hat
client.domains.delete_forwarding('example.com')
```

### Registry-Dokumente (.tr)

```ruby
doc = DomainNameApi::DocumentUpload.from_file(:identity_card, 'id.pdf')
client.domains.upload_documents('example.com.tr', doc)
client.domains.documents('example.com.tr').each { |d| puts "#{d.name} #{d.status}" }
```

Dateien werden für Sie Base64-kodiert; Format (PDF, JPG, PNG, DOC, DOCX, ODT) und Größe (10 MB pro Datei, 50 MB pro
Request) werden vor dem Upload geprüft.

### SSL-Zertifikate

```ruby
csr = client.ssl.generate_csr(domain_name: 'example.com', country: 'TR', state: 'Istanbul', locality: 'Istanbul',
                              organization: 'Example Ltd', organization_unit: 'IT')
# belastet das Guthaben (CLI: dna ssl initialize)
order = client.ssl.purchase('example.com', package_code: 'PositiveSSL')
id = order.certificate_id # aufbewahren: jeder spätere Aufruf erwartet sie
client.ssl.configure(certificate_id: id, csr: csr.csr, approver_mail: 'admin@example.com',
                     authentication_type: :email, web_server_type: :apache, contact: ssl_contact)
client.ssl.status(id).issued? # so lange abfragen, bis true
File.write('example.com.crt', client.ssl.content(id).chain)
```

Eine Domain kann mehrere Zertifikate haben. Ein bestehendes Zertifikat wird deshalb über seine `certificate_id`
(eine GUID) angesprochen, nie über den Domainnamen: `purchase` und `renew` geben sie zurück, `list` findet sie.
Ein Domainname an einer Stelle, an der eine ID erwartet wird, löst einen `InputError` aus, bevor etwas gesendet
wird. Konfigurieren Sie ein Zertifikat innerhalb von 15 Tagen nach dem Kauf oder der Verlängerung.

```ruby
client.ssl.list(domain_name: 'example.com').each { |c| puts "#{c.certificate_id} #{c.status}" } # neueste zuerst
client.ssl.all { |c| puts "#{c.domain_name} #{c.subscription_expires_at}" } # alle Zertifikate, Seite für Seite

client.ssl.approvers(certificate_id: id)                                      # für ein bestehendes Zertifikat
client.ssl.approvers(domain_name: 'example.com', package_code: 'PositiveSSL') # vor einem Kauf

renewal = client.ssl.renew(id) # belastet das Guthaben; möglich ab 30 Tagen vor Ablauf des Abonnements
client.ssl.configure(certificate_id: renewal.certificate_id, csr: new_csr.csr, approver_mail: 'admin@example.com',
                     authentication_type: :email, web_server_type: :apache, contact: ssl_contact)
```

Zum Verlängern rufen Sie `renew` auf und konfigurieren anschließend mit `configure` das neue Zertifikat, das
zurückgegeben wird. Rufen Sie nicht erneut `purchase` auf: Das wäre eine unabhängige neue Bestellung zum
Kaufpreis, und das alte Zertifikat erhält nie den Status `Renewed`.

### Hosting

```ruby
client.hosting.packages.each { |p| puts p.service_plans.map(&:service_plan) }
created = client.hosting.create('example.com', service_plan: 'Linux-Starter') # belastet das Guthaben

st = client.hosting.wait(created.service_id, timeout: 30 * 60) # fragt ab, bis das Hosting aktiv ist
puts st.panel_address, st.username, st.password
```

Rufen Sie `create` nie erneut für ein Hosting auf, das noch bereitgestellt wird: Das belastet Ihr Guthaben doppelt.

### Guthaben, Preise und Bestellungen

```ruby
account = client.account.get
account.balance('USD')
profile = client.account.profile # profile.company_name, profile.account_currency, profile.status.active?

client.account.all_transactions(from: Date.new(2026, 11, 1)) do |tx|
  puts "#{tx.creation_time} #{tx.type} #{tx.change}"
end

tld = client.products.tld('com.tr')
tld&.register_price(1)&.to_s   # => "12.50 USD"

client.products.info('com', order_type: :renew, years: 2) # Preis einer 2-jährigen .com-Verlängerung
client.orders.get('ORDER-CODE')
```

## Ergebnisse, Modelle und Enums

Jedes Ergebnis ist ein `DomainNameApi::Model`: snake_case-Reader, `?`-Prädikate für Flags, `Time`-Objekte für
Datumsangaben, verschachtelte Modelle und Listen.

```ruby
d = client.domains.info('example.com')
d.locked?                 # auch d.locked
d.hosts.first.ip_addresses.first.address
d.to_h                    # ein einfacher Hash mit snake_case-Schlüsseln
d.raw                     # das JSON-Objekt, wie die API es gesendet hat, für Felder, die dieses Gem nicht modelliert
```

Numerische Werte und feste String-Werte sind Enums (`DomainStatus`, `RecordType`, `ContactType`, `DocumentType`, ...):

```ruby
d.status.pending_delete?                       # ein Prädikat pro Enum-Wert
d.status == DomainNameApi::DomainStatus::ACTIVE
d.status == :active                            # auch Symbole, Namen und Zahlen lassen sich vergleichen
d.status.to_s                                  # => "Active"
d.status.to_i                                  # => 0
DomainNameApi::DomainStatus.members            # alle Werte
```

Requests akzeptieren Enums, Symbole, Namen in beliebiger Schreibweise oder Zahlen: `statuses: [:active, 'PendingDelete', 7]`.

Das Dekodieren ist tolerant: Datumsangaben ohne Zeitzone, `null`, `[]` statt `{}`, als Strings gesendete Zahlen, Rollen
in beliebiger Schreibweise (`"registrant"`, `"ADMINISTRATIVE"`) und Werte, die dieses Gem noch nicht kennt, werden alle
dekodiert, statt den Aufruf scheitern zu lassen (`status.known?` ist bei Letzteren false).

## Requests und BaseRequest

Jede API-Operation ist eine Request-Klasse: `DomainInfoRequest`, `DNSAddRequest`, `SSLConfigureRequest`, ..., jeweils
benannt nach dem CLI-Befehl (`dna domain renew` entspricht `DomainRenewRequest`). Sie erben alle von
`DomainNameApi::BaseRequest`, das das Grundgerüst liefert: eine `endpoint`- und `attribute`-DSL auf Klassenebene,
Initialisierung per Keywords, Validierungshelfer, Pfadvorlagen sowie Query- und Body-Builder. Listen-Requests erben von
`PagedRequest`, das `skip`, `limit` und `sort` ergänzt. Ein Request aus diesem Gem sieht so aus:

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

Die Service-Methoden erstellen diese Requests für Sie. `client.call` sendet jeden Request, auch eigene Klassen, zum
Beispiel, um nur die benötigten Felder zu lesen oder einen Endpoint aufzurufen, den dieses Gem noch nicht abdeckt:

```ruby
class Expiry < DomainNameApi::Model
  field :expiration_date, :time
  field :remaining_days, :integer, from: 'remainingDay'
end

class ExpiryRequest < DomainNameApi::BaseRequest
  endpoint :get, '/api/v1/domains/info', safety: :read
  returns Expiry            # weglassen, um das geparste JSON zu erhalten
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

| Überschreibbare Methode | Standard         | Zweck                                                                       |
|-------------------------|------------------|-----------------------------------------------------------------------------|
| `query`                 | `nil`            | eine `Query` (`params.string(...)`), ein Hash oder ein Array von Paaren     |
| `body`                  | `nil`            | ein Hash oder Array mit den Namen der API; Enums, Modelle und Zeiten werden umgewandelt |
| `validate`              | nichts zu prüfen | Probleme mit `required`, `check`, `between`, `max_length`, `enum` melden    |
| `decode(data)`          | verwendet `returns` | das geparste JSON in Ihr Ergebnis umwandeln                              |

Pfad-Platzhalter werden aus den Attributen befüllt und escaped: `endpoint :get, '/api/v1/contacts/{handle}'`.

Ihr Request erhält alles, was die eingebauten erhalten: Zugangsdaten, Retries, Pacing, Fehlernormalisierung,
Correlation-IDs, Tracing und Read-only-Durchsetzung. `client.execute(request)` gibt die vollständige `Response` zurück
(Status, Header, Roh-Body, Correlation-ID, Quota, Versuche), mit dem dekodierten Ergebnis in `value`.
`client.prepare(request)` validiert und baut den exakten HTTP-Request, ohne ihn zu senden, um einen kostenpflichtigen
Request vor dem Absenden zu protokollieren oder zu prüfen (der API-Schlüssel wird in `inspect` maskiert).

## Fehler

| Fehler                           | Wann                                                       | Nützliche Methoden                                                             |
|----------------------------------|------------------------------------------------------------|--------------------------------------------------------------------------------|
| `DomainNameApi::InputError`      | die Validierung hat den Request abgelehnt; **es wurde nichts gesendet** | `request`, `fields`                                               |
| `DomainNameApi::APIError`        | die API hat mit einem Nicht-2xx-Status geantwortet         | `status`, `code`, `api_message`, `details`, `fields`, `data`, `correlation_id`, `hint` |
| `DomainNameApi::OperationError`  | die API hat mit 2xx und `"success": false` geantwortet     | `code`, `api_message`, `correlation_id`                                        |
| `DomainNameApi::NetworkError`    | der Request wurde nicht abgeschlossen (DNS, TLS, Timeout, Reset) | `original`, `timeout?`                                                   |
| `DomainNameApi::ReadOnlyError`   | ein Read-only-Client hat eine Änderung blockiert; es wurde nichts gesendet | `safety`                                                       |

Alle erben von `DomainNameApi::Error`, das die häufigen Fragen beantwortet: `kind` (`:auth`,
`:not_found`, `:validation`, `:rejected`, `:conflict`, `:rate_limited`, `:server`, `:network`, `:invalid_input`,
`:read_only`), `not_found?`, `auth?`, `rate_limited?`, `insufficient_balance?`, `outcome_unknown?`,
`retryable?` und `code?(code)`.

```ruby
begin
  client.domains.renew('example.com', years: 1)
rescue DomainNameApi::Error => e
  if e.outcome_unknown?
    # Die Verlängerung ist möglicherweise durchgegangen. Prüfen Sie die Domain, bevor Sie es erneut versuchen.
  elsif e.insufficient_balance?
  elsif e.not_found?
  elsif e.code?(DomainNameApi::ErrorCode::PRIVACY_NOT_SUPPORTED)
  elsif e.is_a?(DomainNameApi::APIError)
    logger.error("#{e.code} #{e.api_message} #{e.hint} #{e.correlation_id}")
  end
end
```

Verzweigen Sie nach `code`, nicht nach der Meldung: Meldungen sind lokalisiert. API-Codes sehen so aus:
`Dna.DomainService:Domain:10007`; die häufigen sind Konstanten in `DomainNameApi::ErrorCode`, die übrigen stehen in der
[Fehlerreferenz](https://www.domainnameapi.com/docs/reference/errors.md). Nennen Sie die `correlation_id`, wenn Sie
den Support kontaktieren.

## Sicherheit und Zuverlässigkeit

- **Sicherheitsklassen.** Jeder Request ist `:read`, `:write`, `:destructive` oder `:billable` (`request.safety`,
  `request.billable?`). Einige POST- und PUT-Requests sind Lesezugriffe (`DomainSearchRequest`, `SSLStatusRequest`).
- **Read-only-Modus.** `read_only: true` blockiert alles, was kein Lesezugriff ist, für Reporting-Jobs und um
  die Produktion gefahrlos zu erkunden.
- **Retries.** 429-Antworten werden immer wiederholt und berücksichtigen `Retry-After`: Die API weist sie ab, bevor sie
  etwas tut. Netzwerkfehler und 502/503/504 werden nur für Lesezugriffe und idempotente Schreibzugriffe wiederholt, sodass eine Registrierung
  oder Verlängerung nie zweimal gesendet wird. Prüfen Sie nach einem fehlgeschlagenen kostenpflichtigen Request `e.outcome_unknown?`.
- **Pacing.** Der Client verteilt Requests zeitlich, um unter den Limits pro Schlüssel zu bleiben (5 Requests/Sekunde, 2 Suchen/Sekunde,
  ein Zonenaufruf pro Sekunde). Schalten Sie es mit `pacing: false` ab, wenn Sie selbst drosseln.
- **Quota.** `client.execute(request).quota` stellt die Soft-Quota-Header bereit. Bei Überschreitung des Limits verlangsamt die API
  die Antworten (bis zu 5 s), statt sie abzuweisen; das Standard-Timeout von 60 s lässt dafür Spielraum.
- **Correlation-IDs.** Jeder Request trägt einen `X-Correlation-ID`. Setzen Sie eine eigene, um API-Aufrufe mit Ihren Logs zu verknüpfen:
  `DomainNameApi.with_correlation_id(job.id) { ... }` oder `client.call(request, correlation_id: job.id)`.
- **Observability.** `logger: Logger.new($stdout)` protokolliert jeden Austausch; `on_trace: ->(event) { ... }` liefert Ihnen
  jeden Request, jede Response und jeden Retry als `TraceEvent`, für Metriken oder Fehlerberichte. Der API-Schlüssel ist nie
  darin enthalten; Bodies können Kontaktdaten enthalten, maskieren Sie sie daher vor dem Speichern.
- **Threads.** Ein Client kann sicher zwischen Threads geteilt werden. Erstellen Sie einen und verwenden Sie ihn wieder.
- **Nichts anderes verlässt Ihren Prozess.** Keine Telemetrie, keine Drittanbieterdienste.

## Client-Optionen

| Option                       | Wirkung                                                                             |
|------------------------------|-------------------------------------------------------------------------------------|
| `environment: :ote`          | die Testumgebung verwenden (Standard `:production`)                                 |
| `base_url: 'https://...'`    | Requests an einen Proxy oder einen Testserver senden                                |
| `timeout: 60`                | Sekunden pro HTTP-Versuch                                                           |
| `open_timeout: 10`           | Sekunden für den Verbindungsaufbau                                                  |
| `user_agent: 'app/1.0'`      | Ihr Produkt dem User-Agent voranstellen                                             |
| `currency: 'TRY'`            | Währung der Such- und Katalogpreise                                                 |
| `retries: 2`                 | Anzahl der Retries                                                                  |
| `max_retry_wait: 30`         | das längste `Retry-After`, auf das der Client wartet                                |
| `pacing: false`              | clientseitiges Pacing abschalten                                                    |
| `read_only: true`            | jeden Request blockieren, der kein Lesezugriff ist                                  |
| `logger: Logger.new($stdout)`| Austausch protokollieren: Requests auf Level debug, Retries auf warn, Fehler auf error |
| `on_trace: ->(event) {}`     | jeden Request, jede Response und jeden Retry beobachten                             |
| `transport: my_transport`    | Ihre eigene HTTP-Schicht (Proxy, Connection-Pool, ...): jedes Objekt mit `call(request)` |

`DomainNameApi::NetHTTPTransport.new(proxy: 'http://proxy:8080', ca_file: 'corp-ca.pem')` ist der Standardtransport
mit einem Proxy oder Ihrem eigenen CA-Bundle. Redirects werden nie verfolgt: Die API antwortet bei einer unbekannten
oder gesperrten Reseller ID mit 302, was zu einem Authentifizierungsfehler wird.

## Den eigenen Code testen

Übergeben Sie einen Transport, der wie die API antwortet; sonst muss nichts gemockt werden:

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

`request` ist ein `DomainNameApi::PreparedRequest` (`http_method`, `url`, `headers`, `body`), sodass der Fake auch
prüfen kann, was gesendet wurde. WebMock und VCR funktionieren ebenfalls, da der Standardtransport `Net::HTTP` ist.

## Migration von v1

v2 ist ein neues Design: typisierte Ergebnisse statt Hashes mit String-Schlüsseln, Exceptions statt
`{'result' => 'ERROR'}`-Umschläge und die vollständige API statt des Methodensatzes von php-dna. Der Gem-Name bleibt
`domainnameapi`; fixieren Sie `tag: 'v1.0.1'`, um v1 zu behalten, bis Sie umsteigen.

| v1                                                   | v2                                                                       |
|------------------------------------------------------|--------------------------------------------------------------------------|
| `Client.new(id, key, true)`                          | `Client.new(reseller_id: id, api_key: key, environment: :ote)`           |
| `res['result'] == 'OK'`                              | keine Exception                                                          |
| `get_reseller_details`, `get_current_balance`        | `account.get` (+ `account.balance('USD')`)                               |
| `check_availability`                                 | `domains.search`, `domains.bulk_search`                                  |
| `get_list`                                           | `domains.list`, `domains.all`                                            |
| `get_tld_list`                                       | `products.tlds`, `products.all_tlds`, `products.tld`                     |
| `get_details`, `get_contacts`, `sync_from_registry`  | `domains.info`                                                           |
| `register_with_contact_info`                         | `domains.register_with_contacts` (oder `contacts.create` + `domains.register`) |
| `renew`, `transfer`, `check_transfer`                | `domains.renew`, `domains.transfer`, `domains.transfer_check`            |
| `modify_name_server`                                 | `domains.set_name_servers`                                               |
| `enable_theft_protection_lock` / `disable_...`       | `domains.lock` / `domains.unlock`                                        |
| `modify_privacy_protection_status`                   | `domains.set_privacy`                                                    |
| `save_contacts`                                      | `domains.update_contacts`, `domains.set_contact_handles`                 |
| `add_child_name_server`, `modify_child_name_server`, `delete_child_name_server` | `domains.add_host`, `domains.update_host`, `domains.delete_host` |
| `get_resource_records`                               | `dns.list`                                                               |
| `add_resource_record`, `add_resource_record_value`   | `dns.add`                                                                |
| `edit_resource_record`, `set_resource_record_set`, `replace_resource_record_value` | `dns.update`                               |
| `delete_resource_record`, `remove_resource_record_value`, `delete_resource_record_set` | `dns.delete` (einmal pro Wert)         |
| `apply_resource_records`                             | `dns.apply`                                                              |
| `get_forwarding`, `set_forwarding`, `delete_forwarding` | `domains.forwarding`, `domains.set_forwarding`, `domains.delete_forwarding` |
| `cancel_transfer`, `approve_transfer`, `reject_transfer` | nicht in der veröffentlichten API; senden Sie einen [eigenen Request](#requests-und-baserequest), falls Ihr Konto sie hat |
| `is_tr_tld`, `validate_contact`                      | `name.end_with?('.tr')`; die Validierung läuft bei jedem Request         |
| `get_request_data`, `get_response_data`, ...         | `on_trace:`, `logger:`, `client.execute(request)`                        |
| Telemetrie (`set_error_reporting_enabled`, Sentry)   | entfernt: nichts verlässt Ihren Prozess; leiten Sie `on_trace`-Events an Ihr eigenes Reporting weiter |
| `set_ssl_verification(false)`                        | `transport: NetHTTPTransport.new(ca_file: ...)` mit Ihrem eigenen CA-Bundle |

## Entwicklung

```bash
bundle install
bundle exec rake test   # Unit-Tests; keiner greift auf das Netzwerk zu
```

`test/fixtures/openapi.json` ist das OpenAPI-Dokument der API. Die Tests prüfen jede Request-Klasse dagegen
(Methode, Pfad, Query-Namen, Body-Felder, Pflichtfelder), die JSON-Namen jedes Response-Modells gegen die Response-Schemas
sowie jeden Enum-Wert und schlagen fehl, wenn die API eine Operation ohne Request-Klasse erhält. So aktualisieren Sie es:

```bash
curl -fsSL -A "ruby-dna-spec-update" -o test/fixtures/openapi.json https://api.domainresellerapi.com/swagger/v1/swagger.json
bundle exec rake test
```

Die Konventionen dieses Repositorys finden Sie in [AGENTS.md](AGENTS.md).

## Support

- API-Dokumentation: <https://www.domainnameapi.com/docs/>
- CLI und MCP-Server: <https://github.com/domainreseller/cli>
- Website: <https://www.domainnameapi.com>

## Lizenz

Apache License 2.0. Siehe [LICENSE](LICENSE).
