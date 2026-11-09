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

# ruby-dna — Client DomainNameAPI per Ruby

Registra, rinnova e trasferisci domini, gestisci contatti, name server, child name server, zone DNS e inoltro URL tramite l'API REST di DomainNameAPI. `ruby-dna` è un porting fedele di [php-dna](https://github.com/domainreseller/php-dna): gli stessi metodi, le stesse richieste in rete e gli stessi valori di ritorno, verificati con le fixture di conformità di php-dna.

## 📦 Download — usa sempre le Releases!

⬇️ **Scarica qui l'ultima versione testata: https://github.com/domainreseller/ruby-dna/releases/latest**

> ⚠️ **Non** usare il pulsante verde **Code → Download ZIP** — scarica il ramo di sviluppo grezzo. I pacchetti di release sono versionati, testati e pronti per la produzione.

## Guida all'Installazione e Integrazione

### Requisiti Minimi

- Ruby 2.7 o superiore (Raccomandato 3.3+)
- Nessuna dipendenza a runtime: solo la libreria standard (`net/http`, `json`, `openssl`).

### A) Bundler

```ruby
# Gemfile
gem 'domainnameapi', git: 'https://github.com/domainreseller/ruby-dna.git', tag: 'v1.0.0'
```

```bash
bundle install
```

### B) File gem dalla release

Scarica `domainnameapi-1.0.0.gem` dall'[ultima release](https://github.com/domainreseller/ruby-dna/releases/latest), poi:

```bash
gem install ./domainnameapi-1.0.0.gem
```

### C) Utilizzo manuale

Scarica l'archivio della release, copia la cartella `lib` nel tuo progetto ed esamina gli esempi nella cartella [examples](examples):

```ruby
$LOAD_PATH.unshift File.expand_path('lib', __dir__)
require 'domainnameapi'
```

## 🔑 Credenziali API — Reseller ID e API Key

La libreria comunica con l'API REST di DomainNameAPI e richiede esattamente due credenziali, passate al costruttore:

| Parametro | Valore |
|---|---|
| Primo | Reseller ID — UUID come `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx` |
| Secondo | API Key |

> 💡 Trovi il tuo **Reseller ID** e la tua **API Key** nel pannello DomainNameAPI, sotto **Impostazioni API**.
> ⚠️ Queste sono **credenziali API** — i dati di accesso al pannello **non funzioneranno** qui.

## Avvio rapido

```ruby
require 'domainnameapi'

reseller_id = 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx'
api_key     = 'your-api-key'

# Ambiente live
dna = DomainNameApi::Client.new(reseller_id, api_key)

# Ambiente di test (OTE)
dna = DomainNameApi::Client.new(reseller_id, api_key, true)

result = dna.get_details('example.com')
if result['result'] == 'OK'
  puts result['data']['Dates']['Expiration']
else
  puts "#{result['error']['Code']}: #{result['error']['Message']}"
end
```

I nomi dei metodi sono la forma snake_case di quelli di php-dna (`getDetails` → `get_details`, `registerWithContactInfo` → `register_with_contact_info`), con lo stesso ordine dei parametri e gli stessi valori predefiniti. I risultati sono semplici Hash e Array Ruby con **chiavi String**, esattamente la struttura restituita da php-dna (inclusi i flag stringa come `'LockStatus' => 'true'` e i prezzi formattati come `'11.9900'`). Le credenziali vengono ripulite dagli spazi, e il flag della modalità di test accetta anche stringhe: `"true"`, `"1"`, `"on"` e `"yes"` indicano la modalità di test, qualsiasi altro valore indica l'ambiente live.

## Gestione degli errori

I metodi non sollevano mai eccezioni per problemi dell'API o di rete. Una chiamata fallita restituisce un envelope di errore:

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

