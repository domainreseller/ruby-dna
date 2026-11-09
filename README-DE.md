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

# ruby-dna — DomainNameAPI-Client für Ruby

Registrieren, verlängern und transferieren Sie Domains und verwalten Sie Kontakte, Nameserver, Child-Nameserver, DNS-Zonen und URL-Weiterleitungen über die DomainNameAPI REST-API. `ruby-dna` ist eine originalgetreue Portierung von [php-dna](https://github.com/domainreseller/php-dna): dieselben Methoden, dieselben Anfragen auf der Leitung und dieselben Rückgabewerte, überprüft anhand der Konformitäts-Fixtures von php-dna.

## 📦 Download — immer die Releases verwenden!

⬇️ **Die neueste getestete Version erhalten Sie hier: https://github.com/domainreseller/ruby-dna/releases/latest**

> ⚠️ Verwenden Sie **nicht** den grünen Button **Code → Download ZIP** — damit laden Sie den rohen Entwicklungszweig herunter. Release-Pakete sind versioniert, getestet und produktionsreif.

## Installations- und Integrationsanleitung

### Mindestanforderungen

- Ruby 2.7 oder höher (Empfohlen 3.3+)
- Keine Laufzeitabhängigkeiten: nur die Standardbibliothek (`net/http`, `json`, `openssl`).

### A) Bundler

```ruby
# Gemfile
gem 'domainnameapi', git: 'https://github.com/domainreseller/ruby-dna.git', tag: 'v1.0.0'
```

```bash
bundle install
```

### B) Gem-Datei aus dem Release

Laden Sie `domainnameapi-1.0.0.gem` aus dem [neuesten Release](https://github.com/domainreseller/ruby-dna/releases/latest) herunter und führen Sie dann aus:

```bash
gem install ./domainnameapi-1.0.0.gem
```

### C) Manuelle Verwendung

Laden Sie das Release-Archiv herunter, kopieren Sie den Ordner `lib` in Ihr Projekt und sehen Sie sich die Beispiele im Ordner [examples](examples) an:

```ruby
$LOAD_PATH.unshift File.expand_path('lib', __dir__)
require 'domainnameapi'
```

## 🔑 API-Zugangsdaten — Reseller ID & API Key

Die Bibliothek kommuniziert mit der DomainNameAPI REST-API und benötigt genau zwei Zugangsdaten, die dem Konstruktor übergeben werden:

| Parameter | Wert |
|---|---|
| Erster | Reseller ID — UUID wie `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx` |
| Zweiter | API Key |

> 💡 Ihre **Reseller ID** und Ihren **API Key** finden Sie in Ihrem DomainNameAPI-Panel unter **API-Einstellungen**.
> ⚠️ Dies sind **API-Zugangsdaten** — Ihre Panel-Anmeldedaten funktionieren hier **nicht**.

## Schnellstart

```ruby
require 'domainnameapi'

reseller_id = 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx'
api_key     = 'your-api-key'

# Live-Umgebung
dna = DomainNameApi::Client.new(reseller_id, api_key)

# Test-Umgebung (OTE)
dna = DomainNameApi::Client.new(reseller_id, api_key, true)

result = dna.get_details('example.com')
if result['result'] == 'OK'
  puts result['data']['Dates']['Expiration']
else
  puts "#{result['error']['Code']}: #{result['error']['Message']}"
end
```

Die Methodennamen sind die snake_case-Form der Namen aus php-dna (`getDetails` → `get_details`, `registerWithContactInfo` → `register_with_contact_info`), mit derselben Parameterreihenfolge und denselben Standardwerten. Die Ergebnisse sind einfache Ruby-Hashes und -Arrays mit **String-Schlüsseln**, exakt in der Struktur, die php-dna zurückgibt (einschließlich String-Flags wie `'LockStatus' => 'true'` und formatierter Preise wie `'11.9900'`). Leerzeichen um die Zugangsdaten werden entfernt, und das Testmodus-Flag akzeptiert auch Strings: `"true"`, `"1"`, `"on"` und `"yes"` bedeuten Testmodus, alles andere bedeutet Live-Betrieb.

## Fehlerbehandlung

Bei API- oder Netzwerkproblemen lösen die Methoden niemals eine Exception aus. Ein fehlgeschlagener Aufruf liefert eine Fehlerstruktur zurück:

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

- `Code` lautet bei Gateway-Fehlern `API_<HTTP-Status>` (`API_400`, `API_401`, `API_429`, `API_500`, ...). Eine `301`/`302`-Antwort bedeutet ungültige Zugangsdaten (`Invalid API credentials`).
- Ein leerer Fehlertext wird zu einer lesbaren Meldung wie `HTTP 429 - Too Many Requests`.
- Feldvalidierungsfehler werden zu `Details` zusammengefasst, z. B. `Admin PostalCode - 'PostalCode' is required`.
- Netzwerkausfälle sind Fehler und niemals ein leerer Erfolg. Ein Timeout lautet `Could not reach the DomainNameAPI service: the connection timed out. (...)`; andere Transportfehler lauten `Curl error during request: ...`. Ihre Codes folgen den Nummern von curl (`API_28` Timeout, `API_6` DNS, `API_7` Verbindung abgelehnt, `API_35`/`API_60` TLS); `get_parsed_response_data['Code']` enthält `CURL_<n>`.
- `get_current_balance` behält seine eigene Struktur: `'OperationResult' => 'FAILED'` mit `ErrorCode` und `OperationMessage`.
- `check_availability` liefert bei Erfolg eine einfache Liste und bei einem Fehler die Fehlerstruktur.

Nur Programmierfehler lösen eine Exception aus (zum Beispiel löst `set_resource_record_set` mit `contents`, das keine Liste ist, einen `TypeError` aus).

Die Timeouts betragen 30 Sekunden pro Aufruf und 10 Sekunden für den Verbindungsaufbau. Aufrufe der DNS-Zonen-Endpunkte erfolgen im Abstand von mindestens einer Sekunde, da das Gateway auf schnelle Folgen von Anfragen mit `HTTP 429` antwortet.

### Diagnose

```ruby
dna.get_request_data         # { 'url' => ..., 'method' => 'GET', 'payload' => {...} } des letzten Aufrufs
dna.get_response_data        # zuletzt dekodierter Antworttext (oder { 'raw_response' => body })
dna.get_response_headers     # { 'url', 'http_code', 'headers', 'total_time' }
dna.get_parsed_response_data # zuletzt geparster Antworttext oder der letzte Fehler { 'Code', 'Message', 'Details' }
dna.get_last_function        # z. B. 'request:GET domains/info'
dna.get_service_url          # https://api.domainresellerapi.com/api/v1
dna.set_service_url('https://ote.domainresellerapi.com/api/v1')
```

## Testmodus

Übergeben Sie `true` als drittes Konstruktorargument, um das OTE-Test-Gateway (`https://ote.domainresellerapi.com/api/v1`) zu verwenden. Live-Aufrufe gehen an `https://api.domainresellerapi.com/api/v1`. Der Testmodus verwendet separate Test-Zugangsdaten.

## Fehlerberichte (Telemetrie)

Wenn ein API-Aufruf fehlschlägt, kann die Bibliothek einen Fehlerbericht an den eigenen Fehler-Tracker von DomainNameAPI (Sentry) senden. Ein kleiner, zufällig gewählter Anteil erfolgreicher Aufrufe (4 %, dazu jeder Aufruf, der länger als 1 Sekunde dauert) kann als Performance-Datensatz gesendet werden. Das hilft DomainNameAPI, Probleme zu finden und zu beheben. Fehlerberichte sind **standardmäßig aktiviert**.

> ℹ️ In Version 1.0.0 existiert das Sentry-Projekt für ruby-dna noch nicht, daher ist der eingebaute DSN leer und es wird **nichts gesendet**. Berichte werden gesendet, sobald ein Release den DSN mitliefert. Mit `DomainNameApi::Client.new(id, key, false, sentry_dsn: '...')` lässt sich ein DSN explizit setzen.

**Was gesendet wird:**

- Fehlercode und -meldung
- Pfad des aufgerufenen Endpunkts und HTTP-Methode
- Dauer des Aufrufs
- Bibliotheksname (`DomainNameAPI-Ruby`), Bibliotheksversion und Ruby-Version
- Reseller ID und Domainname
- die öffentliche IP-Adresse des Servers (im Hintergrund ermittelt über `api.ipify.org`)
- der Benutzername des Betriebssystems, unter dem der Prozess läuft
- API-Anfrage und -Antwort, einschließlich der Kontaktdaten der Domain; nur Zugangsdaten werden maskiert – EPP-/Auth-Codes, API-Keys, Passwörter und Tokens werden durch `***` ersetzt

**Was nie gesendet wird:** EPP-/Auth-Codes, API-Keys, Passwörter oder Tokens in lesbarer Form; Methodenargumente in Stacktraces.

Erwartete, häufig auftretende Fehler (Domain nicht gefunden, unzureichendes Guthaben, ungültige Zugangsdaten, ...) werden nicht gemeldet. Die Berichte werden aus einem Hintergrund-Thread mit kurzen Timeouts gesendet: Sie verlangsamen Ihren Aufruf niemals und lassen ihn niemals fehlschlagen.

**Wozu und wie lange:** Die Daten werden ausschließlich zur Nutzungsmessung und zur frühzeitigen Erkennung von Problemen verwendet und 30 Tage lang auf dem eigenen Sentry-Server von DomainNameAPI gespeichert; danach werden sie automatisch gelöscht.

**So schalten Sie es ab:**

```ruby
dna = DomainNameApi::Client.new(reseller_id, api_key)
dna.set_error_reporting_enabled(false)
```

Der **Minimalmodus** sendet nur Fehlercode und -meldung, Endpunkt, Zeitmessung, Versionen und die Reseller ID — keine Anfrage-/Antwortdaten, keine Domain, keine Server-IP und keinen Benutzernamen:

```ruby
dna.set_telemetry_minimal(true)
```

> 🔒 **Sicherheit:** Die TLS-Zertifikatsprüfung ist aktiviert. Auf einem Server mit veraltetem CA-Bundle kann sie mit `dna.set_ssl_verification(false)` abgeschaltet werden — nicht empfohlen; besser ist es, das CA-Bundle zu aktualisieren.

## Verwendung

Alle Beispiele setzen `dna = DomainNameApi::Client.new(reseller_id, api_key)` voraus. Ausführbare Skripte für jede Methode finden Sie unter [examples](examples).

### Konto

#### Reseller-Details

```ruby
dna.get_reseller_details
```

<details>
<summary>Beispielausgabe</summary>

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
    { 'balance' => '601.64', 'currency' => 'USD', 'symbol' => '$' },
    { 'balance' => '1250.5', 'currency' => 'TL',  'symbol' => 'TL' }
  ]
}
```

</details>

#### Aktuelles Guthaben

`get_current_balance(currency = 'USD')` — `'USD'`, `'TRY'`, `'EUR'` oder `'GBP'`.

```ruby
dna.get_current_balance('USD')
```

<details>
<summary>Beispielausgabe</summary>

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
```

