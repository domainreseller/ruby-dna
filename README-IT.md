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

# ruby-dna: l'SDK Ruby per la Domain Name API

[![CI](https://github.com/domainreseller/ruby-dna/actions/workflows/ci.yml/badge.svg)](https://github.com/domainreseller/ruby-dna/actions/workflows/ci.yml)
[![License](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](LICENSE)

Client Ruby per l'API REST per rivenditori di [Domain Name API](https://www.domainnameapi.com): ricerca di domini,
registrazione, rinnovo e trasferimento, DNS, DNSSEC, contatti, certificati SSL, hosting, ordini, catalogo prodotti e
saldo.

- **Tutte le 67 operazioni dell'API**, raggruppate come nella [CLI `dna`](https://github.com/domainreseller/cli):
  `dna domain info` corrisponde a `client.domains.info`, `dna dns add` a `client.dns.add`.
- **Oggetti veri, non hash**: `domain.status.pending_delete?`, `domain.expiration_date` è un `Time`,
  `availability.available?`, `tld.register_price(1)`.
- **Ogni operazione è una classe di richiesta** che eredita da `DomainNameApi::BaseRequest` e si valida da sola prima
  dell'invio. Scrivi le tue allo stesso modo.
- **Sicuro per impostazione predefinita**: le richieste a pagamento non vengono mai ritentate alla cieca,
  `read_only: true` blocca le modifiche, il client regola il proprio ritmo entro i limiti di frequenza ed è sicuro da
  condividere tra thread.
- **Nessuna dipendenza.** Ruby 3.1 o successivo, solo libreria standard.

```ruby
client = DomainNameApi::Client.new(reseller_id: reseller_id, api_key: api_key, environment: :ote)

a = client.domains.search('example.com')
puts "#{a.domain_name} is available for #{a.price} #{a.currency}" if a.available?
```

## Indice

- [Installazione](#installazione)
- [Credenziali e ambienti](#credenziali-e-ambienti)
- [Servizi](#servizi)
- [Utilizzo](#utilizzo)
- [Risultati, modelli ed enumerazioni](#risultati-modelli-ed-enumerazioni)
- [Richieste e BaseRequest](#richieste-e-baserequest)
- [Errori](#errori)
- [Sicurezza e affidabilità](#sicurezza-e-affidabilità)
- [Opzioni del client](#opzioni-del-client)
- [Testare il proprio codice](#testare-il-proprio-codice)
- [Migrare dalla v1](#migrare-dalla-v1)
- [Sviluppo](#sviluppo)

## Installazione

> ⬇️ Usa una versione con tag dalle [Releases](https://github.com/domainreseller/ruby-dna/releases/latest). Il
> pulsante verde **Code → Download ZIP** ti dà il ramo di sviluppo.

Con Bundler:

```ruby
# Gemfile
gem 'domainnameapi', git: 'https://github.com/domainreseller/ruby-dna.git', tag: 'v2.1.0'
```

Oppure installa il file `.gem` allegato alla release:

```bash
gem install ./domainnameapi-2.1.0.gem
```

```ruby
require 'domainnameapi'
```

I programmi eseguibili si trovano in [examples](examples): `quickstart`, `register`, `expiring`, `dns`, `ssl` e
`custom_request`.

```bash
DNA_RESELLER_ID=... DNA_API_KEY=... DNA_ENV=ote ruby examples/quickstart.rb example.com
```

## Credenziali e ambienti

Servono due credenziali API, disponibili nel pannello rivenditore (**API settings**). Le credenziali di accesso al
pannello non funzionano.

| Credenziale | Aspetto                                |
|-------------|----------------------------------------|
| Reseller ID | `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx` |
| API key     | una lunga stringa segreta              |

Esistono due ambienti. **Inizia con OTE**, l'ambiente di test: ha dati propri e una propria chiave API, e nulla di ciò
che fai lì costa denaro o tocca domini reali.

```ruby
# Ambiente di test (OTE)
client = DomainNameApi::Client.new(reseller_id: reseller_id, api_key: ote_api_key, environment: :ote)

# Produzione (predefinito): registrazioni reali, addebiti reali
client = DomainNameApi::Client.new(reseller_id: reseller_id, api_key: api_key)
```

`environment:` accetta anche le stringhe salvate dai pannelli: `'production'`, `'ote'`, `'test'` e i flag della
modalità di test (`'true'`, `'1'`, `true`). `Client.from_env` legge le stesse variabili della CLI `dna`:

| Variabile         | Significato                                                   |
|-------------------|---------------------------------------------------------------|
| `DNA_RESELLER_ID` | ID rivenditore                                                |
| `DNA_API_KEY`     | chiave API dell'ambiente selezionato                          |
| `DNA_ENV`         | `production` (predefinito) oppure `ote`                       |
| `DNA_TEST_MODE`   | `true` seleziona OTE (come negli altri SDK DomainNameAPI)     |
| `DNA_BASE_URL`    | un URL di base personalizzato, ad es. un proxy                |

```ruby
client = DomainNameApi::Client.from_env(user_agent: 'my-panel/1.4')
```

Una chiave o un ambiente errati falliscono alla prima richiesta con un `APIError` il cui `auth?` è true e il cui `hint`
indica cosa controllare; `client.account.get` è il modo meno costoso per verificare.

## Servizi

| Servizio           | Gruppo CLI    | Metodi                                                                                                                                                            |
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

Gli input obbligatori sono posizionali (`info('example.com')`), tutto il resto è un argomento con nome
(`renew('example.com', years: 1)`). Le operazioni con molti input facoltativi accettano argomenti con nome oppure un
oggetto di richiesta: `register(domain_name: ..., years: 1, ...)` e `register(DomainNameApi::DomainRegisterRequest.new(...))`
sono equivalenti. `ssl.purchase` corrisponde a `dna ssl initialize` della CLI (`initialize` è riservato in Ruby).

## Utilizzo

Tutti gli snippet presuppongono un `client`.

### Ricerca

```ruby
a = client.domains.search('example.com')
a.available?            # a.price, a.currency, a.premium?, a.document_required?, a.reason

client.domains.bulk_search('example.com', 'example.net', 'example.org').each do |r|
  puts "#{r.domain_name} #{r.status} #{r.price}"
end
```

`bulk_search` divide le liste di più di 30 domini in più richieste. I prezzi usano la valuta dell'account, l'opzione
`currency: 'TRY'` del client oppure `search('example.com', currency: 'USD')`.

### Registrazione

Con gli handle dei contatti (creane uno con `contacts.create`):

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
  handles: handle # un solo handle per tutti e quattro i ruoli, oppure { registrant: 'DNA-1', admin: 'DNA-2', tech: ..., billing: ... }
)
result.status           # result.domain_id, result.expiration_date
```

Con contatti inline:

```ruby
client.domains.register_with_contacts(
  domain_name: 'example.com',
  name_servers: %w[ns1.example.net ns2.example.net],
  contacts: owner # un solo Contact per tutti e quattro i ruoli, oppure { registrant: owner, admin: admin, tech: admin, billing: admin }
)
```

I contatti possono essere oggetti `DomainNameApi::Contact` oppure Hash con gli stessi campi. Vengono normalizzati prima
dell'invio: gli spazi nei campi vengono rimossi, il paese viene portato in maiuscolo e i campi telefonici conservano
solo le cifre (`'+90 (555) 123-45-67'` funziona). Alcuni TLD richiedono attributi di registro: trovali con
`client.products.tld('com.tr').required_attributes` e passali come `tld_attributes:`.

Se l'API risponde ma rifiuta l'operazione (`"success": false`), il metodo solleva un `DomainNameApi::OperationError` con
il messaggio dell'API.

### Rinnovo, trasferimento, ripristino

```ruby
check = client.domains.renew_check('example.com', years: 1)   # check.renewable?, check.premium_price
client.domains.renew('example.com', years: 1)

tc = client.domains.transfer_check('example.com', 'auth-code') # tc.transferable?, tc.auth_code_valid?
client.domains.transfer('example.com', auth_code: 'auth-code')
client.domains.transfer_status('example.com').status

client.domains.restore('example.com') # durante il periodo di redemption
```

### Dettagli del dominio ed elenco dei domini

```ruby
d = client.domains.info('example.com')
d.status                # => #<DomainNameApi::DomainStatus Active (0)>
d.expiration_date       # => 2027-03-15 10:20:30 UTC
d.remaining_days, d.locked?, d.privacy_protection?, d.name_servers, d.auth_code, d.hosts
d.contact(:registrant)&.email

# Una pagina
page = client.domains.list(limit: 50, sort: 'expirationDate')
page.total_count
page.each { |domain| puts domain.domain_name }

# Tutti i domini; le pagine vengono recuperate man mano
client.domains.all(statuses: [:active]) do |domain|
  puts "#{domain.domain_name} #{domain.expiration_date}"
end
client.domains.all.first(10) # un Enumerator senza blocco: recupera una sola pagina
```

### Blocco, privacy, nameserver, nameserver figli

```ruby
client.domains.lock('example.com')
client.domains.unlock('example.com')
client.domains.set_privacy('example.com', true)
code = client.domains.update_auth_code('example.com')

client.domains.set_name_servers('example.com', %w[ns1.example.net ns2.example.net])
client.domains.set_name_servers('example.com', %w[ns1.other.net ns2.other.net], dnssec_mode: :disable) # domini firmati con DNSSEC

client.domains.add_host('example.com', 'ns1.example.com', '192.0.2.10', '2001:db8::10') # versione IP rilevata
client.domains.update_host('example.com', 'ns1.example.com', ip_addresses: ['192.0.2.20'])
client.domains.delete_host('example.com', 'ns1.example.com')
```

### Contatti di un dominio

```ruby
client.domains.set_contact_handles('example.com', admin: 'DNA-2', tech: 'DNA-2') # gli altri ruoli restano invariati
client.domains.update_contacts('example.com', billing: billing_contact)

details = client.contacts.get('DNA-1')               # il contatto e il suo stato di verifica
result = client.contacts.update('DNA-1', contact)    # aggiorna tutti i domini che usano l'handle
result.affected_domains.each { |a| puts "#{a.domain_name} #{a.new_handle}" }
client.contacts.resend_verification('DNA-1')          # false quando non c'è nulla da verificare
```

### Zona DNS

```ruby
client.dns.add('example.com', name: 'www', type: :a, values: '192.0.2.10', ttl: 600)
client.dns.update('example.com', record_name: 'www', type: :a, values: %w[192.0.2.20 192.0.2.21]) # sostituisce l'intero set
client.dns.delete('example.com', name: 'www', type: :a, value: '192.0.2.20')

client.dns.list('example.com').each do |set|
  puts "#{set.name} #{set.type} #{set.ttl} #{set.values.join(', ')}"
end

client.dns.apply('example.com') # passa il dominio ai nameserver della piattaforma
```

I nomi possono essere relativi (`'www'`), l'apex (`''` o `'@'`) o completi (FQDN). I tipi di record sono simboli o
stringhe, in maiuscolo o minuscolo (`:txt` e `'txt'` vengono inviati come `TXT`). La validazione intercetta ciò che
l'API rifiuterebbe: un CNAME all'apex, un valore CAA senza tre parti, un valore MX senza priorità, un record A con un
indirizzo IPv6. L'ambiente di test risponde a ogni chiamata di zona con HTTP 500, quindi il codice per le zone può
essere provato solo in produzione.

### DNSSEC

```ruby
results = client.dnssec.add('example.com', '2371 13 2 1F987CC6583E92DF0890718C42...') # come lo mostra il tuo provider DNS
info = client.dnssec.get('example.com') # info.status.signed?, info.ds_records
client.dnssec.disable('example.com')
```

`DomainNameApi::DS.parse` legge il formato di presentazione e intere righe di file di zona; funziona anche `DS.new(key_tag: ...,
algorithm: :ecdsa_p256_sha256, digest_type: :sha256, digest: '...')`.

### Inoltro URL

```ruby
client.domains.set_forwarding('example.com', 'https://www.example.org')              # redirect 301
client.domains.set_forwarding('example.com', 'https://www.example.org', type: :frame) # inoltro mascherato
f = client.domains.forwarding('example.com') # nil quando il dominio non ne ha
client.domains.delete_forwarding('example.com')
```

### Documenti del registro (.tr)

```ruby
doc = DomainNameApi::DocumentUpload.from_file(:identity_card, 'id.pdf')
client.domains.upload_documents('example.com.tr', doc)
client.domains.documents('example.com.tr').each { |d| puts "#{d.name} #{d.status}" }
```

I file vengono codificati in base64 per te; il formato (PDF, JPG, PNG, DOC, DOCX, ODT) e la dimensione (10 MB per file,
50 MB per richiesta) vengono verificati prima del caricamento.

### Certificati SSL

```ruby
csr = client.ssl.generate_csr(domain_name: 'example.com', country: 'TR', state: 'Istanbul', locality: 'Istanbul',
                              organization: 'Example Ltd', organization_unit: 'IT')
# addebita il saldo (CLI: dna ssl initialize)
order = client.ssl.purchase('example.com', package_code: 'PositiveSSL')
id = order.certificate_id # conservalo: ogni chiamata successiva lo richiede
client.ssl.configure(certificate_id: id, csr: csr.csr, approver_mail: 'admin@example.com',
                     authentication_type: :email, web_server_type: :apache, contact: ssl_contact)
client.ssl.status(id).issued? # interroga finché non restituisce true
File.write('example.com.crt', client.ssl.content(id).chain)
```

Un dominio può avere più certificati, quindi un certificato esistente si identifica con il suo `certificate_id`
(un GUID), mai con il nome di dominio: `purchase` e `renew` lo restituiscono e `list` lo trova. Un nome di dominio
al posto di un identificativo solleva un `InputError` prima che venga inviato qualcosa. Configura un certificato
entro 15 giorni dall'acquisto o dal rinnovo.

```ruby
client.ssl.list(domain_name: 'example.com').each { |c| puts "#{c.certificate_id} #{c.status}" } # dal più recente
client.ssl.all { |c| puts "#{c.domain_name} #{c.subscription_expires_at}" } # tutti i certificati, pagina per pagina

client.ssl.approvers(certificate_id: id)                                      # per un certificato esistente
client.ssl.approvers(domain_name: 'example.com', package_code: 'PositiveSSL') # prima di un acquisto

renewal = client.ssl.renew(id) # addebita il saldo; possibile da 30 giorni prima della scadenza dell'abbonamento
client.ssl.configure(certificate_id: renewal.certificate_id, csr: new_csr.csr, approver_mail: 'admin@example.com',
                     authentication_type: :email, web_server_type: :apache, contact: ssl_contact)
```

Per rinnovare, chiama `renew` e poi `configure` sul nuovo certificato restituito. Non chiamare di nuovo
`purchase`: sarebbe un nuovo ordine indipendente, al prezzo di acquisto, e il vecchio certificato non passerebbe
mai allo stato `Renewed`.

### Hosting

```ruby
client.hosting.packages.each { |p| puts p.service_plans.map(&:service_plan) }
created = client.hosting.create('example.com', service_plan: 'Linux-Starter') # addebita il saldo

st = client.hosting.wait(created.service_id, timeout: 30 * 60) # interroga finché non è attivo
puts st.panel_address, st.username, st.password
```

Non chiamare mai `create` di nuovo per un hosting ancora in fase di provisioning: l'addebito avverrebbe due volte.

### Saldo, prezzi e ordini

```ruby
account = client.account.get
account.balance('USD')
profile = client.account.profile # profile.company_name, profile.account_currency, profile.status.active?

client.account.all_transactions(from: Date.new(2026, 11, 1)) do |tx|
  puts "#{tx.creation_time} #{tx.type} #{tx.change}"
end

tld = client.products.tld('com.tr')
tld&.register_price(1)&.to_s   # => "12.50 USD"

client.products.info('com', order_type: :renew, years: 2) # prezzo di un rinnovo biennale di un .com
client.orders.get('ORDER-CODE')
```

## Risultati, modelli ed enumerazioni

Ogni risultato è un `DomainNameApi::Model`: metodi di lettura in snake_case, predicati `?` per i flag, oggetti `Time`
per le date, modelli annidati e liste.

```ruby
d = client.domains.info('example.com')
d.locked?                 # anche d.locked
d.hosts.first.ip_addresses.first.address
d.to_h                    # un semplice Hash con chiavi in snake_case
d.raw                     # l'oggetto JSON così come l'ha inviato l'API, per i campi che questa gem non modella
```

I valori numerici e le stringhe fisse sono enumerazioni (`DomainStatus`, `RecordType`, `ContactType`, `DocumentType`,
...):

```ruby
d.status.pending_delete?                       # un predicato per ogni membro
d.status == DomainNameApi::DomainStatus::ACTIVE
d.status == :active                            # il confronto funziona anche con simboli, nomi e numeri
d.status.to_s                                  # => "Active"
d.status.to_i                                  # => 0
DomainNameApi::DomainStatus.members            # tutti i membri
```

Le richieste accettano enumerazioni, simboli, nomi in maiuscolo o minuscolo oppure numeri:
`statuses: [:active, 'PendingDelete', 7]`.

La decodifica è tollerante: le date senza fuso orario, `null`, `[]` al posto di `{}`, i numeri inviati come stringhe, i
ruoli in qualsiasi maiuscolo/minuscolo (`"registrant"`, `"ADMINISTRATIVE"`) e i valori che questa gem non conosce
ancora vengono tutti decodificati invece di far fallire la chiamata (per questi ultimi `status.known?` è false).

## Richieste e BaseRequest

Ogni operazione dell'API è una classe di richiesta: `DomainInfoRequest`, `DNSAddRequest`, `SSLConfigureRequest`, ...
che prende il nome dal comando della CLI (`dna domain renew` corrisponde a `DomainRenewRequest`). Tutte ereditano da
`DomainNameApi::BaseRequest`, che fornisce l'infrastruttura: un DSL `endpoint` e `attribute` a livello di classe,
l'inizializzazione tramite argomenti con nome, helper di validazione, template di percorso e builder per query e corpo.
Le richieste di elenco ereditano da `PagedRequest`, che aggiunge `skip`, `limit` e `sort`. Una richiesta di questa gem
si presenta così:

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

I metodi dei servizi le costruiscono per te. `client.call` invia qualsiasi richiesta, comprese le tue classi, ad esempio
per leggere solo i campi che ti servono o per chiamare un endpoint che questa gem non incapsula ancora:

```ruby
class Expiry < DomainNameApi::Model
  field :expiration_date, :time
  field :remaining_days, :integer, from: 'remainingDay'
end

class ExpiryRequest < DomainNameApi::BaseRequest
  endpoint :get, '/api/v1/domains/info', safety: :read
  returns Expiry            # omettilo per ottenere il JSON decodificato
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

| Ridefinizione  | Predefinito     | Scopo                                                                       |
|----------------|-----------------|-----------------------------------------------------------------------------|
| `query`        | `nil`           | un `Query` (`params.string(...)`), un Hash o un Array di coppie             |
| `body`         | `nil`           | un Hash o un Array con i nomi dell'API; enumerazioni, modelli e date vengono convertiti |
| `validate`     | nulla da verificare | segnala i problemi con `required`, `check`, `between`, `max_length`, `enum` |
| `decode(data)` | usa `returns`   | trasforma il JSON decodificato nel tuo risultato                            |

I segnaposto del percorso vengono riempiti con gli attributi e sottoposti a escape:
`endpoint :get, '/api/v1/contacts/{handle}'`.

La tua richiesta ottiene tutto ciò che ottengono quelle integrate: credenziali, tentativi ripetuti, controllo del ritmo,
normalizzazione degli errori, ID di correlazione, tracciamento e applicazione della modalità di sola lettura.
`client.execute(request)` restituisce l'intera `Response` (stato, header, corpo grezzo, ID di correlazione, quota,
tentativi) con il risultato decodificato in `value`. `client.prepare(request)` valida e costruisce l'esatta richiesta
HTTP senza inviarla, per registrare o rivedere una richiesta a pagamento prima che parta (la chiave API è mascherata in
`inspect`).

## Errori

| Errore                           | Quando                                                     | Metodi utili                                                                   |
|----------------------------------|------------------------------------------------------------|--------------------------------------------------------------------------------|
| `DomainNameApi::InputError`      | la validazione ha rifiutato la richiesta; **non è stato inviato nulla** | `request`, `fields`                                               |
| `DomainNameApi::APIError`        | l'API ha risposto con uno stato non 2xx                    | `status`, `code`, `api_message`, `details`, `fields`, `data`, `correlation_id`, `hint` |
| `DomainNameApi::OperationError`  | l'API ha risposto 2xx con `"success": false`               | `code`, `api_message`, `correlation_id`                                        |
| `DomainNameApi::NetworkError`    | la richiesta non è stata completata (DNS, TLS, timeout, reset) | `original`, `timeout?`                                                     |
| `DomainNameApi::ReadOnlyError`   | un client di sola lettura ha bloccato una modifica; non è stato inviato nulla | `safety`                                                    |

Tutti ereditano da `DomainNameApi::Error`, che risponde alle domande più comuni: `kind` (`:auth`,
`:not_found`, `:validation`, `:rejected`, `:conflict`, `:rate_limited`, `:server`, `:network`, `:invalid_input`,
`:read_only`), `not_found?`, `auth?`, `rate_limited?`, `insufficient_balance?`, `outcome_unknown?`,
`retryable?` e `code?(code)`.

```ruby
begin
  client.domains.renew('example.com', years: 1)
rescue DomainNameApi::Error => e
  if e.outcome_unknown?
    # Il rinnovo potrebbe essere andato a buon fine. Controlla il dominio prima di riprovare.
  elsif e.insufficient_balance?
  elsif e.not_found?
  elsif e.code?(DomainNameApi::ErrorCode::PRIVACY_NOT_SUPPORTED)
  elsif e.is_a?(DomainNameApi::APIError)
    logger.error("#{e.code} #{e.api_message} #{e.hint} #{e.correlation_id}")
  end
end
```

Distingui i casi in base a `code`, non al messaggio: i messaggi sono localizzati. I codici dell'API hanno questo
aspetto: `Dna.DomainService:Domain:10007`; quelli più comuni sono costanti in `DomainNameApi::ErrorCode`, gli altri si
trovano nel [riferimento degli errori](https://www.domainnameapi.com/docs/reference/errors.md). Indica il
`correlation_id` quando contatti il supporto.

## Sicurezza e affidabilità

- **Classi di sicurezza.** Ogni richiesta è `:read`, `:write`, `:destructive` o `:billable` (`request.safety`,
  `request.billable?`). Alcune richieste POST e PUT sono letture (`DomainSearchRequest`, `SSLStatusRequest`).
- **Modalità di sola lettura.** `read_only: true` blocca tutto ciò che non è una lettura, per i job di reportistica e
  per esplorare la produzione in sicurezza.
- **Tentativi ripetuti.** Le risposte 429 vengono sempre ritentate, rispettando `Retry-After`: l'API le rifiuta prima
  di fare qualsiasi cosa. Gli errori di rete e i 502/503/504 vengono ritentati solo per le letture e per le scritture
  idempotenti, così una registrazione o un rinnovo non viene mai inviato due volte. Dopo il fallimento di una richiesta
  a pagamento, controlla `e.outcome_unknown?`.
- **Controllo del ritmo.** Il client distanzia le richieste per restare entro i limiti per chiave (5 richieste/secondo,
  2 ricerche/secondo, una chiamata di zona al secondo). Disattivalo con `pacing: false` se regoli tu il ritmo.
- **Quota.** `client.execute(request).quota` espone gli header della quota soft. Oltre il limite l'API rallenta le
  risposte (fino a 5 s) invece di rifiutarle; il timeout predefinito di 60 s lascia margine per questo.
- **ID di correlazione.** Ogni richiesta porta un `X-Correlation-ID`. Imposta il tuo per collegare le chiamate API ai
  tuoi log: `DomainNameApi.with_correlation_id(job.id) { ... }` oppure `client.call(request, correlation_id: job.id)`.
- **Osservabilità.** `logger: Logger.new($stdout)` registra ogni scambio; `on_trace: ->(event) { ... }` ti consegna
  ogni richiesta, risposta e nuovo tentativo come `TraceEvent`, per metriche o segnalazione degli errori. La chiave API
  non vi compare mai; i corpi possono contenere dati di contatto, quindi mascherali prima di salvarli.
- **Thread.** Un client è sicuro da condividere tra thread. Creane uno e riutilizzalo.
- **Nient'altro lascia il tuo processo.** Nessuna telemetria, nessun servizio di terze parti.

## Opzioni del client

| Opzione                      | Effetto                                                                             |
|------------------------------|-------------------------------------------------------------------------------------|
| `environment: :ote`          | usa l'ambiente di test (predefinito `:production`)                                  |
| `base_url: 'https://...'`    | invia le richieste a un proxy o a un server di test                                 |
| `timeout: 60`                | secondi per tentativo HTTP                                                          |
| `open_timeout: 10`           | secondi per stabilire la connessione                                                |
| `user_agent: 'app/1.0'`      | antepone il tuo prodotto allo User-Agent                                            |
| `currency: 'TRY'`            | valuta dei prezzi di ricerca e del catalogo                                         |
| `retries: 2`                 | numero di tentativi                                                                 |
| `max_retry_wait: 30`         | il `Retry-After` più lungo che il client è disposto ad attendere                    |
| `pacing: false`              | disattiva il controllo del ritmo lato client                                        |
| `read_only: true`            | blocca ogni richiesta che non sia di lettura                                        |
| `logger: Logger.new($stdout)`| registra gli scambi: richieste a livello debug, tentativi ripetuti a livello warn, errori a livello error |
| `on_trace: ->(event) {}`     | osserva ogni richiesta, risposta e nuovo tentativo                                  |
| `transport: my_transport`    | il tuo livello HTTP (proxy, pool di connessioni, ...): qualsiasi oggetto con `call(request)` |

`DomainNameApi::NetHTTPTransport.new(proxy: 'http://proxy:8080', ca_file: 'corp-ca.pem')` è il transport predefinito
con un proxy o con il tuo bundle di CA. I redirect non vengono mai seguiti: l'API risponde 302 per un ID rivenditore
sconosciuto o sospeso, che diventa un errore di autenticazione.

## Testare il proprio codice

Passa un transport che risponde come l'API; non serve simulare nient'altro:

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

`request` è un `DomainNameApi::PreparedRequest` (`http_method`, `url`, `headers`, `body`), quindi il transport fittizio
può anche verificare ciò che è stato inviato. Funzionano anche WebMock e VCR, dato che il transport predefinito è
`Net::HTTP`.

## Migrare dalla v1

La v2 è un nuovo progetto: risultati tipizzati al posto di Hash con chiavi String, eccezioni al posto delle buste
`{'result' => 'ERROR'}` e l'API completa al posto dell'insieme di metodi di php-dna. Il nome della gem resta
`domainnameapi`; fissa `tag: 'v1.0.1'` per mantenere la v1 finché non passi alla v2.

| v1                                                   | v2                                                                       |
|------------------------------------------------------|--------------------------------------------------------------------------|
| `Client.new(id, key, true)`                          | `Client.new(reseller_id: id, api_key: key, environment: :ote)`           |
| `res['result'] == 'OK'`                              | nessuna eccezione                                                        |
| `get_reseller_details`, `get_current_balance`        | `account.get` (+ `account.balance('USD')`)                               |
| `check_availability`                                 | `domains.search`, `domains.bulk_search`                                  |
| `get_list`                                           | `domains.list`, `domains.all`                                            |
| `get_tld_list`                                       | `products.tlds`, `products.all_tlds`, `products.tld`                     |
| `get_details`, `get_contacts`, `sync_from_registry`  | `domains.info`                                                           |
| `register_with_contact_info`                         | `domains.register_with_contacts` (oppure `contacts.create` + `domains.register`) |
| `renew`, `transfer`, `check_transfer`                | `domains.renew`, `domains.transfer`, `domains.transfer_check`            |
| `modify_name_server`                                 | `domains.set_name_servers`                                               |
| `enable_theft_protection_lock` / `disable_...`       | `domains.lock` / `domains.unlock`                                        |
| `modify_privacy_protection_status`                   | `domains.set_privacy`                                                    |
| `save_contacts`                                      | `domains.update_contacts`, `domains.set_contact_handles`                 |
| `add_child_name_server`, `modify_child_name_server`, `delete_child_name_server` | `domains.add_host`, `domains.update_host`, `domains.delete_host` |
| `get_resource_records`                               | `dns.list`                                                               |
| `add_resource_record`, `add_resource_record_value`   | `dns.add`                                                                |
| `edit_resource_record`, `set_resource_record_set`, `replace_resource_record_value` | `dns.update`                               |
| `delete_resource_record`, `remove_resource_record_value`, `delete_resource_record_set` | `dns.delete` (una volta per valore)    |
| `apply_resource_records`                             | `dns.apply`                                                              |
| `get_forwarding`, `set_forwarding`, `delete_forwarding` | `domains.forwarding`, `domains.set_forwarding`, `domains.delete_forwarding` |
| `cancel_transfer`, `approve_transfer`, `reject_transfer` | non presenti nell'API pubblicata; invia una [richiesta personalizzata](#richieste-e-baserequest) se il tuo account le prevede |
| `is_tr_tld`, `validate_contact`                      | `name.end_with?('.tr')`; la validazione viene eseguita a ogni richiesta  |
| `get_request_data`, `get_response_data`, ...         | `on_trace:`, `logger:`, `client.execute(request)`                        |
| telemetria (`set_error_reporting_enabled`, Sentry)   | rimossa: nulla lascia il tuo processo; inoltra gli eventi di `on_trace` al tuo sistema di segnalazione |
| `set_ssl_verification(false)`                        | `transport: NetHTTPTransport.new(ca_file: ...)` con il tuo bundle di CA  |

## Sviluppo

```bash
bundle install
bundle exec rake test   # test unitari; nessuno accede alla rete
```

`test/fixtures/openapi.json` è il documento OpenAPI dell'API. I test verificano ogni classe di richiesta rispetto ad
esso (metodo, percorso, nomi delle query, campi del corpo, campi obbligatori), i nomi JSON di ogni modello di risposta
rispetto agli schemi di risposta e ogni valore di enumerazione, e falliscono quando l'API acquisisce un'operazione
senza una classe di richiesta. Per aggiornarlo:

```bash
curl -fsSL -A "ruby-dna-spec-update" -o test/fixtures/openapi.json https://api.domainresellerapi.com/swagger/v1/swagger.json
bundle exec rake test
```

Vedi [AGENTS.md](AGENTS.md) per le convenzioni di questo repository.

## Supporto

- Documentazione dell'API: <https://www.domainnameapi.com/docs/>
- CLI e server MCP: <https://github.com/domainreseller/cli>
- Sito web: <https://www.domainnameapi.com>

## Licenza

Apache License 2.0. Vedi [LICENSE](LICENSE).