- `Code` è `API_<stato HTTP>` per gli errori del gateway (`API_400`, `API_401`, `API_429`, `API_500`, ...). Una risposta `301`/`302` indica credenziali errate (`Invalid API credentials`).
- Quando il gateway invia un proprio codice di errore, l'envelope lo riporta anche come `GatewayCode` (ad es. `'GatewayCode' => 'Dna.DomainService:Domain:10007'`), così puoi distinguere un `API_404` da un altro.
- Un corpo di errore vuoto diventa un messaggio leggibile come `HTTP 429 - Too Many Requests`. Il corpo grezzo della risposta non viene mai usato come messaggio quando il messaggio del gateway è generico; al suo posto viene usato un testo stabile che indica il codice del gateway.
- Gli errori di validazione dei campi vengono appiattiti in `Details`, ad esempio `Admin PostalCode - 'PostalCode' is required`.
- I guasti di rete sono errori, mai un successo vuoto. Un timeout riporta `Could not reach the DomainNameAPI service: the connection timed out. (...)`; gli altri errori di trasporto riportano `Curl error during request: ...`. I loro codici sono `CURL_<n>` con i numeri di curl (`CURL_28` timeout, `CURL_6` DNS, `CURL_7` connessione rifiutata, `CURL_35`/`CURL_60` TLS, `CURL_56` reset); `API_<n>` è riservato agli stati HTTP.
- Una registrazione, un trasferimento o un rinnovo a cui il gateway risponde con HTTP 200 ma `"success": false` è un rifiuto, non un successo: restituisce l'envelope di errore con codice `REGISTER_DOMAIN`, `TRANSFER_DOMAIN` o `RENEW_DOMAIN` e il messaggio del gateway.
- `get_current_balance` mantiene il proprio envelope: `'OperationResult' => 'FAILED'` con `ErrorCode` e `OperationMessage`.
- `check_availability` restituisce un semplice elenco in caso di successo e l'envelope di errore in caso di fallimento.

Sollevano eccezioni solo gli errori di programmazione (ad esempio `set_resource_record_set` con un `contents` che non è un elenco solleva `TypeError`).

I timeout sono di 30 secondi per chiamata e di 10 secondi per la connessione. Le chiamate agli endpoint delle zone DNS vengono distanziate di almeno un secondo, perché il gateway risponde `HTTP 429` alle raffiche di richieste.

### Diagnostica

```ruby
dna.get_request_data         # { 'url' => ..., 'method' => 'GET', 'payload' => {...} } dell'ultima chiamata
dna.get_response_data        # ultimo corpo di risposta decodificato (o { 'raw_response' => body })
dna.get_response_headers     # { 'url', 'http_code', 'headers', 'total_time' }
dna.get_parsed_response_data # ultimo corpo analizzato, o l'ultimo errore { 'Code', 'Message', 'Details' }
dna.get_last_function        # ad es. 'request:GET domains/info'
dna.get_service_url          # https://api.domainresellerapi.com/api/v1
dna.set_service_url('https://ote.domainresellerapi.com/api/v1')
```

## Modalità di test

Passa `true` come terzo argomento del costruttore per usare il gateway di test OTE (`https://ote.domainresellerapi.com/api/v1`). Le chiamate live vanno a `https://api.domainresellerapi.com/api/v1`. La modalità di test usa credenziali di test separate.

## Segnalazione errori (telemetria)

Quando una chiamata API fallisce, la libreria può inviare una segnalazione di errore al sistema di tracciamento errori di DomainNameAPI (Sentry). Una piccola quota casuale delle chiamate riuscite (4%, più ogni chiamata che dura più di 1 secondo) può essere inviata come record di prestazioni. Questo aiuta DomainNameAPI a trovare e correggere i problemi. La segnalazione errori è **attiva per impostazione predefinita**.

> ℹ️ Nella versione 1.0.0 il progetto Sentry per ruby-dna non esiste ancora, quindi il DSN integrato è vuoto e **non viene inviato nulla**. Le segnalazioni inizieranno quando una release includerà il DSN. `DomainNameApi::Client.new(id, key, false, sentry_dsn: '...')` ne imposta uno esplicitamente.

**Cosa viene inviato:**

- codice e messaggio di errore
- percorso dell'endpoint chiamato e metodo HTTP
- durata della chiamata
- nome della libreria (`DomainNameAPI-Ruby`), versione della libreria e versione di Ruby
- ID rivenditore e nome di dominio
- l'indirizzo IP pubblico del server (ricavato tramite `api.ipify.org`, in background)
- il nome utente del sistema operativo con cui gira il processo
- la richiesta e la risposta API, inclusi i dati di contatto del dominio; vengono mascherate solo le credenziali — codici EPP/auth, chiavi API, password e token vengono sostituiti con `***`

**Cosa non viene mai inviato:** codici EPP/auth, chiavi API, password o token in forma leggibile; argomenti dei metodi negli stack trace.

Gli errori previsti e frequenti (dominio non trovato, saldo insufficiente, credenziali non valide, ...) non vengono segnalati. Le segnalazioni vengono inviate da un thread in background con timeout brevi: non rallentano né interrompono mai la tua chiamata.