</details>

<hr style="border: 4px solid #000; border-style: dashed;">

### Suche und Listen

#### Domain-Verfügbarkeitsprüfung

`check_availability(domains, extensions, period, command = 'create')`

```ruby
dna.check_availability(['hello', 'world123x0'], ['com', 'net'], 1, 'create')
```

<details>
<summary>Beispielausgabe</summary>

```ruby
[
  { 'TLD' => 'com', 'DomainName' => 'hello', 'Status' => 'notavailable', 'Command' => 'create',
    'Period' => 1, 'IsFee' => false, 'Price' => '10.8100', 'Currency' => 'USD', 'Reason' => 'Domain exists' },
  { 'TLD' => 'com', 'DomainName' => 'world123x0', 'Status' => 'available', 'Command' => 'create',
    'Period' => 1, 'IsFee' => false, 'Price' => '10.8100', 'Currency' => 'USD', 'Reason' => nil }
]
```

</details>

#### Domain-Liste

`get_list(extra_parameters = {})` — `PageNumber` (beginnend bei 0), `PageSize`, `OrderColumn`, `OrderDirection` sowie die eigenen Filter des Gateways (z. B. `DomainName`).

```ruby
dna.get_list('OrderColumn' => 'Id', 'OrderDirection' => 'ASC', 'PageNumber' => 0, 'PageSize' => 1000)
```

