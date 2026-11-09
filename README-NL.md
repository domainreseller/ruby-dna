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

# ruby-dna — DomainNameAPI-client voor Ruby

Registreer, verleng en transfereer domeinen en beheer contacten, nameservers, child nameservers, DNS-zones en URL-doorsturing via de DomainNameAPI REST API. `ruby-dna` is een getrouwe port van [php-dna](https://github.com/domainreseller/php-dna): dezelfde methoden, dezelfde verzoeken over de lijn en dezelfde retourwaarden, geverifieerd aan de hand van de conformance-fixtures van php-dna.

## 📦 Downloaden — gebruik altijd de Releases!

⬇️ **Download hier de nieuwste geteste versie: https://github.com/domainreseller/ruby-dna/releases/latest**

> ⚠️ Gebruik **niet** de groene knop **Code → Download ZIP** — daarmee downloadt u de ruwe ontwikkelbranch. Release-pakketten zijn geversioneerd, getest en klaar voor productie.

## Installatie en Integratie Gids

### Minimale Vereisten

- Ruby 2.7 of hoger (Aanbevolen 3.3+)
- Geen runtime-afhankelijkheden: alleen de standaardbibliotheek (`net/http`, `json`, `openssl`).

### A) Bundler

```ruby
# Gemfile
gem 'domainnameapi', git: 'https://github.com/domainreseller/ruby-dna.git', tag: 'v1.0.0'
```

```bash
bundle install
```

### B) Gem-bestand uit de release

Download `domainnameapi-1.0.0.gem` uit de [nieuwste release](https://github.com/domainreseller/ruby-dna/releases/latest) en voer daarna uit:

```bash
gem install ./domainnameapi-1.0.0.gem
```

### C) Handmatig gebruik

Download het release-archief, kopieer de map `lib` naar uw project en bekijk de voorbeelden in de map [examples](examples):

```ruby
$LOAD_PATH.unshift File.expand_path('lib', __dir__)
require 'domainnameapi'
```

## 🔑 API-inloggegevens — Reseller ID en API Key

De bibliotheek communiceert met de DomainNameAPI REST API en heeft precies twee gegevens nodig, die aan de constructor worden meegegeven:

| Parameter | Waarde |
|---|---|
| Eerste | Reseller ID — UUID zoals `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx` |
| Tweede | API Key |

> 💡 U vindt uw **Reseller ID** en **API Key** in uw DomainNameAPI-panel onder **API-instellingen**.
> ⚠️ Dit zijn **API-inloggegevens** — de gegevens waarmee u op het panel inlogt, werken hier **niet**.

## Snel aan de slag

```ruby
require 'domainnameapi'

reseller_id = 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx'
api_key     = 'your-api-key'

# Live-omgeving
dna = DomainNameApi::Client.new(reseller_id, api_key)

# Testomgeving (OTE)
dna = DomainNameApi::Client.new(reseller_id, api_key, true)

result = dna.get_details('example.com')
if result['result'] == 'OK'
  puts result['data']['Dates']['Expiration']
else
  puts "#{result['error']['Code']}: #{result['error']['Message']}"
end
```

Methodenamen zijn de snake_case-vorm van die van php-dna (`getDetails` → `get_details`, `registerWithContactInfo` → `register_with_contact_info`), met dezelfde volgorde van parameters en dezelfde standaardwaarden. Resultaten zijn gewone Ruby-Hashes en -Arrays met **String-sleutels**, precies de structuur die php-dna teruggeeft (inclusief string-vlaggen zoals `'LockStatus' => 'true'` en opgemaakte prijzen zoals `'11.9900'`). Inloggegevens worden getrimd, en de testmodus-vlag accepteert ook strings: `"true"`, `"1"`, `"on"` en `"yes"` betekenen testmodus, al het andere betekent live.

## Foutafhandeling

Methoden genereren nooit een exception bij API- of netwerkproblemen. Een mislukte aanroep geeft een fout-envelop terug:

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

- `Code` is `API_<HTTP status>` voor gatewayfouten (`API_400`, `API_401`, `API_429`, `API_500`, ...). Een `301`/`302`-antwoord betekent ongeldige inloggegevens (`Invalid API credentials`).
- Wanneer de gateway een eigen foutcode meestuurt, bevat de envelop die ook als `GatewayCode` (bijv. `'GatewayCode' => 'Dna.DomainService:Domain:10007'`), zodat u de ene `API_404` van de andere kunt onderscheiden.
- Een lege foutbody wordt omgezet in een leesbare melding zoals `HTTP 429 - Too Many Requests`. Wanneer de melding van de gateway een standaardtekst is, wordt de ruwe antwoordbody nooit als melding gebruikt; in plaats daarvan wordt een vaste tekst gebruikt die de gatewaycode noemt.
- Validatiefouten van velden worden samengevoegd in `Details`, bijvoorbeeld `Admin PostalCode - 'PostalCode' is required`.
- Netwerkstoringen zijn fouten, nooit een leeg succes. Een time-out luidt `Could not reach the DomainNameAPI service: the connection timed out. (...)`; andere transportfouten luiden `Curl error during request: ...`. Hun codes zijn `CURL_<n>` met de nummers van curl (`CURL_28` time-out, `CURL_6` DNS, `CURL_7` verbinding geweigerd, `CURL_35`/`CURL_60` TLS, `CURL_56` reset); `API_<n>` is gereserveerd voor HTTP-statussen.
- Een registratie, transfer of verlenging die de gateway beantwoordt met HTTP 200 maar `"success": false` is een weigering, geen succes: de methode geeft de fout-envelop terug met code `REGISTER_DOMAIN`, `TRANSFER_DOMAIN` of `RENEW_DOMAIN` en de melding van de gateway.
- `get_current_balance` behoudt zijn eigen envelop: `'OperationResult' => 'FAILED'` met `ErrorCode` en `OperationMessage`.
- `check_availability` geeft bij succes een gewone lijst terug en bij een fout de fout-envelop.

Alleen programmeerfouten genereren een exception (bijvoorbeeld `set_resource_record_set` met `contents` die geen lijst is, genereert `TypeError`).

Time-outs zijn 30 seconden per aanroep en 10 seconden voor het opzetten van de verbinding. Aanroepen naar de DNS-zone-endpoints worden minstens één seconde uit elkaar gehouden, omdat de gateway op een stoot verzoeken antwoordt met `HTTP 429`.

### Diagnostiek

```ruby
dna.get_request_data         # { 'url' => ..., 'method' => 'GET', 'payload' => {...} } van de laatste aanroep
dna.get_response_data        # laatst gedecodeerde antwoordbody (of { 'raw_response' => body })
dna.get_response_headers     # { 'url', 'http_code', 'headers', 'total_time' }
dna.get_parsed_response_data # laatst geparste body, of de laatste fout { 'Code', 'Message', 'Details' }
dna.get_last_function        # bijv. 'request:GET domains/info'
dna.get_service_url          # https://api.domainresellerapi.com/api/v1
dna.set_service_url('https://ote.domainresellerapi.com/api/v1')
```

## Testmodus

Geef `true` mee als derde constructorargument om de OTE-testgateway te gebruiken (`https://ote.domainresellerapi.com/api/v1`). Live-aanroepen gaan naar `https://api.domainresellerapi.com/api/v1`. De testmodus gebruikt aparte test-inloggegevens.

## Foutrapportage (telemetrie)

Wanneer een API-aanroep mislukt, kan de bibliotheek een foutrapport sturen naar de eigen fouttracker van DomainNameAPI (Sentry). Een klein, willekeurig deel van de geslaagde aanroepen (4%, plus elke aanroep die langer dan 1 seconde duurt) kan als prestatiegegeven worden verstuurd. Dit helpt DomainNameAPI problemen te vinden en op te lossen. Foutrapportage staat **standaard aan**.

> ℹ️ In versie 1.0.0 bestaat het Sentry-project voor ruby-dna nog niet; de ingebouwde DSN is daarom leeg en er wordt **niets verstuurd**. Rapporten worden pas verstuurd zodra een release de DSN meelevert. Met `DomainNameApi::Client.new(id, key, false, sentry_dsn: '...')` stelt u er expliciet een in.

**Wat wordt verstuurd:**

- foutcode en -melding
- pad van het aangeroepen endpoint en HTTP-methode
- duur van de aanroep
- bibliotheeknaam (`DomainNameAPI-Ruby`), bibliotheekversie en Ruby-versie
- reseller-ID en domeinnaam
- het publieke IP-adres van de server (op de achtergrond opgevraagd via `api.ipify.org`)
- de gebruikersnaam van het besturingssysteem waaronder het proces draait
- het API-verzoek en -antwoord, inclusief de contactgegevens van het domein; alleen inloggegevens worden gemaskeerd — EPP-/auth-codes, API-keys, wachtwoorden en tokens worden vervangen door `***`

**Wat nooit wordt verstuurd:** EPP-/auth-codes, API-keys, wachtwoorden of tokens in leesbare vorm; methodeargumenten in stacktraces.

Verwachte fouten die veel voorkomen (domein niet gevonden, onvoldoende saldo, ongeldige inloggegevens, ...) worden niet gerapporteerd. Rapporten worden vanuit een achtergrondthread met korte time-outs verstuurd: ze vertragen of verstoren uw aanroep nooit.

**Waarom en hoe lang:** de gegevens worden alleen gebruikt voor gebruiksmeting en het vroegtijdig opsporen van problemen, en worden 30 dagen bewaard op de eigen Sentry-server van DomainNameAPI, waarna ze automatisch worden verwijderd.

**Uitschakelen:**

```ruby
dna = DomainNameApi::Client.new(reseller_id, api_key)
dna.set_error_reporting_enabled(false)
```

**Minimale modus** verstuurt alleen de foutcode en -melding, het endpoint, de duur, de versies en de reseller-ID — geen verzoek-/antwoordgegevens, domein, server-IP of gebruikersnaam:

```ruby
dna.set_telemetry_minimal(true)
```

> 🔒 **Beveiliging:** TLS-certificaatverificatie staat aan. Op een server met een verouderde CA-bundle kan deze worden uitgeschakeld met `dna.set_ssl_verification(false)` — niet aanbevolen; de CA-bundle bijwerken is de betere oplossing.

## Gebruik

Alle voorbeelden gaan uit van `dna = DomainNameApi::Client.new(reseller_id, api_key)`. Uitvoerbare scripts voor elke methode staan in [examples](examples).

### Account

#### Reseller-details

```ruby
dna.get_reseller_details
```

<details>
<summary>Voorbeelduitvoer</summary>

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

#### Huidig saldo

`get_current_balance(currency = 'USD')` — het account rapporteert saldi in `'USD'` en `'TRY'`. Voor elke andere valuta (`'EUR'`, `'GBP'`, ...) mislukt de aanroep met `'ErrorCode' => 'BALANCE'` in plaats van `0.00` terug te geven.

```ruby
dna.get_current_balance('USD')
```

<details>
<summary>Voorbeelduitvoer</summary>

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

### Zoeken en lijsten

#### Beschikbaarheid van domeinen controleren

`check_availability(domains, extensions, period, command = 'create')` — `DomainName` in het resultaat is de naam zonder de afsluitende `.tld`.

```ruby
dna.check_availability(['hello', 'world123x0'], ['com', 'net'], 1, 'create')
```

<details>
<summary>Voorbeelduitvoer</summary>

```ruby
[
  { 'TLD' => 'com', 'DomainName' => 'hello', 'Status' => 'notavailable', 'Command' => 'create',
    'Period' => 1, 'IsFee' => false, 'Price' => '10.8100', 'Currency' => 'USD', 'Reason' => 'Domain exists' },
  { 'TLD' => 'com', 'DomainName' => 'world123x0', 'Status' => 'available', 'Command' => 'create',
    'Period' => 1, 'IsFee' => false, 'Price' => '10.8100', 'Currency' => 'USD', 'Reason' => nil }
]
```

</details>

#### Domeinlijst

`get_list(extra_parameters = {})` — `PageNumber` (vanaf 0), `PageSize`, `OrderColumn`, `OrderDirection` en de eigen filters van de gateway (bijv. `DomainName`).

```ruby
dna.get_list('OrderColumn' => 'Id', 'OrderDirection' => 'ASC', 'PageNumber' => 0, 'PageSize' => 1000)
```

<details>
<summary>Voorbeelduitvoer</summary>

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

#### TLD-lijst

`get_tld_list(count = 20)`

```ruby
dna.get_tld_list(100)
```

<details>
<summary>Voorbeelduitvoer</summary>

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

### Domein

#### Domeinregistratie

`register_with_contact_info(domain, period, contacts, name_servers = [], epp_lock = true, privacy_lock = false, additional_attributes = {})`

Contacten gebruiken de sleutels van php-dna. Zowel de platte vorm hieronder als de geneste vorm die `get_contacts` teruggeeft (`Address => { Line1, City, ... }`, `Phone => { Phone => { Number, CountryCode } }`) worden geaccepteerd; ontbrekende velden worden aangevuld en namen, telefoonnummers en landen worden genormaliseerd (zie `validate_contact`). Zonder nameservers worden `ns1.domainnameapi.com` en `ns2.domainnameapi.com` gebruikt.

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

Geef voor `.tr`-domeinen de TRABIS-attributen mee als 7e argument:

```ruby
# Particuliere eigenaar
{ 'TRABISDOMAINCATEGORY' => 1, 'TRABISCITIZIENID' => '12345678901' }
# Zakelijke eigenaar
{ 'TRABISDOMAINCATEGORY' => 0, 'TRABISTAXOFFICE' => 'Istanbul VD', 'TRABISTAXNUMBER' => '1234567890' }
```

De categorie wordt verstuurd als `Owner`/`Corporate`, `TRABISCITIZIENID` als `TRABISCITIZENID`, en verouderde sleutels (`TRABISNAMESURNAME`, `TRABISCOUNTRYID`, `TRABISCITYID`, ...) worden weggelaten, omdat de gateway deze nu uit het contact leest.

<details>
<summary>Voorbeelduitvoer</summary>

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

#### Domeinverlenging

```ruby
dna.renew('example.com', 1)
```

<details>
<summary>Voorbeelduitvoer</summary>

```ruby
{ 'result' => 'OK', 'data' => { 'ExpirationDate' => '2025-03-15T10:00:00' } }
```

</details>

#### Domeininformatie

```ruby
dna.get_details('example.com')
```

<details>
<summary>Voorbeelduitvoer</summary>

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

#### Synchroniseren vanuit het register

Dezelfde aanroep en uitvoer als `get_details`.

```ruby
dna.sync_from_registry('example.com')
```

#### Nameservers wijzigen

Geef een lijst of een Hash mee (de waarden worden gebruikt). Namen worden getrimd, naar kleine letters omgezet, van een afsluitende punt ontdaan en ontdubbeld; het resultaat toont die genormaliseerde lijst.

```ruby
dna.modify_name_server('example.com', ['ns1.example.com', 'ns2.example.com'])
```

<details>
<summary>Voorbeelduitvoer</summary>

```ruby
{ 'result' => 'OK', 'data' => { 'NameServers' => ['ns1.example.com', 'ns2.example.com'] } }
```

</details>

#### Domeinvergrendeling inschakelen

```ruby
dna.enable_theft_protection_lock('example.com')
```

<details>
<summary>Voorbeelduitvoer</summary>

```ruby
{ 'result' => 'OK', 'data' => { 'LockStatus' => true } }
```

</details>

#### Domeinvergrendeling uitschakelen

```ruby
dna.disable_theft_protection_lock('example.com')
```

<details>
<summary>Voorbeelduitvoer</summary>

```ruby
{ 'result' => 'OK', 'data' => { 'LockStatus' => false } }
```

</details>

#### Domeinprivacy wijzigen

`modify_privacy_protection_status(domain, status, reason = 'Owner request')` — `status` mag `true`/`false` zijn of een waarde in panelstijl: `1`, `'1'`, `'true'`, `'on'` en `'yes'` schakelen privacy in, al het andere schakelt het uit. Het resultaat toont de geparste boolean. `reason` wordt voor compatibiliteit geaccepteerd maar niet verstuurd: de gateway kent zo'n veld niet.

```ruby
dna.modify_privacy_protection_status('example.com', true, 'Owner request')
```

<details>
<summary>Voorbeelduitvoer</summary>

```ruby
{ 'data' => { 'PrivacyProtectionStatus' => true }, 'result' => 'OK' }
```

</details>

#### Domeincontacten ophalen

Contacttypes worden hoofdletterongevoelig herkend (`admin`/`administrative`, `tech`/`technical`, `registrant`/`owner`, `billing`); andere types die het register teruggeeft, blijven behouden na de vier standaardtypes.

```ruby
dna.get_contacts('example.com')
```

<details>
<summary>Voorbeelduitvoer</summary>

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
      # elk ander contacttype dat het register teruggeeft, volgt na deze vier
    }
  },
  'result' => 'OK'
}
```

</details>

#### Domeincontacten opslaan

```ruby
dna.save_contacts('example.com', {
  'Administrative' => contact,
  'Billing'        => contact,
  'Technical'      => contact,
  'Registrant'     => contact
})
```

<details>
<summary>Voorbeelduitvoer</summary>

```ruby
{ 'result' => 'OK', 'data' => { 'contacts' => {} } }
```

</details>

<hr style="border: 4px solid #000; border-style: dashed;">

### Child nameservers

#### Child nameserver toevoegen

```ruby
dna.add_child_name_server('example.com', 'ns1.example.com', '1.2.3.4')
```

<details>
<summary>Voorbeelduitvoer</summary>

```ruby
{ 'result' => 'OK', 'data' => { 'NameServer' => 'ns1.example.com', 'IPAdresses' => ['1.2.3.4'] } }
```

</details>

#### Child nameserver verwijderen

```ruby
dna.delete_child_name_server('example.com', 'ns1.example.com')
```

<details>
<summary>Voorbeelduitvoer</summary>

```ruby
{ 'result' => 'OK', 'data' => { 'NameServer' => 'ns1.example.com' } }
```

</details>

#### Child nameserver bijwerken

```ruby
dna.modify_child_name_server('example.com', 'ns1.example.com', '1.2.3.5')
```

<details>
<summary>Voorbeelduitvoer</summary>

```ruby
{ 'result' => 'OK', 'data' => { 'NameServer' => 'ns1.example.com', 'IPAdresses' => ['1.2.3.5'] } }
```

</details>

<hr style="border: 4px solid #000; border-style: dashed;">

### Transfers

#### Domeintransfer

`transfer(domain, epp_code, period)` — een transfer verstuurt nooit contacten: de registrar regelt die, dus het verzoek bevat altijd een lege contactlijst en de methode heeft geen contactenargument. Werk de contacten bij met `save_contacts` zodra de transfer is voltooid.

```ruby
dna.transfer('example.com', 'Xy9#mK2$', 3)
```

<details>
<summary>Voorbeelduitvoer</summary>

```ruby
{
  'data' => { 'ID' => 0, 'Status' => 'WaitingForIncomingTransfer', 'DomainName' => 'example.com', ... },
  'result' => 'OK'
}
```

</details>

#### Transfer controleren

`result` is alleen `'OK'` wanneer het register meldt dat het domein transfereerbaar is.

```ruby
dna.check_transfer('example.com', 'Xy9#mK2$')
```

<details>
<summary>Voorbeelduitvoer</summary>

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

#### Een transfer annuleren, goedkeuren of afwijzen

`cancel_transfer` annuleert een lopende inkomende transfer; `approve_transfer` en `reject_transfer` beantwoorden een lopende uitgaande transfer.

```ruby
dna.cancel_transfer('example.com')
dna.approve_transfer('example.com')
dna.reject_transfer('example.com')
```

<details>
<summary>Voorbeelduitvoer</summary>

```ruby
{ 'result' => 'OK', 'data' => { 'DomainName' => 'example.com', 'Status' => 'Cancelled' } } # 'Approved' / 'Rejected'
```

</details>

<hr style="border: 4px solid #000; border-style: dashed;">

### DNS-zone

Ondersteunde recordtypes: `A`, `AAAA`, `ALIAS`, `CAA`, `CNAME`, `DS`, `MX`, `NAPTR`, `PTR`, `SRV`, `TLSA`, `TXT` (andere types worden geweigerd voordat er een aanroep plaatsvindt). Namen zijn relatief (`'www'`); `''` of `'@'` is de apex van de zone, en een volledige naam zoals `'www.example.com'` wordt teruggebracht tot het label. Wijzigingen worden direct toegepast; geef `apply = false` mee om er meerdere klaar te zetten en roep daarna eenmaal `apply_resource_records` aan. De TTL is 1–86400 seconden.

Als het automatische toepassen mislukt, geeft de methode de fout van het toepassen terug (de wijziging blijft klaargezet, niet live) in plaats van `OK`. Het resultaat toont het in hoofdletters omgezette type en de TTL die daadwerkelijk zijn verstuurd.

De gateway slaat een naam + type op als één **set**: het schrijven van een set vervangt al zijn waarden, en het verwijderen van één waarde verwijdert de hele set. De `*_resource_record_value`-methoden voeren het lezen-samenvoegen-schrijven voor u uit.

#### Records weergeven

```ruby
dna.get_resource_records('example.com')
```

<details>
<summary>Voorbeelduitvoer</summary>

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

#### Een recordset vervangen

`set_resource_record_set(domain, name, type, contents, ttl = 3600, apply = true)` — een lege lijst verwijdert de set.

```ruby
dna.set_resource_record_set('example.com', 'www', 'A', ['192.0.2.10', '192.0.2.11'], 3600)
```

<details>
<summary>Voorbeelduitvoer</summary>

```ruby
{ 'result' => 'OK', 'data' => { 'Name' => 'www', 'Type' => 'A', 'TTL' => 3600, 'Contents' => ['192.0.2.10', '192.0.2.11'] } }
```

</details>

#### Eén waarde toevoegen, vervangen of verwijderen

`add_resource_record_value(domain, name, type, value, ttl = nil, apply = true)`, `replace_resource_record_value(domain, name, type, old_value, new_value, ttl = nil, apply = true)`, `remove_resource_record_value(domain, name, type, value, apply = true)`. Een `nil`-TTL behoudt de huidige TTL van de set; een waarde toevoegen die al bestaat of een waarde verwijderen die niet bestaat, heeft geen effect (`'Changed' => false`).

```ruby
dna.add_resource_record_value('example.com', '', 'MX', '10 mail.example.com.')
dna.replace_resource_record_value('example.com', '', 'MX', '10 mail.example.com.', '20 mail.example.com.')
dna.remove_resource_record_value('example.com', '', 'MX', '20 mail.example.com.')
```

<details>
<summary>Voorbeelduitvoer</summary>

```ruby
{ 'result' => 'OK', 'data' => { 'Name' => '', 'Type' => 'MX', 'TTL' => 3600, 'Contents' => ['10 mail.example.com.'] } }
# waarde bestaat al:
{ 'result' => 'OK', 'data' => { 'Name' => '', 'Type' => 'MX', 'Contents' => ['10 mail.example.com.'], 'Changed' => false } }
```

</details>

#### Een recordset verwijderen

`delete_resource_record_set(domain, name, type, apply = true, known_value = '')` — verwijdert elke waarde van de set; als er niets te verwijderen is, is dat een succes met `'Removed' => false`.

```ruby
dna.delete_resource_record_set('example.com', 'www', 'A')
```

<details>
<summary>Voorbeelduitvoer</summary>

```ruby
{ 'result' => 'OK', 'data' => { 'Name' => 'www.example.com.', 'Type' => 'A', 'Content' => '192.0.2.10' } }
```

</details>

#### Low-level record-aanroepen

```ruby
dna.add_resource_record('example.com', 'www', 'A', '192.0.2.10', 3600, true)
dna.edit_resource_record('example.com', 'www', 'www', 'A', '192.0.2.20', 3600, true)
dna.delete_resource_record('example.com', 'www.example.com.', '192.0.2.20', 'A', true)
dna.apply_resource_records('example.com')
```

<details>
<summary>Voorbeelduitvoer</summary>

```ruby
{ 'result' => 'OK', 'data' => { 'Name' => 'www', 'Type' => 'A', 'TTL' => 3600, 'Content' => '192.0.2.10' } }   # toevoegen / bewerken
{ 'result' => 'OK', 'data' => { 'Name' => 'www.example.com.', 'Type' => 'A', 'Content' => '192.0.2.20' } }    # verwijderen
{ 'result' => 'OK', 'data' => { 'DomainName' => 'example.com' } }                                              # toepassen
```

</details>

<hr style="border: 4px solid #000; border-style: dashed;">

### URL-doorsturing

Doorstuurtypes: `'Standard'` (gewone omleiding) en `'Frame'` (gemaskeerd). De gateway antwoordt `Redirect information not found` wanneer er niets is ingesteld: `get_forwarding` meldt dan `'Enabled' => false` en `delete_forwarding` slaagt met `'Removed' => false`. Elke andere fout, zoals een onbekend domein, wordt als fout teruggegeven.

```ruby
dna.set_forwarding('example.com', 'https://www.example.org', 'Standard')
dna.get_forwarding('example.com')
dna.delete_forwarding('example.com')
```

<details>
<summary>Voorbeelduitvoer</summary>

```ruby
# set_forwarding
{ 'result' => 'OK', 'data' => { 'RedirectAddress' => 'https://www.example.org', 'ForwardType' => 'Standard' } }
# get_forwarding (als er niets is ingesteld, geeft dit Enabled => false, geen fout)
{ 'result' => 'OK', 'data' => { 'Enabled' => true, 'RedirectAddress' => 'https://www.example.org', 'ForwardType' => 'Standard' } }
# delete_forwarding (Removed => false als er niets was ingesteld)
{ 'result' => 'OK', 'data' => { 'DomainName' => 'example.com', 'Removed' => true } }
```

</details>

<hr style="border: 4px solid #000; border-style: dashed;">

### Hulpfuncties (zonder netwerk)

#### Is het een .tr-domein?

```ruby
dna.is_tr_tld('example.com.tr') # => true
dna.is_tr_tld('example.com')    # => false
```

#### Een contact valideren

Vult een contact aan en normaliseert het op dezelfde manier als bij registratie: cijfers en leestekens worden uit namen verwijderd, een ontbrekende provincie/staat wordt de stad, landnamen worden ISO-codes en telefoonnummers worden gesplitst in nummer en landcode. Een nummer dat met een eigen landnummer (`+` of `00`) is geschreven, behoudt dat landnummer, ook wanneer een andere `PhoneCountryCode` is opgegeven (`'+1 202 555 0100'` → `'2025550100'` / `'1'`).

```ruby
dna.validate_contact('FirstName' => 'J0hn', 'Phone' => '+90 532 374 33 88', 'Country' => 'Turkey')
```

<details>
<summary>Voorbeelduitvoer</summary>

```ruby
{
  'FirstName' => 'Jhn', 'Phone' => '5323743388', 'Country' => 'TR', 'LastName' => 'Isimyok',
  'AddressLine1' => 'Addres yok', 'City' => 'ISTANBUL', 'State' => 'ISTANBUL', 'ZipCode' => '34000',
  'PhoneCountryCode' => '90', 'Fax' => '', 'FaxCountryCode' => ''
}
```

</details>

<hr style="border: 4px solid #000; border-style: dashed;">

### Instellingen

| Methode | Effect |
|---|---|
| `set_error_reporting_enabled(false)` | Telemetrie uitschakelen |
| `set_telemetry_minimal(true)` | De minimale telemetrie-payload versturen |
| `set_ssl_verification(false)` | TLS-certificaatverificatie overslaan (niet aanbevolen) |
| `set_service_url(url)` | Een andere gateway-URL gebruiken |
| `set_transport(callable)` | Het HTTP-transport vervangen (zie hieronder) |

Het HTTP-transport is elk object dat reageert op `call(request)`, waarbij `request` een Hash is met `:method`, `:url`, `:headers`, `:body`, `:timeout`, `:connect_timeout` en `:verify_ssl`, en dat een `DomainNameApi::Response` teruggeeft (of een Hash met `:status`, `:body`, `:headers`). De standaard is `DomainNameApi::NetHttpTransport` (Net::HTTP). Zo draaien de tests zonder netwerk:

```ruby
fake = ->(request) { DomainNameApi::Response.new(status: 200, body: '{"resellerId":"abc"}', headers: {}) }
dna = DomainNameApi::Client.new(reseller_id, api_key, false, transport: fake)
```

<hr style="border: 4px solid #000; border-style: dashed;">

## Tests

De testsuite gebruikt alleen Minitest en maakt nooit gebruik van het netwerk:

```bash
bundle install
bundle exec rake test
```

`test/conformance_test.rb` draait de 126 conformance-fixtures van php-dna (`test/fixtures/conformance/`): voor elk scenario worden de verstuurde verzoeken (methode, pad, query, JSON-body, authenticatieheaders) en de retourwaarde vergeleken met wat php-dna produceerde. De overige tests dekken de HTTP-laag, de foutmapping, het maskeren in de telemetrie, het Net::HTTP-transport en de hulpfuncties.

<hr style="border: 4px solid #000; border-style: dashed;">

## Return en Foutcodes met Beschrijvingen

| Code | Beschrijving | Detail |
|------|-------------|--------|
| 1000 | Commando succesvol voltooid | Operatie succesvol. |
| 1001 | Commando succesvol voltooid; actie in behandeling | Operatie succesvol. De operatie is echter momenteel in de wachtrij geplaatst voor voltooiing. |
| 2003 | Vereiste parameter ontbreekt | Parameter ontbreekt error. Bijvoorbeeld: geen telefoon invoer in contactinformatie. |
| 2105 | Object komt niet in aanmerking voor verlenging | Domeinstatus is niet geschikt voor verlenging, vergrendeld voor update operaties. Status mag niet "clientupdateprohibited" zijn. Kan te wijten zijn aan andere statusvoorwaarden. |
| 2200 | Authenticatiefout | Autorisatiefout, beveiligingscode is onjuist of domein is geregistreerd bij een andere registrar. |
| 2302 | Object bestaat | Domeinnaam of nameserver informatie bestaat al in database. Kan niet geregistreerd worden. |
| 2303 | Object bestaat niet | Domeinnaam of nameserver informatie bestaat niet in database. Nieuwe registratie vereist. |
| 2304 | Objectstatus verbiedt operatie | Domeinstatus is niet geschikt voor updates, vergrendeld voor update operaties. Status mag niet "clientupdateprohibited" zijn. Kan te wijten zijn aan andere statusvoorwaarden. |

| CODE | DETAIL |
|------|--------|
| 101 | Systeemfout gedetailleerd voor ({0})! |
| 102 | Meerdere fouten gedetailleerd voor ({0})! |
| 103 | Onbekende fouten gedetailleerd voor ({0})! |
| 200 | API commando niet gevonden ({0})! |
| 210 | API service niet gevonden ({0})! |
| 211 | API service provider niet ingesteld! |
| 300 | Reseller niet gevonden! |
| 301 | Uw huidige IP-adres is niet geautoriseerd voor toegang. Zorg ervoor dat u verbinding maakt vanaf een geautoriseerd IP-adres en probeer opnieuw |
| 310 | TLD wordt niet ondersteund! |
| 320 | API niet gevonden! |
| 321 | Valuta wordt niet ondersteund! |
| 330 | Vereiste parameter(s) niet ingesteld ({0}). |
| – | Zorg ervoor dat u alle contactobjecten volledig verzendt |
| 340 | Prijsdefinitie niet gevonden ({0}[{1}]-{2}{3}). |
| 350 | Onvoldoende reseller saldo. (Reseller Id : {0} - Huidig Saldo : {1} {2}). |
| 350 | Boekhoudvaluta komt niet overeen of het saldo is niet voldoende. |
| 360 | Ongeldige API aanvraag voor veld ({0}). |
| 360 | API quota overschreden! |
| 361 | Throttled error! |
| 362 | Premium domein is momenteel niet beschikbaar voor registratie. |
| 363 | Operatie geannuleerd omdat domein in auto-vernieuwingsperiode is |
| 364 | Dit domein is momenteel niet beschikbaar voor transactie vanwege een probleem met het register |

| CODE | DETAIL |
|------|--------|
| 400 | Ongeldig contact ({0}). |
| 401 | Contactinfo kan niet synchroniseren. |
| 402 | Geen toegang tot contactinformatie van register. |
| 403 | HET SYSTEEM HEEFT ONTBREKENDE INFORMATIE. VOER UW STANDAARDINFORMATIE IN OF NEEM CONTACT OP MET HET ONDERSTEUNINGSTEAM. |
| 404 | DOMEINCONTACT KAN NIET WORDEN BIJGEWERKT. TOESTEMMING VAN HET REGISTER. |
| 410 | Contact niet gevonden. |
| 410 | Contact niet gevonden ({0}). |
| 420 | Ongeldig Api commando voor contact {0}. |
| 430 | Contact api niet gevonden. |
| 440 | Contact is niet gesynchroniseerd. |
| 450 | Te veel domeincontacten! |
| 451 | Kon niet doorgaan met contact update. |

| CODE | DETAIL |
|------|--------|
| 500 | Ongeldig domein id. |
| 500 | Ongeldig domein id ({0}). |
| 501 | Domein kon niet worden gesynchroniseerd({0}) |
| 502 | Interne transfer mislukt |
| 503 | Domeinregistratie is niet beschikbaar. |
| 504 | Domeininformatie komt niet overeen. Voor :{0} |
| 505 | Voer het IP-adres in. |
| 506 | Domeintransfer is gestart maar contactinfo kon niet worden gelezen. |
| 507 | Autorisatiefout. |
| 510 | Domein niet gevonden. |
| 511 | Verlopen domeinen kunnen niet worden gevonden. |
| 512 | Domein is niet verlengbaar. |
| 513 | Domein is niet in updatebare status. Het moet actief zijn om te worden bijgewerkt |
| 514 | Redemption Period verwacht. |
| 520 | Ongeldig Api commando voor domein "{0}". |
| 530 | Ongeldige domeinperiode. Periode moet {0} tot {1} jaar zijn. Gevraagde periode is {2} jaar. |
| 540 | Domein kan niet worden verlengd tot meer dan {0} jaar vanaf huidige datum. |
| 550 | Ongeldige domeinnaam. Domein moet {0} tot {1} karakters lang zijn. Gevraagde domeinnaam is {2} karakters. |
| 560 | Ongeldig nameserver aantal. Domein moet {0} tot {1} nameservers hebben. Gevraagd nameserver aantal is {2}. |
| 561 | Geen nameserver informatie gevonden in de binnenkomende aanvraag |
| 570 | Idn niet ondersteund voor tld "{0}". |
| 571 | Periode ongeldig. |
| 572 | Commando ongeldig. |
| 573 | Domeinnamen niet gevonden. |
| 574 | TLD namen niet gevonden. |
| 575 | Domein is niet in updatebare status. Het moet actief zijn voor nameservers om te worden bijgewerkt |
| 576 | Domein kan worden vernieuwd in de laatste 1 maand voor de vervaldatum |
| 580 | Transfer niet ondersteund voor tld "{0}". |
| 581 | Child nameserver niet gevonden |
| 582 | Transfer gestart door andere reseller. |
| 583 | Transfer niet geïnitialiseerd. Neem contact op met het ondersteuningsteam. |
| 584 | Objectstatus verbiedt operatie |
| 590 | Auth code is vereist voor deze transfer. |
| 591 | Auth code is niet geldig. |
| 592 | Transfer lock bestaat op domein. |
| 593 | Domein kan niet worden getransfereerd, Statusinformatie en Transfer Lock moeten voldoen aan de vereiste criteria. (Statusinformatie: #ok) |
| 594 | Domein nameserver adres kon niet worden opgelost ({0}) |
| 595 | Contactinformatie kan niet worden gelezen (whois.registrar.tld) Zorg ervoor dat privacy bescherming status open is |
| 596 | Contactinformatie kon niet worden geverifieerd |
| 597 | Tld niet gevonden |
| 598 | Onbekende fout opgetreden |
| 599 | Domein Forward niet gevonden |

## Licentie

Apache License 2.0 — zie [LICENSE](LICENSE).