**Perché e per quanto tempo:** i dati vengono usati solo per misurare l'utilizzo e diagnosticare tempestivamente i problemi, e sono conservati per 30 giorni sul server Sentry di DomainNameAPI, dopodiché vengono eliminati automaticamente.

**Come disattivarla:**

```ruby
dna = DomainNameApi::Client.new(reseller_id, api_key)
dna.set_error_reporting_enabled(false)
```

La **modalità minima** invia solo il codice e il messaggio di errore, l'endpoint, i tempi, le versioni e il Reseller ID — nessun dato di richiesta/risposta, dominio, IP del server o nome utente:

```ruby
dna.set_telemetry_minimal(true)
```

> 🔒 **Sicurezza:** la verifica dei certificati TLS è attiva. Su un server con un bundle CA obsoleto può essere disattivata con `dna.set_ssl_verification(false)` — sconsigliato; aggiornare il bundle CA è la soluzione migliore.

## Utilizzo

Tutti gli esempi presuppongono `dna = DomainNameApi::Client.new(reseller_id, api_key)`. Script eseguibili per ogni metodo si trovano in [examples](examples).

### Account

#### Dettagli rivenditore

```ruby
dna.get_reseller_details
```

<details>
<summary>Output di esempio</summary>

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

#### Saldo attuale

`get_current_balance(currency = 'USD')` — l'account riporta saldi in `'USD'` e `'TRY'`. Per qualsiasi altra valuta (`'EUR'`, `'GBP'`, ...) la chiamata fallisce con `'ErrorCode' => 'BALANCE'` invece di rispondere `0.00`.

```ruby
dna.get_current_balance('USD')
```

<details>
<summary>Output di esempio</summary>

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

### Ricerca ed elenchi

#### Verifica disponibilità dominio

`check_availability(domains, extensions, period, command = 'create')` — `DomainName` nel risultato è il nome senza il `.tld` finale.

```ruby
dna.check_availability(['hello', 'world123x0'], ['com', 'net'], 1, 'create')
```

<details>
<summary>Output di esempio</summary>

```ruby
[
  { 'TLD' => 'com', 'DomainName' => 'hello', 'Status' => 'notavailable', 'Command' => 'create',
    'Period' => 1, 'IsFee' => false, 'Price' => '10.8100', 'Currency' => 'USD', 'Reason' => 'Domain exists' },
  { 'TLD' => 'com', 'DomainName' => 'world123x0', 'Status' => 'available', 'Command' => 'create',
    'Period' => 1, 'IsFee' => false, 'Price' => '10.8100', 'Currency' => 'USD', 'Reason' => nil }
]
```

</details>

#### Elenco domini

`get_list(extra_parameters = {})` — `PageNumber` (a partire da 0), `PageSize`, `OrderColumn`, `OrderDirection` e i filtri propri del gateway (ad es. `DomainName`).

```ruby
dna.get_list('OrderColumn' => 'Id', 'OrderDirection' => 'ASC', 'PageNumber' => 0, 'PageSize' => 1000)
```

<details>
<summary>Output di esempio</summary>

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

#### Elenco TLD

`get_tld_list(count = 20)`

```ruby
dna.get_tld_list(100)
```

<details>
<summary>Output di esempio</summary>

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

### Dominio

#### Registrazione dominio

`register_with_contact_info(domain, period, contacts, name_servers = [], epp_lock = true, privacy_lock = false, additional_attributes = {})`

I contatti usano le chiavi di php-dna. Sono accettate sia la forma piatta qui sotto sia quella annidata restituita da `get_contacts` (`Address => { Line1, City, ... }`, `Phone => { Phone => { Number, CountryCode } }`); i campi mancanti vengono completati e nomi, telefoni e paesi vengono normalizzati (vedi `validate_contact`). Se non vengono indicati name server, vengono usati `ns1.domainnameapi.com` e `ns2.domainnameapi.com`.

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

Per i domini `.tr` passa gli attributi TRABIS come 7° argomento:

```ruby
# Titolare persona fisica
{ 'TRABISDOMAINCATEGORY' => 1, 'TRABISCITIZIENID' => '12345678901' }
# Titolare azienda
{ 'TRABISDOMAINCATEGORY' => 0, 'TRABISTAXOFFICE' => 'Istanbul VD', 'TRABISTAXNUMBER' => '1234567890' }
```

La categoria viene inviata come `Owner`/`Corporate`, `TRABISCITIZIENID` come `TRABISCITIZENID`, e le chiavi legacy (`TRABISNAMESURNAME`, `TRABISCOUNTRYID`, `TRABISCITYID`, ...) vengono scartate, perché il gateway ora le legge dal contatto.