<details>
<summary>Beispielausgabe</summary>

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

#### TLD-Liste

`get_tld_list(count = 20)`

```ruby
dna.get_tld_list(100)
```

<details>
<summary>Beispielausgabe</summary>

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

#### Domain-Registrierung

`register_with_contact_info(domain, period, contacts, name_servers = [], epp_lock = true, privacy_lock = false, additional_attributes = {})`

Kontakte verwenden die Schlüssel von php-dna. Akzeptiert werden sowohl die unten gezeigte flache Form als auch die verschachtelte Form, die `get_contacts` zurückgibt (`Address => { Line1, City, ... }`, `Phone => { Phone => { Number, CountryCode } }`); fehlende Felder werden ergänzt und Namen, Telefonnummern und Länder normalisiert (siehe `validate_contact`). Werden keine Nameserver angegeben, werden `ns1.domainnameapi.com` und `ns2.domainnameapi.com` verwendet.

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

Für `.tr`-Domains übergeben Sie die TRABIS-Attribute als 7. Argument:

```ruby
# Privatperson als Inhaber
{ 'TRABISDOMAINCATEGORY' => 1, 'TRABISCITIZIENID' => '12345678901' }
# Unternehmen als Inhaber
{ 'TRABISDOMAINCATEGORY' => 0, 'TRABISTAXOFFICE' => 'Istanbul VD', 'TRABISTAXNUMBER' => '1234567890' }
```

Die Kategorie wird als `Owner`/`Corporate` gesendet, `TRABISCITIZIENID` als `TRABISCITIZENID`, und veraltete Schlüssel (`TRABISNAMESURNAME`, `TRABISCOUNTRYID`, `TRABISCITYID`, ...) werden verworfen, da das Gateway diese Angaben inzwischen aus dem Kontakt liest.

