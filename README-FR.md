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

# ruby-dna : le SDK Ruby pour la Domain Name API

[![CI](https://github.com/domainreseller/ruby-dna/actions/workflows/ci.yml/badge.svg)](https://github.com/domainreseller/ruby-dna/actions/workflows/ci.yml)
[![License](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](LICENSE)

Client Ruby pour l'API REST revendeur de [Domain Name API](https://www.domainnameapi.com) : recherche de domaines,
enregistrement, renouvellement et transfert, DNS, DNSSEC, contacts, certificats SSL, hébergement, commandes, catalogue
de produits et solde.

- **Les 67 opérations de l'API**, regroupées comme dans la [CLI `dna`](https://github.com/domainreseller/cli) :
  `dna domain info` correspond à `client.domains.info`, `dna dns add` à `client.dns.add`.
- **De vrais objets, pas des hashes** : `domain.status.pending_delete?`, `domain.expiration_date` est un `Time`,
  `availability.available?`, `tld.register_price(1)`.
- **Chaque opération est une classe de requête** qui hérite de `DomainNameApi::BaseRequest` et se valide elle-même
  avant tout envoi. Écrivez les vôtres de la même façon.
- **Sûr par défaut** : les requêtes facturables ne sont jamais rejouées aveuglément, `read_only: true` bloque les
  modifications, le client se cadence sous les limites de débit et peut être partagé entre threads en toute sécurité.
- **Aucune dépendance.** Ruby 3.1 ou plus récent, bibliothèque standard uniquement.

```ruby
client = DomainNameApi::Client.new(reseller_id: reseller_id, api_key: api_key, environment: :ote)

a = client.domains.search('example.com')
puts "#{a.domain_name} is available for #{a.price} #{a.currency}" if a.available?
```

## Sommaire

- [Installation](#installation)
- [Identifiants et environnements](#identifiants-et-environnements)
- [Services](#services)
- [Utilisation](#utilisation)
- [Résultats, modèles et énumérations](#résultats-modèles-et-énumérations)
- [Requêtes et BaseRequest](#requêtes-et-baserequest)
- [Erreurs](#erreurs)
- [Sécurité et fiabilité](#sécurité-et-fiabilité)
- [Options du client](#options-du-client)
- [Tester votre code](#tester-votre-code)
- [Migrer depuis la v1](#migrer-depuis-la-v1)
- [Développement](#développement)

## Installation

> ⬇️ Utilisez une version taguée depuis les [Releases](https://github.com/domainreseller/ruby-dna/releases/latest). Le
> bouton vert **Code → Download ZIP** vous donne la branche de développement.

Avec Bundler :

```ruby
# Gemfile
gem 'domainnameapi', git: 'https://github.com/domainreseller/ruby-dna.git', tag: 'v2.2.0'
```

Ou installez le fichier `.gem` joint à la release :

```bash
gem install ./domainnameapi-2.2.0.gem
```

```ruby
require 'domainnameapi'
```

Des programmes exécutables se trouvent dans [examples](examples) : `quickstart`, `register`, `expiring`, `dns`, `ssl`
et `custom_request`.

```bash
DNA_RESELLER_ID=... DNA_API_KEY=... DNA_ENV=ote ruby examples/quickstart.rb example.com
```

## Identifiants et environnements

Vous avez besoin de deux identifiants d'API, disponibles dans le panneau revendeur (**API settings**). Les
identifiants de connexion au panneau ne fonctionnent pas.

| Identifiant | Aspect                                 |
|-------------|----------------------------------------|
| Reseller ID | `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx` |
| API key     | une longue chaîne secrète              |

Il existe deux environnements. **Commencez par OTE**, l'environnement de test : il possède ses propres données et sa
propre clé d'API, et rien de ce que vous y faites ne coûte d'argent ni n'affecte de domaines en production.

```ruby
# Environnement de test (OTE)
client = DomainNameApi::Client.new(reseller_id: reseller_id, api_key: ote_api_key, environment: :ote)

# Production (par défaut) : vrais enregistrements, vraie facturation
client = DomainNameApi::Client.new(reseller_id: reseller_id, api_key: api_key)
```

`environment:` accepte aussi les chaînes que stockent les panneaux : `'production'`, `'ote'`, `'test'`, ainsi que les
indicateurs de mode test (`'true'`, `'1'`, `true`). `Client.from_env` lit les mêmes variables que la CLI `dna` :

| Variable          | Signification                                                 |
|-------------------|---------------------------------------------------------------|
| `DNA_RESELLER_ID` | ID revendeur                                                  |
| `DNA_API_KEY`     | clé d'API de l'environnement sélectionné                      |
| `DNA_ENV`         | `production` (par défaut) ou `ote`                            |
| `DNA_TEST_MODE`   | `true` sélectionne OTE (comme dans les autres SDK DomainNameAPI) |
| `DNA_BASE_URL`    | une URL de base personnalisée, par ex. un proxy               |
| `DNA_APP`         | votre application, envoyée dans `X-App` (par défaut `ruby`)   |
| `DNA_APP_VERSION` | sa version, envoyée dans `X-Version` (par défaut : la version du gem) |

```ruby
client = DomainNameApi::Client.from_env(user_agent: 'my-panel/1.4')
```

Une clé ou un environnement incorrect échoue dès la première requête avec une `APIError` dont `auth?` vaut true et
dont `hint` indique ce qu'il faut contrôler ; `client.account.get` est le moyen le moins coûteux de vérifier.

## Services

| Service            | Groupe CLI    | Méthodes                                                                                                                                                          |
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

Les entrées obligatoires sont positionnelles (`info('example.com')`), tout le reste est un argument nommé
(`renew('example.com', years: 1)`). Les opérations comportant de nombreuses entrées facultatives acceptent des arguments
nommés ou un objet de requête : `register(domain_name: ..., years: 1, ...)` et
`register(DomainNameApi::DomainRegisterRequest.new(...))` sont équivalents. `ssl.purchase` correspond à la commande
`dna ssl initialize` de la CLI (`initialize` est réservé en Ruby).

## Utilisation

Tous les extraits supposent un `client`.

### Recherche

```ruby
a = client.domains.search('example.com')
a.available?            # a.price, a.currency, a.premium?, a.document_required?, a.reason

client.domains.bulk_search('example.com', 'example.net', 'example.org').each do |r|
  puts "#{r.domain_name} #{r.status} #{r.price}"
end
```

`bulk_search` découpe les listes de plus de 30 domaines en plusieurs requêtes. Les prix sont exprimés dans la devise du
compte, dans celle de l'option `currency: 'TRY'` du client, ou via `search('example.com', currency: 'USD')`.

### Enregistrement

Avec des identifiants de contact (créez-en un avec `contacts.create`) :

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
  handles: handle # un seul identifiant pour les quatre rôles, ou { registrant: 'DNA-1', admin: 'DNA-2', tech: ..., billing: ... }
)
result.status           # result.domain_id, result.expiration_date
```

Avec des contacts en ligne :

```ruby
client.domains.register_with_contacts(
  domain_name: 'example.com',
  name_servers: %w[ns1.example.net ns2.example.net],
  contacts: owner # un seul Contact pour les quatre rôles, ou { registrant: owner, admin: admin, tech: admin, billing: admin }
)
```

Les contacts peuvent être des objets `DomainNameApi::Contact` ou des Hash contenant les mêmes champs. Ils sont
normalisés avant l'envoi : les champs sont débarrassés des espaces superflus, le pays est mis en majuscules et les
champs de téléphone ne conservent que leurs chiffres (`'+90 (555) 123-45-67'` fonctionne). Certains TLD exigent des
attributs de registre : trouvez-les avec `client.products.tld('com.tr').required_attributes` et transmettez-les via
`tld_attributes:`.

Si l'API répond mais refuse l'opération (`"success": false`), la méthode lève une `DomainNameApi::OperationError`
portant le message de l'API.

### Renouvellement, transfert, restauration

```ruby
check = client.domains.renew_check('example.com', years: 1)   # check.renewable?, check.premium_price
client.domains.renew('example.com', years: 1)

tc = client.domains.transfer_check('example.com', 'auth-code') # tc.transferable?, tc.auth_code_valid?
client.domains.transfer('example.com', auth_code: 'auth-code')
client.domains.transfer_status('example.com').status

client.domains.restore('example.com') # pendant la période de rédemption
```

### Détails d'un domaine et liste des domaines

```ruby
d = client.domains.info('example.com')
d.status                # => #<DomainNameApi::DomainStatus Active (0)>
d.expiration_date       # => 2027-03-15 10:20:30 UTC
d.remaining_days, d.locked?, d.privacy_protection?, d.name_servers, d.auth_code, d.hosts
d.contact(:registrant)&.email

# Une page
page = client.domains.list(limit: 50, sort: 'expirationDate')
page.total_count
page.each { |domain| puts domain.domain_name }

# Tous les domaines ; les pages sont récupérées au fur et à mesure
client.domains.all(statuses: [:active]) do |domain|
  puts "#{domain.domain_name} #{domain.expiration_date}"
end
client.domains.all.first(10) # un Enumerator sans bloc : ne récupère qu'une seule page
```

### Verrouillage, confidentialité, serveurs de noms, serveurs de noms enfants

```ruby
client.domains.lock('example.com')
client.domains.unlock('example.com')
client.domains.set_privacy('example.com', true)
code = client.domains.update_auth_code('example.com')

client.domains.set_name_servers('example.com', %w[ns1.example.net ns2.example.net])
client.domains.set_name_servers('example.com', %w[ns1.other.net ns2.other.net], dnssec_mode: :disable) # domaines signés avec DNSSEC

client.domains.add_host('example.com', 'ns1.example.com', '192.0.2.10', '2001:db8::10') # version IP détectée
client.domains.update_host('example.com', 'ns1.example.com', ip_addresses: ['192.0.2.20'])
client.domains.delete_host('example.com', 'ns1.example.com')
```

### Contacts d'un domaine

```ruby
client.domains.set_contact_handles('example.com', admin: 'DNA-2', tech: 'DNA-2') # les autres rôles restent inchangés
client.domains.update_contacts('example.com', billing: billing_contact)

details = client.contacts.get('DNA-1')               # le contact et son état de vérification
result = client.contacts.update('DNA-1', contact)    # met à jour tous les domaines utilisant l'identifiant
result.affected_domains.each { |a| puts "#{a.domain_name} #{a.new_handle}" }
client.contacts.resend_verification('DNA-1')          # false lorsqu'il n'y a rien à vérifier
```

### Zone DNS

```ruby
client.dns.add('example.com', name: 'www', type: :a, values: '192.0.2.10', ttl: 600)
client.dns.update('example.com', record_name: 'www', type: :a, values: %w[192.0.2.20 192.0.2.21]) # remplace tout le jeu
client.dns.delete('example.com', name: 'www', type: :a, value: '192.0.2.20')

client.dns.list('example.com').each do |set|
  puts "#{set.name} #{set.type} #{set.ttl} #{set.values.join(', ')}"
end

client.dns.apply('example.com') # bascule le domaine sur les serveurs de noms de la plateforme
```

Les noms peuvent être relatifs (`'www'`), l'apex (`''` ou `'@'`) ou complets (FQDN). Les types d'enregistrement sont
des symboles ou des chaînes, quelle que soit la casse (`:txt` et `'txt'` sont envoyés comme `TXT`). La validation
détecte ce que l'API rejetterait : un CNAME à l'apex, une valeur CAA sans trois parties, une valeur MX sans priorité, un
enregistrement A avec une adresse IPv6. L'environnement de test répond à chaque appel de zone par un HTTP 500 ; le code
de zone ne peut donc être essayé qu'en production.

### DNSSEC

```ruby
results = client.dnssec.add('example.com', '2371 13 2 1F987CC6583E92DF0890718C42...') # tel que l'affiche votre fournisseur DNS
info = client.dnssec.get('example.com') # info.status.signed?, info.ds_records
client.dnssec.disable('example.com')
```

`DomainNameApi::DS.parse` lit le format de présentation et des lignes entières de fichier de zone ; `DS.new(key_tag: ...,
algorithm: :ecdsa_p256_sha256, digest_type: :sha256, digest: '...')` fonctionne également.

### Redirection d'URL

```ruby
client.domains.set_forwarding('example.com', 'https://www.example.org')              # redirection 301
client.domains.set_forwarding('example.com', 'https://www.example.org', type: :frame) # redirection masquée
f = client.domains.forwarding('example.com') # nil lorsque le domaine n'en a pas
client.domains.delete_forwarding('example.com')
```

### Documents du registre (.tr)

```ruby
doc = DomainNameApi::DocumentUpload.from_file(:identity_card, 'id.pdf')
client.domains.upload_documents('example.com.tr', doc)
client.domains.documents('example.com.tr').each { |d| puts "#{d.name} #{d.status}" }
```

Les fichiers sont encodés en base64 pour vous ; le format (PDF, JPG, PNG, DOC, DOCX, ODT) et la taille (10 Mo par
fichier, 50 Mo par requête) sont vérifiés avant l'envoi.

### Certificats SSL

```ruby
csr = client.ssl.generate_csr(domain_name: 'example.com', country: 'TR', state: 'Istanbul', locality: 'Istanbul',
                              organization: 'Example Ltd', organization_unit: 'IT')
# débite le solde (CLI : dna ssl initialize)
order = client.ssl.purchase('example.com', package_code: 'PositiveSSL')
id = order.certificate_id # conservez-le : chaque appel suivant l'attend
client.ssl.configure(certificate_id: id, csr: csr.csr, approver_mail: 'admin@example.com',
                     authentication_type: :email, web_server_type: :apache, contact: ssl_contact)
client.ssl.status(id).issued? # interrogez jusqu'à obtenir true
File.write('example.com.crt', client.ssl.content(id).chain)
```

Un domaine peut avoir plusieurs certificats : un certificat existant est donc désigné par son `certificate_id`
(un GUID), jamais par son nom de domaine. `purchase` et `renew` le renvoient, et `list` permet de le retrouver.
Un nom de domaine fourni à la place d'un identifiant lève une `InputError` avant tout envoi. Configurez un
certificat dans les 15 jours suivant son achat ou son renouvellement.

```ruby
client.ssl.list(domain_name: 'example.com').each { |c| puts "#{c.certificate_id} #{c.status}" } # les plus récents d'abord
client.ssl.all { |c| puts "#{c.domain_name} #{c.subscription_expires_at}" } # tous les certificats, page par page

client.ssl.approvers(certificate_id: id)                                      # pour un certificat existant
client.ssl.approvers(domain_name: 'example.com', package_code: 'PositiveSSL') # avant un achat

renewal = client.ssl.renew(id) # débite le solde ; possible à partir de 30 jours avant la fin de l'abonnement
client.ssl.configure(certificate_id: renewal.certificate_id, csr: new_csr.csr, approver_mail: 'admin@example.com',
                     authentication_type: :email, web_server_type: :apache, contact: ssl_contact)
```

Pour renouveler, appelez `renew`, puis `configure` sur le nouveau certificat renvoyé. N'appelez pas `purchase`
une nouvelle fois : ce serait une nouvelle commande sans lien, au prix d'achat, et l'ancien certificat ne
passerait jamais à l'état `Renewed`.

### Hébergement

```ruby
client.hosting.packages.each { |p| puts p.service_plans.map(&:service_plan) }
created = client.hosting.create('example.com', service_plan: 'Linux-Starter') # débite le solde

st = client.hosting.wait(created.service_id, timeout: 30 * 60) # interroge jusqu'à l'activation
puts st.panel_address, st.username, st.password
```

N'appelez jamais `create` une seconde fois pour un hébergement encore en cours de provisionnement : cela facture deux
fois.

### Solde, prix et commandes

```ruby
account = client.account.get
account.balance('USD')
profile = client.account.profile # profile.company_name, profile.account_currency, profile.status.active?

client.account.all_transactions(from: Date.new(2026, 11, 1)) do |tx|
  puts "#{tx.creation_time} #{tx.type} #{tx.change}"
end

tld = client.products.tld('com.tr')
tld&.register_price(1)&.to_s   # => "12.50 USD"

client.products.info('com', order_type: :renew, years: 2) # prix d'un renouvellement de .com sur 2 ans
client.orders.get('ORDER-CODE')
```

## Résultats, modèles et énumérations

Chaque résultat est un `DomainNameApi::Model` : des accesseurs en snake_case, des prédicats `?` pour les indicateurs,
des objets `Time` pour les dates, des modèles imbriqués et des listes.

```ruby
d = client.domains.info('example.com')
d.locked?                 # aussi d.locked
d.hosts.first.ip_addresses.first.address
d.to_h                    # un Hash simple avec des clés en snake_case
d.raw                     # l'objet JSON tel que l'API l'a envoyé, pour les champs que cette gem ne modélise pas
```

Les valeurs numériques et les chaînes fixes sont des énumérations (`DomainStatus`, `RecordType`, `ContactType`,
`DocumentType`, ...) :

```ruby
d.status.pending_delete?                       # un prédicat par membre
d.status == DomainNameApi::DomainStatus::ACTIVE
d.status == :active                            # les symboles, les noms et les nombres se comparent aussi
d.status.to_s                                  # => "Active"
d.status.to_i                                  # => 0
DomainNameApi::DomainStatus.members            # tous les membres
```

Les requêtes acceptent des énumérations, des symboles, des noms quelle que soit la casse ou des nombres :
`statuses: [:active, 'PendingDelete', 7]`.

Le décodage est tolérant : les dates sans fuseau horaire, `null`, `[]` au lieu de `{}`, les nombres envoyés sous forme
de chaînes, les rôles quelle que soit la casse (`"registrant"`, `"ADMINISTRATIVE"`) et les valeurs que cette gem ne
connaît pas encore sont tous décodés au lieu de faire échouer l'appel (`status.known?` vaut false pour ces dernières).

## Requêtes et BaseRequest

Chaque opération de l'API est une classe de requête : `DomainInfoRequest`, `DNSAddRequest`, `SSLConfigureRequest`,
... nommée d'après la commande de la CLI (`dna domain renew` correspond à `DomainRenewRequest`). Toutes héritent de
`DomainNameApi::BaseRequest`, qui fournit la mécanique : un DSL `endpoint` et `attribute` au niveau de la classe, une
initialisation par arguments nommés, des aides à la validation, des modèles de chemin et des constructeurs de query et
de corps. Les requêtes de liste héritent de `PagedRequest`, qui ajoute `skip`, `limit` et `sort`. Une requête de cette
gem ressemble à ceci :

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

Les méthodes des services les construisent pour vous. `client.call` envoie n'importe quelle requête, y compris vos
propres classes, par exemple pour ne lire que les champs dont vous avez besoin ou pour appeler un endpoint que cette
gem n'encapsule pas encore :

```ruby
class Expiry < DomainNameApi::Model
  field :expiration_date, :time
  field :remaining_days, :integer, from: 'remainingDay'
end

class ExpiryRequest < DomainNameApi::BaseRequest
  endpoint :get, '/api/v1/domains/info', safety: :read
  returns Expiry            # omettez-le pour obtenir le JSON décodé
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

| Redéfinition   | Par défaut      | Rôle                                                                        |
|----------------|-----------------|-----------------------------------------------------------------------------|
| `query`        | `nil`           | un `Query` (`params.string(...)`), un Hash ou un Array de paires            |
| `body`         | `nil`           | un Hash ou un Array avec les noms de l'API ; énumérations, modèles et dates sont convertis |
| `validate`     | rien à vérifier | signale les problèmes avec `required`, `check`, `between`, `max_length`, `enum` |
| `decode(data)` | utilise `returns` | transforme le JSON décodé en votre résultat                               |

Les espaces réservés du chemin sont remplis à partir des attributs et échappés :
`endpoint :get, '/api/v1/contacts/{handle}'`.

Votre requête bénéficie de tout ce dont bénéficient les requêtes intégrées : identifiants, nouvelles tentatives,
cadencement, normalisation des erreurs, identifiants de corrélation, traçage et application du mode lecture seule.
`client.execute(request)` renvoie la `Response` complète (statut, en-têtes, corps brut, identifiant de corrélation,
quota, tentatives) avec le résultat décodé dans `value`. `client.prepare(request)` valide et construit la requête HTTP
exacte sans l'envoyer, pour journaliser ou relire une requête facturable avant son départ (la clé d'API est masquée
dans `inspect`).

## Erreurs

| Erreur                           | Quand                                                      | Méthodes utiles                                                                |
|----------------------------------|------------------------------------------------------------|--------------------------------------------------------------------------------|
| `DomainNameApi::InputError`      | la validation a rejeté la requête ; **rien n'a été envoyé** | `request`, `fields`                                                           |
| `DomainNameApi::APIError`        | l'API a répondu avec un statut non 2xx                     | `status`, `code`, `api_message`, `details`, `fields`, `data`, `correlation_id`, `hint` |
| `DomainNameApi::OperationError`  | l'API a répondu 2xx avec `"success": false`                | `code`, `api_message`, `correlation_id`                                        |
| `DomainNameApi::NetworkError`    | la requête n'a pas abouti (DNS, TLS, délai dépassé, réinitialisation) | `original`, `timeout?`                                              |
| `DomainNameApi::ReadOnlyError`   | un client en lecture seule a bloqué une modification ; rien n'a été envoyé | `safety`                                                       |

Toutes héritent de `DomainNameApi::Error`, qui répond aux questions courantes : `kind` (`:auth`,
`:not_found`, `:validation`, `:rejected`, `:conflict`, `:rate_limited`, `:server`, `:network`, `:invalid_input`,
`:read_only`), `not_found?`, `auth?`, `rate_limited?`, `insufficient_balance?`, `outcome_unknown?`,
`retryable?` et `code?(code)`.

```ruby
begin
  client.domains.renew('example.com', years: 1)
rescue DomainNameApi::Error => e
  if e.outcome_unknown?
    # Le renouvellement a peut-être abouti. Vérifiez le domaine avant de réessayer.
  elsif e.insufficient_balance?
  elsif e.not_found?
  elsif e.code?(DomainNameApi::ErrorCode::PRIVACY_NOT_SUPPORTED)
  elsif e.is_a?(DomainNameApi::APIError)
    logger.error("#{e.code} #{e.api_message} #{e.hint} #{e.correlation_id}")
  end
end
```

Branchez-vous sur `code`, pas sur le message : les messages sont localisés. Les codes de l'API ressemblent à
`Dna.DomainService:Domain:10007` ; les plus courants sont des constantes de `DomainNameApi::ErrorCode`, les autres se
trouvent dans la [référence des erreurs](https://www.domainnameapi.com/docs/reference/errors.md). Indiquez le
`correlation_id` lorsque vous contactez le support.

## Sécurité et fiabilité

- **Classes de sécurité.** Chaque requête est `:read`, `:write`, `:destructive` ou `:billable` (`request.safety`,
  `request.billable?`). Certaines requêtes POST et PUT sont des lectures (`DomainSearchRequest`, `SSLStatusRequest`).
- **Mode lecture seule.** `read_only: true` bloque tout ce qui n'est pas une lecture, pour les tâches de reporting et
  pour explorer la production en toute sécurité.
- **Nouvelles tentatives.** Les réponses 429 sont toujours rejouées, en respectant `Retry-After` : l'API les rejette
  avant de rien faire. Les erreurs réseau et les 502/503/504 ne sont rejouées que pour les lectures et les écritures
  idempotentes, de sorte qu'un enregistrement ou un renouvellement n'est jamais envoyé deux fois. Après l'échec d'une
  requête facturable, vérifiez `e.outcome_unknown?`.
- **Cadencement.** Le client espace les requêtes pour rester sous les limites par clé (5 requêtes/seconde,
  2 recherches/seconde, un appel de zone par seconde). Désactivez-le avec `pacing: false` si vous cadencez vous-même.
- **Quota.** `client.execute(request).quota` expose les en-têtes de quota souple. Au-delà de la limite, l'API ralentit
  les réponses (jusqu'à 5 s) au lieu de les rejeter ; le délai d'expiration par défaut de 60 s laisse de la marge pour
  cela.
- **Identifiants de corrélation.** Chaque requête porte un `X-Correlation-ID`. Définissez le vôtre pour relier les
  appels d'API à vos journaux : `DomainNameApi.with_correlation_id(job.id) { ... }` ou
  `client.call(request, correlation_id: job.id)`.
- **Observabilité.** `logger: Logger.new($stdout)` journalise chaque échange ; `on_trace: ->(event) { ... }` vous
  transmet chaque requête, réponse et nouvelle tentative sous forme de `TraceEvent`, pour les métriques ou le suivi des
  erreurs. La clé d'API n'y figure jamais ; les corps peuvent contenir des données de contact, masquez-les donc avant
  de les stocker.
- **Threads.** Un client peut être partagé entre threads en toute sécurité. Créez-en un et réutilisez-le.
- **Rien d'autre ne quitte votre processus.** Aucune télémétrie, aucun service tiers.

## Options du client

| Option                       | Effet                                                                               |
|------------------------------|-------------------------------------------------------------------------------------|
| `environment: :ote`          | utilise l'environnement de test (par défaut `:production`)                          |
| `base_url: 'https://...'`    | envoie les requêtes à un proxy ou à un serveur de test                              |
| `timeout: 60`                | secondes par tentative HTTP                                                         |
| `open_timeout: 10`           | secondes pour établir la connexion                                                  |
| `user_agent: 'app/1.0'`      | place votre produit devant le User-Agent                                            |
| `app_name: 'whmcs'`          | votre application, envoyée dans l'en-tête `X-App` (par défaut `ruby`)               |
| `app_version: '8.13.1'`      | sa version, envoyée dans l'en-tête `X-Version` (par défaut : la version du gem)     |
| `currency: 'TRY'`            | devise des prix de recherche et du catalogue                                        |
| `retries: 2`                 | nombre de nouvelles tentatives                                                      |
| `max_retry_wait: 30`         | le `Retry-After` le plus long que le client accepte d'attendre                      |
| `pacing: false`              | désactive le cadencement côté client                                                |
| `read_only: true`            | bloque toute requête qui n'est pas une lecture                                      |
| `logger: Logger.new($stdout)`| journalise les échanges : requêtes au niveau debug, nouvelles tentatives au niveau warn, échecs au niveau error |
| `on_trace: ->(event) {}`     | observe chaque requête, réponse et nouvelle tentative                               |
| `transport: my_transport`    | votre propre couche HTTP (proxy, pool de connexions, ...) : tout objet doté de `call(request)` |

`DomainNameApi::NetHTTPTransport.new(proxy: 'http://proxy:8080', ca_file: 'corp-ca.pem')` est le transport par défaut
avec un proxy ou votre propre bundle de CA. Les redirections ne sont jamais suivies : l'API répond 302 pour un ID
revendeur inconnu ou suspendu, ce qui devient une erreur d'authentification.

### Identifier votre intégration

Chaque requête porte deux en-têtes qui indiquent à l'API quelle application l'envoie : `X-App` (par défaut
`ruby`) et `X-Version` (par défaut : la version du gem). Renseignez-les avec votre panel ou votre module et
sa version :

```ruby
client = DomainNameApi::Client.new(reseller_id: reseller_id, api_key: api_key,
                                   app_name: 'WiseCP', app_version: 'V2.0.20-beta')
# X-App: wisecp, X-Version: 2.0.20
```

Le nom est mis en minuscules et seuls `a-z`, `0-9`, `.`, `_` et `-` sont conservés ; la version ne garde que
les chiffres et les points. Un nom vide revient à `ruby`, une version vide à la version du gem.
`Client.from_env` les lit dans `DNA_APP` et `DNA_APP_VERSION`. Le User-Agent ne change pas.

## Tester votre code

Passez un transport qui répond comme l'API ; rien d'autre n'a besoin d'être simulé :

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

`request` est une `DomainNameApi::PreparedRequest` (`http_method`, `url`, `headers`, `body`) ; le faux transport peut
donc aussi vérifier ce qui a été envoyé. WebMock et VCR fonctionnent également, puisque le transport par défaut est
`Net::HTTP`.

## Migrer depuis la v1

La v2 est une nouvelle conception : des résultats typés au lieu de Hash à clés String, des exceptions au lieu
d'enveloppes `{'result' => 'ERROR'}`, et l'API complète au lieu de l'ensemble de méthodes de php-dna. Le nom de la gem
reste `domainnameapi` ; fixez `tag: 'v1.0.1'` pour conserver la v1 jusqu'à ce que vous changiez.

| v1                                                   | v2                                                                       |
|------------------------------------------------------|--------------------------------------------------------------------------|
| `Client.new(id, key, true)`                          | `Client.new(reseller_id: id, api_key: key, environment: :ote)`           |
| `res['result'] == 'OK'`                              | aucune exception                                                         |
| `get_reseller_details`, `get_current_balance`        | `account.get` (+ `account.balance('USD')`)                               |
| `check_availability`                                 | `domains.search`, `domains.bulk_search`                                  |
| `get_list`                                           | `domains.list`, `domains.all`                                            |
| `get_tld_list`                                       | `products.tlds`, `products.all_tlds`, `products.tld`                     |
| `get_details`, `get_contacts`, `sync_from_registry`  | `domains.info`                                                           |
| `register_with_contact_info`                         | `domains.register_with_contacts` (ou `contacts.create` + `domains.register`) |
| `renew`, `transfer`, `check_transfer`                | `domains.renew`, `domains.transfer`, `domains.transfer_check`            |
| `modify_name_server`                                 | `domains.set_name_servers`                                               |
| `enable_theft_protection_lock` / `disable_...`       | `domains.lock` / `domains.unlock`                                        |
| `modify_privacy_protection_status`                   | `domains.set_privacy`                                                    |
| `save_contacts`                                      | `domains.update_contacts`, `domains.set_contact_handles`                 |
| `add_child_name_server`, `modify_child_name_server`, `delete_child_name_server` | `domains.add_host`, `domains.update_host`, `domains.delete_host` |
| `get_resource_records`                               | `dns.list`                                                               |
| `add_resource_record`, `add_resource_record_value`   | `dns.add`                                                                |
| `edit_resource_record`, `set_resource_record_set`, `replace_resource_record_value` | `dns.update`                               |
| `delete_resource_record`, `remove_resource_record_value`, `delete_resource_record_set` | `dns.delete` (une fois par valeur)     |
| `apply_resource_records`                             | `dns.apply`                                                              |
| `get_forwarding`, `set_forwarding`, `delete_forwarding` | `domains.forwarding`, `domains.set_forwarding`, `domains.delete_forwarding` |
| `cancel_transfer`, `approve_transfer`, `reject_transfer` | absent de l'API publiée ; envoyez une [requête personnalisée](#requêtes-et-baserequest) si votre compte les propose |
| `is_tr_tld`, `validate_contact`                      | `name.end_with?('.tr')` ; la validation s'exécute sur chaque requête     |
| `get_request_data`, `get_response_data`, ...         | `on_trace:`, `logger:`, `client.execute(request)`                        |
| télémétrie (`set_error_reporting_enabled`, Sentry)   | supprimée : rien ne quitte votre processus ; transmettez les événements `on_trace` à votre propre outil de suivi |
| `set_ssl_verification(false)`                        | `transport: NetHTTPTransport.new(ca_file: ...)` avec votre propre bundle de CA |

## Développement

```bash
bundle install
bundle exec rake test   # tests unitaires ; aucun n'accède au réseau
```

`test/fixtures/openapi.json` est le document OpenAPI de l'API. Les tests vérifient chaque classe de requête par rapport
à lui (méthode, chemin, noms de query, champs du corps, champs obligatoires), les noms JSON de chaque modèle de réponse
par rapport aux schémas de réponse ainsi que chaque valeur d'énumération, et échouent lorsque l'API gagne une opération
sans classe de requête. Pour le mettre à jour :

```bash
curl -fsSL -A "ruby-dna-spec-update" -o test/fixtures/openapi.json https://api.domainresellerapi.com/swagger/v1/swagger.json
bundle exec rake test
```

Voir [AGENTS.md](AGENTS.md) pour les conventions de ce dépôt.

## Support

- Documentation de l'API : <https://www.domainnameapi.com/docs/>
- CLI et serveur MCP : <https://github.com/domainreseller/cli>
- Site web : <https://www.domainnameapi.com>

## Licence

Apache License 2.0. Voir [LICENSE](LICENSE).