<details>
<summary>Output di esempio</summary>

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

#### Rinnovo dominio

```ruby
dna.renew('example.com', 1)
```

<details>
<summary>Output di esempio</summary>

```ruby
{ 'result' => 'OK', 'data' => { 'ExpirationDate' => '2025-03-15T10:00:00' } }
```

</details>

#### Dettagli dominio

```ruby
dna.get_details('example.com')
```

<details>
<summary>Output di esempio</summary>

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

#### Sincronizzazione dal registro

Stessa chiamata e stesso output di `get_details`.

```ruby
dna.sync_from_registry('example.com')
```

#### Modifica name server

Passa un elenco o un Hash (vengono usati i valori). I nomi vengono ripuliti dagli spazi, convertiti in minuscolo, privati del punto finale e deduplicati; il risultato riporta l'elenco così normalizzato.

```ruby
dna.modify_name_server('example.com', ['ns1.example.com', 'ns2.example.com'])
```

<details>
<summary>Output di esempio</summary>

```ruby
{ 'result' => 'OK', 'data' => { 'NameServers' => ['ns1.example.com', 'ns2.example.com'] } }
```

</details>

#### Attivare il blocco del dominio

```ruby
dna.enable_theft_protection_lock('example.com')
```

<details>
<summary>Output di esempio</summary>

```ruby
{ 'result' => 'OK', 'data' => { 'LockStatus' => true } }
```

</details>

#### Disattivare il blocco del dominio

```ruby
dna.disable_theft_protection_lock('example.com')
```

<details>
<summary>Output di esempio</summary>

```ruby
{ 'result' => 'OK', 'data' => { 'LockStatus' => false } }
```

</details>

#### Modificare la protezione privacy del dominio

`modify_privacy_protection_status(domain, status, reason = 'Owner request')` — `status` può essere `true`/`false` oppure un valore in stile pannello: `1`, `'1'`, `'true'`, `'on'` e `'yes'` attivano la privacy, qualsiasi altro valore la disattiva. Il risultato riporta il booleano interpretato. `reason` è accettato per compatibilità ma non viene inviato: il gateway non ha un campo del genere.

```ruby
dna.modify_privacy_protection_status('example.com', true, 'Owner request')
```

<details>
<summary>Output di esempio</summary>

```ruby
{ 'data' => { 'PrivacyProtectionStatus' => true }, 'result' => 'OK' }
```

</details>

#### Ottenere i contatti del dominio

I tipi di contatto vengono riconosciuti senza distinzione tra maiuscole e minuscole (`admin`/`administrative`, `tech`/`technical`, `registrant`/`owner`, `billing`); gli altri tipi restituiti dal registro vengono mantenuti dopo i quattro standard.

```ruby
dna.get_contacts('example.com')
```