<details>
<summary>Beispielausgabe</summary>

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

#### Domain-Verlängerung

```ruby
dna.renew('example.com', 1)
```

<details>
<summary>Beispielausgabe</summary>

```ruby
{ 'result' => 'OK', 'data' => { 'ExpirationDate' => '2025-03-15T10:00:00' } }
```

</details>

#### Domain-Details

```ruby
dna.get_details('example.com')
```

<details>
<summary>Beispielausgabe</summary>

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

#### Synchronisierung mit der Registry

Gleicher Aufruf und gleiche Ausgabe wie bei `get_details`.

```ruby
dna.sync_from_registry('example.com')
```

#### Nameserver-Änderung

Übergeben Sie eine Liste oder einen Hash (dabei werden die Werte verwendet).

```ruby
dna.modify_name_server('example.com', ['ns1.example.com', 'ns2.example.com'])
```

<details>
<summary>Beispielausgabe</summary>

```ruby
{ 'result' => 'OK', 'data' => { 'NameServers' => ['ns1.example.com', 'ns2.example.com'] } }
```

</details>

#### Domain-Sperre aktivieren

```ruby
dna.enable_theft_protection_lock('example.com')
```

<details>
<summary>Beispielausgabe</summary>

```ruby
{ 'result' => 'OK', 'data' => { 'LockStatus' => true } }
```

</details>

#### Domain-Sperre deaktivieren

```ruby
dna.disable_theft_protection_lock('example.com')
```

<details>
<summary>Beispielausgabe</summary>

```ruby
{ 'result' => 'OK', 'data' => { 'LockStatus' => false } }
```

</details>

#### Domain-Privatsphäre ändern

`modify_privacy_protection_status(domain, status, reason = 'Owner request')` — der Privatsphäreschutz wird nur eingeschaltet, wenn `status` exakt `true` ist.

```ruby
dna.modify_privacy_protection_status('example.com', true, 'Owner request')
```

<details>
<summary>Beispielausgabe</summary>

```ruby
{ 'data' => { 'PrivacyProtectionStatus' => true }, 'result' => 'OK' }
```

</details>

#### Domain-Kontakte abrufen

```ruby
dna.get_contacts('example.com')
```

<details>
<summary>Beispielausgabe</summary>

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
    }
  },
  'result' => 'OK'
}
```

</details>

#### Domain-Kontakte speichern

```ruby
dna.save_contacts('example.com', {
  'Administrative' => contact,
  'Billing'        => contact,
  'Technical'      => contact,
  'Registrant'     => contact
})
```

<details>
<summary>Beispielausgabe</summary>

```ruby
{ 'result' => 'OK', 'data' => { 'contacts' => {} } }
```

</details>

<hr style="border: 4px solid #000; border-style: dashed;">

### Child-Nameserver

#### Child-Nameserver hinzufügen

```ruby
dna.add_child_name_server('example.com', 'ns1.example.com', '1.2.3.4')
```

<details>
<summary>Beispielausgabe</summary>

```ruby
{ 'result' => 'OK', 'data' => { 'NameServer' => 'ns1.example.com', 'IPAdresses' => ['1.2.3.4'] } }
```

</details>

#### Child-Nameserver löschen

```ruby
dna.delete_child_name_server('example.com', 'ns1.example.com')
```

<details>
<summary>Beispielausgabe</summary>

```ruby
{ 'result' => 'OK', 'data' => { 'NameServer' => 'ns1.example.com' } }
```

</details>

#### Child-Nameserver aktualisieren

```ruby
dna.modify_child_name_server('example.com', 'ns1.example.com', '1.2.3.5')
```

<details>
<summary>Beispielausgabe</summary>

```ruby
{ 'result' => 'OK', 'data' => { 'NameServer' => 'ns1.example.com', 'IPAdresses' => ['1.2.3.5'] } }
```

</details>

<hr style="border: 4px solid #000; border-style: dashed;">

### Transfers

#### Domain-Transfer

`transfer(domain, epp_code, period, contacts = {})` — wie bei der Fassade von php-dna wird der Transfer ohne Kontakte gesendet (das Gateway behält die aktuellen bei).

```ruby
dna.transfer('example.com', 'Xy9#mK2$', 3)
```

<details>
<summary>Beispielausgabe</summary>

```ruby
{
  'data' => { 'ID' => 0, 'Status' => 'WaitingForIncomingTransfer', 'DomainName' => 'example.com', ... },
  'result' => 'OK'
}
```

</details>

#### Transfer prüfen

`result` ist nur dann `'OK'`, wenn die Registry die Domain als transferierbar meldet.

```ruby
dna.check_transfer('example.com', 'Xy9#mK2$')
```

<details>
<summary>Beispielausgabe</summary>

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

#### Transfer abbrechen, genehmigen oder ablehnen

`cancel_transfer` bricht einen ausstehenden eingehenden Transfer ab; `approve_transfer` und `reject_transfer` beantworten einen ausstehenden ausgehenden Transfer.

```ruby
dna.cancel_transfer('example.com')
dna.approve_transfer('example.com')
dna.reject_transfer('example.com')
```

<details>
<summary>Beispielausgabe</summary>

```ruby
{ 'result' => 'OK', 'data' => { 'DomainName' => 'example.com', 'Status' => 'Cancelled' } } # 'Approved' / 'Rejected'
```

</details>

<hr style="border: 4px solid #000; border-style: dashed;">

### DNS-Zone

Unterstützte Record-Typen: `A`, `AAAA`, `ALIAS`, `CAA`, `CNAME`, `DS`, `MX`, `NAPTR`, `PTR`, `SRV`, `TLSA`, `TXT` (andere Typen werden noch vor jedem Aufruf abgelehnt). Namen sind relativ (`'www'`); `''` oder `'@'` steht für den Zonen-Apex, und ein vollständiger Name wie `'www.example.com'` wird auf sein Label gekürzt. Änderungen werden sofort angewendet; übergeben Sie `apply = false`, um mehrere Änderungen vorzumerken, und rufen Sie anschließend einmal `apply_resource_records` auf. Die TTL beträgt 1–86400 Sekunden.

Das Gateway speichert Name + Typ als ein **Set**: Das Schreiben eines Sets ersetzt alle seine Werte, und das Löschen eines Wertes löscht das gesamte Set. Die Methoden `*_resource_record_value` übernehmen das Lesen, Zusammenführen und Schreiben für Sie.

#### Records auflisten

```ruby
dna.get_resource_records('example.com')
```

<details>
<summary>Beispielausgabe</summary>

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

#### Ein Record-Set ersetzen

`set_resource_record_set(domain, name, type, contents, ttl = 3600, apply = true)` — eine leere Liste entfernt das Set.

```ruby
dna.set_resource_record_set('example.com', 'www', 'A', ['192.0.2.10', '192.0.2.11'], 3600)
```

<details>
<summary>Beispielausgabe</summary>

```ruby
{ 'result' => 'OK', 'data' => { 'Name' => 'www', 'Type' => 'A', 'TTL' => 3600, 'Contents' => ['192.0.2.10', '192.0.2.11'] } }
```

</details>

#### Einen Wert hinzufügen, ersetzen oder entfernen

`add_resource_record_value(domain, name, type, value, ttl = nil, apply = true)`, `replace_resource_record_value(domain, name, type, old_value, new_value, ttl = nil, apply = true)`, `remove_resource_record_value(domain, name, type, value, apply = true)`. Eine TTL von `nil` behält die aktuelle TTL des Sets bei; das Hinzufügen eines bereits vorhandenen Wertes oder das Entfernen eines nicht vorhandenen Wertes bewirkt nichts (`'Changed' => false`).

```ruby
dna.add_resource_record_value('example.com', '', 'MX', '10 mail.example.com.')
dna.replace_resource_record_value('example.com', '', 'MX', '10 mail.example.com.', '20 mail.example.com.')
dna.remove_resource_record_value('example.com', '', 'MX', '20 mail.example.com.')
```

<details>
<summary>Beispielausgabe</summary>

```ruby
{ 'result' => 'OK', 'data' => { 'Name' => '', 'Type' => 'MX', 'TTL' => 3600, 'Contents' => ['10 mail.example.com.'] } }
# Wert bereits vorhanden:
{ 'result' => 'OK', 'data' => { 'Name' => '', 'Type' => 'MX', 'Contents' => ['10 mail.example.com.'], 'Changed' => false } }
```

</details>

#### Ein Record-Set löschen

`delete_resource_record_set(domain, name, type, apply = true, known_value = '')` — entfernt alle Werte des Sets; gibt es nichts zu entfernen, ist das ein Erfolg mit `'Removed' => false`.

```ruby
dna.delete_resource_record_set('example.com', 'www', 'A')
```

<details>
<summary>Beispielausgabe</summary>

```ruby
{ 'result' => 'OK', 'data' => { 'Name' => 'www.example.com.', 'Type' => 'A', 'Content' => '192.0.2.10' } }
```

</details>

#### Low-Level-Record-Aufrufe

```ruby
dna.add_resource_record('example.com', 'www', 'A', '192.0.2.10', 3600, true)
dna.edit_resource_record('example.com', 'www', 'www', 'A', '192.0.2.20', 3600, true)
dna.delete_resource_record('example.com', 'www.example.com.', '192.0.2.20', 'A', true)
dna.apply_resource_records('example.com')
```

<details>
<summary>Beispielausgabe</summary>

```ruby
{ 'result' => 'OK', 'data' => { 'Name' => 'www', 'Type' => 'A', 'TTL' => 3600, 'Content' => '192.0.2.10' } }   # add / edit
{ 'result' => 'OK', 'data' => { 'Name' => 'www.example.com.', 'Type' => 'A', 'Content' => '192.0.2.20' } }    # delete
{ 'result' => 'OK', 'data' => { 'DomainName' => 'example.com' } }                                              # apply
```

</details>

<hr style="border: 4px solid #000; border-style: dashed;">

### URL-Weiterleitung

Weiterleitungstypen: `'Standard'` (einfache Umleitung) und `'Frame'` (maskiert).

```ruby
dna.set_forwarding('example.com', 'https://www.example.org', 'Standard')
dna.get_forwarding('example.com')
dna.delete_forwarding('example.com')
```

<details>
<summary>Beispielausgabe</summary>

```ruby
# set_forwarding
{ 'result' => 'OK', 'data' => { 'RedirectAddress' => 'https://www.example.org', 'ForwardType' => 'Standard' } }
# get_forwarding (ist nichts konfiguriert, ergibt das Enabled => false, keinen Fehler)
{ 'result' => 'OK', 'data' => { 'Enabled' => true, 'RedirectAddress' => 'https://www.example.org', 'ForwardType' => 'Standard' } }
# delete_forwarding
{ 'result' => 'OK', 'data' => { 'DomainName' => 'example.com' } }
```

</details>

<hr style="border: 4px solid #000; border-style: dashed;">

### Hilfsfunktionen (ohne Netzwerk)

#### Ist es eine .tr-Domain?

```ruby
dna.is_tr_tld('example.com.tr') # => true
dna.is_tr_tld('example.com')    # => false
```

#### Einen Kontakt validieren

Ergänzt und normalisiert einen Kontakt so, wie es die Registrierung tut: Ziffern und Satzzeichen werden aus Namen entfernt, ein fehlendes Bundesland wird durch die Stadt ersetzt, Ländernamen werden zu ISO-Codes und Telefonnummern werden in Nummer und Ländervorwahl aufgeteilt.

```ruby
dna.validate_contact('FirstName' => 'J0hn', 'Phone' => '+90 532 374 33 88', 'Country' => 'Turkey')
```

<details>
<summary>Beispielausgabe</summary>

```ruby
{
  'FirstName' => 'Jhn', 'Phone' => '5323743388', 'Country' => 'TR', 'LastName' => 'Isimyok',
  'AddressLine1' => 'Addres yok', 'City' => 'ISTANBUL', 'State' => 'ISTANBUL', 'ZipCode' => '34000',
  'PhoneCountryCode' => '90', 'Fax' => '', 'FaxCountryCode' => ''
}
```

</details>

<hr style="border: 4px solid #000; border-style: dashed;">

### Einstellungen

| Methode | Wirkung |
|---|---|
| `set_error_reporting_enabled(false)` | Telemetrie abschalten |
| `set_telemetry_minimal(true)` | Nur die minimale Telemetrie-Nutzlast senden |
| `set_ssl_verification(false)` | TLS-Zertifikatsprüfung überspringen (nicht empfohlen) |
| `set_service_url(url)` | Eine andere Gateway-URL verwenden |
| `set_transport(callable)` | Den HTTP-Transport ersetzen (siehe unten) |

Der HTTP-Transport ist ein beliebiges Objekt, das auf `call(request)` reagiert, wobei `request` ein Hash mit `:method`, `:url`, `:headers`, `:body`, `:timeout`, `:connect_timeout` und `:verify_ssl` ist, und das eine `DomainNameApi::Response` zurückgibt (oder einen Hash mit `:status`, `:body`, `:headers`). Standard ist `DomainNameApi::NetHttpTransport` (Net::HTTP). Auf diese Weise laufen die Tests ohne Netzwerk:

```ruby
fake = ->(request) { DomainNameApi::Response.new(status: 200, body: '{"resellerId":"abc"}', headers: {}) }
dna = DomainNameApi::Client.new(reseller_id, api_key, false, transport: fake)
```

<hr style="border: 4px solid #000; border-style: dashed;">

## Tests

Die Testsuite verwendet ausschließlich Minitest und greift nie auf das Netzwerk zu:

```bash
bundle install
bundle exec rake test
```

`test/conformance_test.rb` führt die 126 Konformitäts-Fixtures von php-dna aus (`test/fixtures/conformance/`): Für jedes Szenario werden die gesendeten Anfragen (Methode, Pfad, Query, JSON-Body, Auth-Header) und der Rückgabewert mit dem verglichen, was php-dna erzeugt hat. Die übrigen Tests decken die HTTP-Schicht, die Fehlerzuordnung, die Maskierung in der Telemetrie, den Net::HTTP-Transport und die Hilfsfunktionen ab.

<hr style="border: 4px solid #000; border-style: dashed;">

## Rückgabe- und Fehlercodes mit Erklärungen

| Code | Beschreibung                                        | Details                                                                                                                                                                  |
|------|-----------------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| 1000 | Befehl erfolgreich abgeschlossen                    | Operation erfolgreich.                                                                                                                                                   |
| 1001 | Befehl erfolgreich abgeschlossen; Aktion ausstehend | Operation erfolgreich. Der Vorgang wurde jedoch in die Warteschlange eingereiht.                                                                                         |
| 2003 | Erforderlicher Parameter fehlt                      | Parameterfehler. Zum Beispiel: Keine Telefonnummer in Kontaktinformationen angegeben.                                                                                    |
| 2105 | Objekt ist nicht für Verlängerung geeignet          | Domain-Status erlaubt keine Verlängerung, ist für Updates gesperrt. Status darf nicht "clientupdateprohibited" sein. Kann auch an anderen Statusbedingungen liegen.      |
| 2200 | Authentifizierungsfehler                            | Berechtigungsfehler, Sicherheitscode falsch oder Domain bei anderem Registrar.                                                                                           |
| 2302 | Objekt existiert bereits                            | Domain-Name oder Nameserver-Information existiert bereits in der Datenbank. Kann nicht registriert werden.                                                               |
| 2303 | Objekt existiert nicht                              | Domain-Name oder Nameserver-Information existiert nicht in der Datenbank. Muss neu erstellt werden.                                                                      |
| 2304 | Objektstatus verhindert Operation                   | Domain-Status erlaubt keine Aktualisierung, ist für Updates gesperrt. Status darf nicht "clientupdateprohibited" sein. Kann auch an anderen Statusbedingungen liegen.    |

| CODE | DETAIL                                                                                                                               |
|------|--------------------------------------------------------------------------------------------------------------------------------------|
| 101  | Systemfehler detailliert für ({0})!                                                                                                  |
| 102  | Mehrere Fehler detailliert für ({0})!                                                                                                |
| 103  | Unbekannte Fehler detailliert für ({0})!                                                                                             |
| 200  | API-Befehl nicht gefunden ({0})!                                                                                                     |
| 210  | API-Service nicht gefunden ({0})!                                                                                                    |
| 211  | API-Service-Provider nicht gesetzt!                                                                                                  |
| 300  | Reseller nicht gefunden!                                                                                                             |
| 301  | Ihre aktuelle IP-Adresse ist nicht für den Zugriff autorisiert. Stellen Sie sicher, dass Sie sich von einer autorisierten IP-Adresse verbinden und versuchen Sie es erneut |
| 310  | TLD wird nicht unterstützt!                                                                                                          |
| 320  | API nicht gefunden!                                                                                                                  |
| 321  | Währung wird nicht unterstützt!                                                                                                      |
| 330  | Erforderliche Parameter nicht gesetzt ({0}).                                                                                         |
| –    | Stellen Sie sicher, dass Sie alle Kontaktobjekte vollständig senden                                                                  |
| 340  | Preisdefinition nicht gefunden ({0}[{1}]-{2}{3}).                                                                                    |
| 350  | Unzureichendes Reseller-Guthaben. (Reseller Id : {0} - Aktuelles Guthaben : {1} {2}).                                                |
| 350  | Buchhaltungswährung stimmt nicht überein oder das Guthaben ist nicht ausreichend.                                                    |
| 360  | Ungültige API-Anfrage für Feld ({0}).                                                                                                |
| 360  | API-Quota überschritten!                                                                                                             |
| 361  | Drosselungsfehler!                                                                                                                   |
| 362  | Premium-Domain ist derzeit nicht für die Registrierung verfügbar.                                                                    |
| 363  | Operation abgebrochen, da sich die Domain in der automatischen Verlängerungsperiode befindet                                         |
| 364  | Diese Domain ist derzeit aufgrund eines Problems mit der Registry nicht für Transaktionen verfügbar                                  |

| CODE | DETAIL                                                                                      |
|------|---------------------------------------------------------------------------------------------|
| 400  | Ungültiger Kontakt ({0}).                                                                   |
| 401  | Kontaktinfo kann nicht synchronisiert werden.                                               |
| 402  | Kein Zugriff auf Kontaktinformationen von der Registry.                                     |
| 403  | DAS SYSTEM HAT FEHLENDE INFORMATIONEN. GEBEN SIE IHRE STANDARDINFORMATIONEN EIN ODER KONTAKTIEREN SIE DAS SUPPORT-TEAM. |
| 404  | DOMAIN-KONTAKT KANN NICHT AKTUALISIERT WERDEN. BERECHTIGUNG VON DER REGISTRY.               |
| 410  | Kontakt nicht gefunden.                                                                     |
| 410  | Kontakt nicht gefunden ({0}).                                                               |
| 420  | Ungültiger Api-Befehl für Kontakt {0}.                                                      |
| 430  | Kontakt-API nicht gefunden.                                                                 |
| 440  | Kontakt ist nicht synchronisiert.                                                           |
| 450  | Zu viele Domain-Kontakte!                                                                   |
| 451  | Kontaktaktualisierung konnte nicht fortgesetzt werden.                                      |

| CODE | DETAIL                                                                                                                               |
|------|--------------------------------------------------------------------------------------------------------------------------------------|
| 500  | Ungültige Domain-ID.                                                                                                                 |
| 500  | Ungültige Domain-ID ({0}).                                                                                                           |
| 501  | Domain konnte nicht synchronisiert werden({0})                                                                                       |
| 502  | Interner Transfer fehlgeschlagen                                                                                                     |
| 503  | Domain-Registrierung ist nicht verfügbar.                                                                                            |
| 504  | Domain-Informationen stimmen nicht überein. Vorher :{0}                                                                              |
| 505  | Geben Sie die IP-Adresse ein.                                                                                                        |
| 506  | Domain-Transfer wurde gestartet, aber Kontaktinfo konnte nicht gelesen werden.                                                       |
| 507  | Autorisierungsfehler.                                                                                                                |
| 510  | Domain nicht gefunden.                                                                                                               |
| 511  | Abgelaufene Domains können nicht gefunden werden.                                                                                    |
| 512  | Domain ist nicht verlängerbar.                                                                                                       |
| 513  | Domain ist nicht in aktualisierbarem Status. Sie muss aktiv sein, um aktualisiert zu werden                                          |
| 514  | Rücknahmeperiode erwartet.                                                                                                           |
| 520  | Ungültiger Api-Befehl für Domain "{0}".                                                                                              |
| 530  | Ungültige Domain-Periode. Periode muss {0} bis {1} Jahre betragen. Angeforderte Periode ist {2} Jahre.                               |
| 540  | Domain kann nicht über {0} Jahre vom aktuellen Datum hinaus verlängert werden.                                                       |
| 550  | Ungültiger Domain-Name. Domain muss {0} bis {1} Zeichen lang sein. Angeforderter Domain-Name ist {2} Zeichen.                        |
| 560  | Ungültige Nameserver-Anzahl. Domain muss {0} bis {1} Nameserver haben. Angeforderte Nameserver-Anzahl ist {2}.                       |
| 561  | Keine Nameserver-Informationen in der eingehenden Anfrage gefunden                                                                   |
| 570  | Idn nicht unterstützt für TLD "{0}".                                                                                                 |
| 571  | Periode ungültig.                                                                                                                    |
| 572  | Befehl ungültig.                                                                                                                     |
| 573  | Domain-Namen nicht gefunden.                                                                                                         |
| 574  | TLD-Namen nicht gefunden.                                                                                                            |
| 575  | Domain ist nicht in aktualisierbarem Status. Sie muss aktiv sein, damit Nameserver aktualisiert werden können                        |
| 576  | Domain kann im letzten Monat vor dem Ablaufdatum verlängert werden                                                                   |
| 580  | Transfer nicht unterstützt für TLD "{0}".                                                                                            |
| 581  | Child-Nameserver nicht gefunden                                                                                                      |
| 582  | Transfer von anderem Reseller gestartet.                                                                                             |
| 583  | Transfer nicht initialisiert. Bitte kontaktieren Sie das Support-Team.                                                               |
| 584  | Objektstatus verbietet Operation                                                                                                     |
| 590  | Auth-Code ist für diesen Transfer erforderlich.                                                                                      |
| 591  | Auth-Code ist nicht gültig.                                                                                                          |
| 592  | Transfer-Sperre existiert auf Domain.                                                                                                |
| 593  | Domain kann nicht transferiert werden, Statusinformationen und Transfer-Sperre müssen die erforderlichen Kriterien erfüllen. (Statusinformationen: #ok) |
| 594  | Domain-Nameserver-Adresse konnte nicht aufgelöst werden ({0})                                                                        |
| 595  | Kontaktinformationen können nicht gelesen werden (whois.registrar.tld) Stellen Sie sicher, dass der Datenschutzstatus offen ist      |
| 596  | Kontaktinformationen konnten nicht verifiziert werden                                                                                |
| 597  | TLD nicht gefunden                                                                                                                   |
| 598  | Unbekannter Fehler aufgetreten                                                                                                       |
| 599  | Domain-Weiterleitung nicht gefunden                                                                                                  |

## Lizenz

Apache License 2.0 — siehe [LICENSE](LICENSE).