<details>
<summary>Output di esempio</summary>

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
      # qualsiasi altro tipo di contatto restituito dal registro segue questi quattro
    }
  },
  'result' => 'OK'
}
```

</details>

#### Salvare i contatti del dominio

```ruby
dna.save_contacts('example.com', {
  'Administrative' => contact,
  'Billing'        => contact,
  'Technical'      => contact,
  'Registrant'     => contact
})
```

<details>
<summary>Output di esempio</summary>

```ruby
{ 'result' => 'OK', 'data' => { 'contacts' => {} } }
```

</details>

<hr style="border: 4px solid #000; border-style: dashed;">

### Child name server

#### Aggiungere un child name server

```ruby
dna.add_child_name_server('example.com', 'ns1.example.com', '1.2.3.4')
```

<details>
<summary>Output di esempio</summary>

```ruby
{ 'result' => 'OK', 'data' => { 'NameServer' => 'ns1.example.com', 'IPAdresses' => ['1.2.3.4'] } }
```

</details>

#### Eliminare un child name server

```ruby
dna.delete_child_name_server('example.com', 'ns1.example.com')
```

<details>
<summary>Output di esempio</summary>

```ruby
{ 'result' => 'OK', 'data' => { 'NameServer' => 'ns1.example.com' } }
```

</details>

#### Aggiornare un child name server

```ruby
dna.modify_child_name_server('example.com', 'ns1.example.com', '1.2.3.5')
```

<details>
<summary>Output di esempio</summary>

```ruby
{ 'result' => 'OK', 'data' => { 'NameServer' => 'ns1.example.com', 'IPAdresses' => ['1.2.3.5'] } }
```

</details>

<hr style="border: 4px solid #000; border-style: dashed;">

### Trasferimenti

#### Trasferimento dominio

`transfer(domain, epp_code, period)` — un trasferimento non invia mai contatti: è il registrar a gestirli, quindi la richiesta contiene sempre un elenco di contatti vuoto e il metodo non accetta alcun argomento per i contatti. Aggiorna i contatti con `save_contacts` una volta completato il trasferimento.

```ruby
dna.transfer('example.com', 'Xy9#mK2$', 3)
```

<details>
<summary>Output di esempio</summary>

```ruby
{
  'data' => { 'ID' => 0, 'Status' => 'WaitingForIncomingTransfer', 'DomainName' => 'example.com', ... },
  'result' => 'OK'
}
```

</details>

#### Verifica trasferimento

`result` è `'OK'` solo quando il registro indica che il dominio è trasferibile.

```ruby
dna.check_transfer('example.com', 'Xy9#mK2$')
```

<details>
<summary>Output di esempio</summary>

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

#### Annullare, approvare o rifiutare un trasferimento

`cancel_transfer` annulla un trasferimento in entrata in sospeso; `approve_transfer` e `reject_transfer` rispondono a un trasferimento in uscita in sospeso.

```ruby
dna.cancel_transfer('example.com')
dna.approve_transfer('example.com')
dna.reject_transfer('example.com')
```

<details>
<summary>Output di esempio</summary>

```ruby
{ 'result' => 'OK', 'data' => { 'DomainName' => 'example.com', 'Status' => 'Cancelled' } } # 'Approved' / 'Rejected'
```

</details>

<hr style="border: 4px solid #000; border-style: dashed;">

### Zona DNS

Tipi di record supportati: `A`, `AAAA`, `ALIAS`, `CAA`, `CNAME`, `DS`, `MX`, `NAPTR`, `PTR`, `SRV`, `TLSA`, `TXT` (gli altri tipi vengono rifiutati prima di qualsiasi chiamata). I nomi sono relativi (`'www'`); `''` o `'@'` indica l'apice della zona, e un nome completo come `'www.example.com'` viene ridotto alla sua etichetta. Le modifiche vengono applicate immediatamente; passa `apply = false` per prepararne diverse e chiama `apply_resource_records` una sola volta. Il TTL va da 1 a 86400 secondi.

Se l'applicazione automatica fallisce, il metodo restituisce l'errore di applicazione (la modifica resta in attesa, non attiva) invece di `OK`. Il risultato riporta il tipo in maiuscolo e il TTL effettivamente inviati.

Il gateway memorizza un nome + tipo come un unico **set**: scrivere un set ne sostituisce tutti i valori, ed eliminare un valore elimina l'intero set. I metodi `*_resource_record_value` eseguono per te la sequenza lettura-unione-scrittura.

#### Elencare i record

```ruby
dna.get_resource_records('example.com')
```

<details>
<summary>Output di esempio</summary>

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

#### Sostituire un set di record

`set_resource_record_set(domain, name, type, contents, ttl = 3600, apply = true)` — un elenco vuoto rimuove il set.

```ruby
dna.set_resource_record_set('example.com', 'www', 'A', ['192.0.2.10', '192.0.2.11'], 3600)
```

<details>
<summary>Output di esempio</summary>

```ruby
{ 'result' => 'OK', 'data' => { 'Name' => 'www', 'Type' => 'A', 'TTL' => 3600, 'Contents' => ['192.0.2.10', '192.0.2.11'] } }
```

</details>

#### Aggiungere, sostituire o rimuovere un singolo valore

`add_resource_record_value(domain, name, type, value, ttl = nil, apply = true)`, `replace_resource_record_value(domain, name, type, old_value, new_value, ttl = nil, apply = true)`, `remove_resource_record_value(domain, name, type, value, apply = true)`. Un TTL `nil` mantiene il TTL attuale del set; aggiungere un valore già esistente o rimuoverne uno inesistente non ha effetto (`'Changed' => false`).

```ruby
dna.add_resource_record_value('example.com', '', 'MX', '10 mail.example.com.')
dna.replace_resource_record_value('example.com', '', 'MX', '10 mail.example.com.', '20 mail.example.com.')
dna.remove_resource_record_value('example.com', '', 'MX', '20 mail.example.com.')
```

<details>
<summary>Output di esempio</summary>

```ruby
{ 'result' => 'OK', 'data' => { 'Name' => '', 'Type' => 'MX', 'TTL' => 3600, 'Contents' => ['10 mail.example.com.'] } }
# valore già presente:
{ 'result' => 'OK', 'data' => { 'Name' => '', 'Type' => 'MX', 'Contents' => ['10 mail.example.com.'], 'Changed' => false } }
```

</details>

#### Eliminare un set di record

`delete_resource_record_set(domain, name, type, apply = true, known_value = '')` — rimuove tutti i valori del set; se non c'è nulla da rimuovere, la chiamata riesce con `'Removed' => false`.

```ruby
dna.delete_resource_record_set('example.com', 'www', 'A')
```

<details>
<summary>Output di esempio</summary>

```ruby
{ 'result' => 'OK', 'data' => { 'Name' => 'www.example.com.', 'Type' => 'A', 'Content' => '192.0.2.10' } }
```

</details>

#### Chiamate di basso livello sui record

```ruby
dna.add_resource_record('example.com', 'www', 'A', '192.0.2.10', 3600, true)
dna.edit_resource_record('example.com', 'www', 'www', 'A', '192.0.2.20', 3600, true)
dna.delete_resource_record('example.com', 'www.example.com.', '192.0.2.20', 'A', true)
dna.apply_resource_records('example.com')
```

<details>
<summary>Output di esempio</summary>

```ruby
{ 'result' => 'OK', 'data' => { 'Name' => 'www', 'Type' => 'A', 'TTL' => 3600, 'Content' => '192.0.2.10' } }   # add / edit
{ 'result' => 'OK', 'data' => { 'Name' => 'www.example.com.', 'Type' => 'A', 'Content' => '192.0.2.20' } }    # delete
{ 'result' => 'OK', 'data' => { 'DomainName' => 'example.com' } }                                              # apply
```

</details>

<hr style="border: 4px solid #000; border-style: dashed;">

### Inoltro URL

Tipi di inoltro: `'Standard'` (reindirizzamento semplice) e `'Frame'` (mascherato). Il gateway risponde `Redirect information not found` quando non è configurato nulla: in tal caso `get_forwarding` riporta `'Enabled' => false` e `delete_forwarding` riesce con `'Removed' => false`. Qualsiasi altro errore, come un dominio sconosciuto, viene restituito come errore.

```ruby
dna.set_forwarding('example.com', 'https://www.example.org', 'Standard')
dna.get_forwarding('example.com')
dna.delete_forwarding('example.com')
```

<details>
<summary>Output di esempio</summary>

```ruby
# set_forwarding
{ 'result' => 'OK', 'data' => { 'RedirectAddress' => 'https://www.example.org', 'ForwardType' => 'Standard' } }
# get_forwarding (se non è configurato nulla restituisce Enabled => false, non un errore)
{ 'result' => 'OK', 'data' => { 'Enabled' => true, 'RedirectAddress' => 'https://www.example.org', 'ForwardType' => 'Standard' } }
# delete_forwarding (Removed => false quando non era configurato nulla)
{ 'result' => 'OK', 'data' => { 'DomainName' => 'example.com', 'Removed' => true } }
```

</details>

<hr style="border: 4px solid #000; border-style: dashed;">

### Utilità (senza rete)

#### È un dominio .tr?

```ruby
dna.is_tr_tld('example.com.tr') # => true
dna.is_tr_tld('example.com')    # => false
```

#### Validare un contatto

Completa e normalizza un contatto nello stesso modo della registrazione: cifre e punteggiatura vengono rimosse dai nomi, uno stato mancante viene sostituito dalla città, i nomi dei paesi diventano codici ISO e i numeri di telefono vengono separati in numero e prefisso internazionale. Un numero scritto con il proprio prefisso `+` o `00` mantiene quel prefisso anche quando è stato indicato un altro `PhoneCountryCode` (`'+1 202 555 0100'` → `'2025550100'` / `'1'`).

```ruby
dna.validate_contact('FirstName' => 'J0hn', 'Phone' => '+90 532 374 33 88', 'Country' => 'Turkey')
```

<details>
<summary>Output di esempio</summary>

```ruby
{
  'FirstName' => 'Jhn', 'Phone' => '5323743388', 'Country' => 'TR', 'LastName' => 'Isimyok',
  'AddressLine1' => 'Addres yok', 'City' => 'ISTANBUL', 'State' => 'ISTANBUL', 'ZipCode' => '34000',
  'PhoneCountryCode' => '90', 'Fax' => '', 'FaxCountryCode' => ''
}
```

</details>

<hr style="border: 4px solid #000; border-style: dashed;">

### Impostazioni

| Metodo | Effetto |
|---|---|
| `set_error_reporting_enabled(false)` | Disattiva la telemetria |
| `set_telemetry_minimal(true)` | Invia il payload di telemetria minimo |
| `set_ssl_verification(false)` | Salta la verifica dei certificati TLS (sconsigliato) |
| `set_service_url(url)` | Usa un altro URL del gateway |
| `set_transport(callable)` | Sostituisce il trasporto HTTP (vedi sotto) |

Il trasporto HTTP è un qualsiasi oggetto che risponde a `call(request)`, dove `request` è un Hash con `:method`, `:url`, `:headers`, `:body`, `:timeout`, `:connect_timeout` e `:verify_ssl`, e restituisce un `DomainNameApi::Response` (o un Hash con `:status`, `:body`, `:headers`). Il valore predefinito è `DomainNameApi::NetHttpTransport` (Net::HTTP). È così che i test vengono eseguiti senza rete:

```ruby
fake = ->(request) { DomainNameApi::Response.new(status: 200, body: '{"resellerId":"abc"}', headers: {}) }
dna = DomainNameApi::Client.new(reseller_id, api_key, false, transport: fake)
```

<hr style="border: 4px solid #000; border-style: dashed;">

## Test

La suite di test usa solo Minitest e non accede mai alla rete:

```bash
bundle install
bundle exec rake test
```

`test/conformance_test.rb` esegue le 126 fixture di conformità di php-dna (`test/fixtures/conformance/`): per ogni scenario verifica le richieste inviate (metodo, percorso, query, corpo JSON, header di autenticazione) e il valore restituito rispetto a quanto prodotto da php-dna. Gli altri test coprono il livello HTTP, la mappatura degli errori, il mascheramento della telemetria, il trasporto Net::HTTP e le utilità.

<hr style="border: 4px solid #000; border-style: dashed;">

## Codici di Ritorno ed Errore con Descrizioni

| Codice | Descrizione | Dettaglio |
|--------|-------------|-----------|
| 1000 | Comando completato con successo | Operazione riuscita. |
| 1001 | Comando completato con successo; azione in sospeso | Operazione riuscita. Tuttavia, l'operazione è attualmente in coda per il completamento. |
| 2003 | Parametro richiesto mancante | Errore parametro mancante. Ad esempio: nessuna voce telefonica nelle informazioni di contatto. |
| 2105 | L'oggetto non è idoneo per il rinnovo | Lo stato del dominio non è adatto per il rinnovo, bloccato per operazioni di aggiornamento. Lo stato non dovrebbe essere "clientupdateprohibited". Potrebbe essere dovuto ad altre condizioni di stato. |
| 2200 | Errore di autenticazione | Errore di autorizzazione, codice di sicurezza errato o dominio registrato con un altro registrar. |
| 2302 | L'oggetto esiste | Il nome di dominio o le informazioni del name server esistono già nel database. Non può essere registrato. |
| 2303 | L'oggetto non esiste | Il nome di dominio o le informazioni del name server non esistono nel database. È richiesta una nuova registrazione. |
| 2304 | Lo stato dell'oggetto vieta l'operazione | Lo stato del dominio non è adatto per gli aggiornamenti, bloccato per operazioni di aggiornamento. Lo stato non dovrebbe essere "clientupdateprohibited". Potrebbe essere dovuto ad altre condizioni di stato. |

| CODICE | DETTAGLIO |
|--------|-----------|
| 101 | Errore di sistema dettagliato per ({0})! |
| 102 | Errori multipli dettagliati per ({0})! |
| 103 | Errori sconosciuti dettagliati per ({0})! |
| 200 | Comando API non trovato ({0})! |
| 210 | Servizio API non trovato ({0})! |
| 211 | Provider di servizio API non impostato! |
| 300 | Rivenditore non trovato! |
| 301 | Il tuo indirizzo IP attuale non è autorizzato ad accedere. Assicurati di connetterti da un indirizzo IP autorizzato e riprova |
| 310 | TLD non supportato! |
| 320 | API non trovata! |
| 321 | Valuta non supportata! |
| 330 | Parametro/i richiesto/i non impostato/i ({0}). |
| – | Assicurati di inviare tutti gli oggetti di contatto completi |
| 340 | Definizione prezzo non trovata ({0}[{1}]-{2}{3}). |
| 350 | Saldo rivenditore insufficiente. (Id Rivenditore : {0} - Saldo Attuale : {1} {2}). |
| 350 | La valuta contabile non corrisponde o il saldo non è sufficiente. |
| 360 | Richiesta API non valida per il campo ({0}). |
| 360 | Quota API superata! |
| 361 | Errore di throttling! |
| 362 | Il dominio premium non è disponibile per la registrazione al momento. |
| 363 | Operazione annullata perché il dominio è nel periodo di rinnovo automatico |
| 364 | Questo dominio è attualmente non disponibile per la transazione a causa di un problema con il registro |

| CODICE | DETTAGLIO |
|--------|-----------|
| 400 | Contatto non valido ({0}). |
| 401 | Le informazioni di contatto non possono essere sincronizzate. |
| 402 | Nessun accesso alle informazioni di contatto dal registro. |
| 403 | IL SISTEMA HA INFORMAZIONI MANCANTI. INSERISCI LE TUE INFORMAZIONI PREDEFINITE O CONTATTA IL TEAM DI SUPPORTO. |
| 404 | IL CONTATTO DEL DOMINIO NON PUÒ ESSERE AGGIORNATO. PERMESSO DAL REGISTRO. |
| 410 | Contatto non trovato. |
| 410 | Contatto non trovato ({0}). |
| 420 | Comando Api non valido per il contatto {0}. |
| 430 | API contatto non trovata. |
| 440 | Il contatto non è sincronizzato. |
| 450 | Troppi contatti di dominio! |
| 451 | Impossibile procedere con l'aggiornamento del contatto. |

| CODICE | DETTAGLIO |
|--------|-----------|
| 500 | ID dominio non valido. |
| 500 | ID dominio non valido ({0}). |
| 501 | Il dominio non può essere sincronizzato({0}) |
| 502 | Trasferimento interno fallito |
| 503 | La registrazione del dominio non è disponibile. |
| 504 | Le informazioni del dominio non corrispondono. Prima :{0} |
| 505 | Inserisci l'indirizzo IP. |
| 506 | Il trasferimento del dominio è stato avviato ma le informazioni di contatto non sono state lette. |
| 507 | Errore di autorizzazione. |
| 510 | Dominio non trovato. |
| 511 | I domini scaduti non possono essere trovati. |
| 512 | Il dominio non è rinnovabile. |
| 513 | Il dominio non è in stato aggiornabile. Deve essere attivo per essere aggiornato |
| 514 | Periodo di redenzione previsto. |
| 520 | Comando Api non valido per il dominio "{0}". |
| 530 | Periodo di dominio non valido. Il periodo deve essere da {0} a {1} anni. Il periodo richiesto è {2} anni. |
| 540 | Il dominio non può essere esteso oltre {0} anni dalla data attuale. |
| 550 | Nome di dominio non valido. Il dominio deve essere lungo da {0} a {1} caratteri. Il nome di dominio richiesto è di {2} caratteri. |
| 560 | Numero di name server non valido. Il dominio deve avere da {0} a {1} name server. Il numero di name server richiesto è {2}. |
| 561 | Nessuna informazione name server trovata nella richiesta in arrivo |
| 570 | Idn non supportato per tld "{0}". |
| 571 | Periodo non valido. |
| 572 | Comando non valido. |
| 573 | Nomi di dominio non trovati. |
| 574 | Nomi TLD non trovati. |
| 575 | Il dominio non è in stato aggiornabile. Deve essere attivo per aggiornare i name server |
| 576 | Il dominio può essere rinnovato nell'ultimo mese prima della data di scadenza |
| 580 | Trasferimento non supportato per tld "{0}". |
| 581 | Child name server non trovato |
| 582 | Trasferimento avviato da altro rivenditore. |
| 583 | Trasferimento non inizializzato. Contatta il team di supporto. |
| 584 | Lo stato dell'oggetto vieta l'operazione |
| 590 | Il codice di autorizzazione è richiesto per questo trasferimento. |
| 591 | Il codice di autorizzazione non è valido. |
| 592 | Esiste un blocco di trasferimento sul dominio. |
| 593 | Il dominio non può essere trasferito, le informazioni di stato e il blocco di trasferimento devono rispettare i criteri richiesti. (Informazioni di stato: #ok) |
| 594 | L'indirizzo del name server di dominio non può essere risolto ({0}) |
| 595 | Le informazioni di contatto non possono essere lette (whois.registrar.tld) Assicurati che lo stato di protezione della privacy sia aperto |
| 596 | Le informazioni di contatto non possono essere verificate |
| 597 | Tld non trovato |
| 598 | Si è verificato un errore sconosciuto |
| 599 | Inoltro di dominio non trovato |

## Licenza

Apache License 2.0 — vedi [LICENSE](LICENSE).
