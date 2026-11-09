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

# ruby-dna — client DomainNameAPI pour Ruby

Enregistrez, renouvelez et transférez des domaines, gérez les contacts, les serveurs de noms, les serveurs de noms enfants, les zones DNS et la redirection d'URL via l'API REST DomainNameAPI. `ruby-dna` est un portage fidèle de [php-dna](https://github.com/domainreseller/php-dna) : les mêmes méthodes, les mêmes requêtes envoyées sur le réseau et les mêmes valeurs de retour, vérifiées à l'aide des fixtures de conformité de php-dna.

## 📦 Téléchargement — utilisez toujours les Releases !

⬇️ **Téléchargez la dernière version testée ici : https://github.com/domainreseller/ruby-dna/releases/latest**

> ⚠️ N'utilisez **pas** le bouton vert **Code → Download ZIP** — il télécharge la branche de développement brute. Les paquets de release sont versionnés, testés et prêts pour la production.

## Guide d'Installation et d'Intégration

### Exigences Minimales

- Ruby 2.7 ou supérieur (Recommandé 3.3+)
- Aucune dépendance d'exécution : uniquement la bibliothèque standard (`net/http`, `json`, `openssl`).

### A) Bundler

```ruby
# Gemfile
gem 'domainnameapi', git: 'https://github.com/domainreseller/ruby-dna.git', tag: 'v1.0.0'
```

```bash
bundle install
```

### B) Fichier gem de la release

Téléchargez `domainnameapi-1.0.0.gem` depuis la [dernière release](https://github.com/domainreseller/ruby-dna/releases/latest), puis :

```bash
gem install ./domainnameapi-1.0.0.gem
```

### C) Utilisation manuelle

Téléchargez l'archive de la release, copiez le dossier `lib` dans votre projet et examinez les exemples dans le dossier [examples](examples) :

```ruby
$LOAD_PATH.unshift File.expand_path('lib', __dir__)
require 'domainnameapi'
```

## 🔑 Identifiants API — Reseller ID et API Key

La bibliothèque communique avec l'API REST DomainNameAPI et n'a besoin que de deux identifiants, transmis au constructeur :

| Paramètre | Valeur |
|---|---|
| Premier | Reseller ID — UUID de la forme `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx` |
| Second | API Key |

> 💡 Vous trouverez votre **Reseller ID** et votre **API Key** dans votre panel DomainNameAPI, sous **Paramètres API**.
> ⚠️ Ce sont des **identifiants API** — vos identifiants de connexion au panel **ne fonctionneront pas** ici.

## Démarrage rapide

```ruby
require 'domainnameapi'

reseller_id = 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx'
api_key     = 'your-api-key'

# Environnement de production
dna = DomainNameApi::Client.new(reseller_id, api_key)

# Environnement de test (OTE)
dna = DomainNameApi::Client.new(reseller_id, api_key, true)

result = dna.get_details('example.com')
if result['result'] == 'OK'
  puts result['data']['Dates']['Expiration']
else
  puts "#{result['error']['Code']}: #{result['error']['Message']}"
end
```

Les noms de méthodes sont la forme snake_case de ceux de php-dna (`getDetails` → `get_details`, `registerWithContactInfo` → `register_with_contact_info`), avec le même ordre de paramètres et les mêmes valeurs par défaut. Les résultats sont de simples Hash et Array Ruby avec des **clés de type String**, exactement la structure que renvoie php-dna (y compris les indicateurs sous forme de chaîne comme `'LockStatus' => 'true'` et les prix formatés comme `'11.9900'`). Les identifiants sont débarrassés de leurs espaces, et l'indicateur de mode test accepte aussi des chaînes : `"true"`, `"1"`, `"on"` et `"yes"` signifient le mode test, toute autre valeur signifie la production.

## Gestion des erreurs

Les méthodes ne lèvent jamais d'exception pour les problèmes d'API ou de réseau. Un appel en échec renvoie une enveloppe d'erreur :

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

- `Code` vaut `API_<statut HTTP>` pour les erreurs de la passerelle (`API_400`, `API_401`, `API_429`, `API_500`, ...). Une réponse `301`/`302` signifie des identifiants incorrects (`Invalid API credentials`).
- Lorsque la passerelle envoie son propre code d'erreur, l'enveloppe le transporte également dans `GatewayCode` (par ex. `'GatewayCode' => 'Dna.DomainService:Domain:10007'`), ce qui permet de distinguer un `API_404` d'un autre.
- Un corps d'erreur vide devient un message lisible tel que `HTTP 429 - Too Many Requests`. Le corps brut de la réponse n'est jamais utilisé comme message lorsque le message de la passerelle est générique ; un texte stable mentionnant le code de la passerelle est utilisé à la place.
- Les erreurs de validation des champs sont aplaties dans `Details`, par ex. `Admin PostalCode - 'PostalCode' is required`.
- Les défaillances réseau sont des erreurs, jamais un succès vide. Un dépassement de délai donne `Could not reach the DomainNameAPI service: the connection timed out. (...)` ; les autres défaillances de transport donnent `Curl error during request: ...`. Leurs codes sont de la forme `CURL_<n>` avec les numéros de curl (`CURL_28` délai dépassé, `CURL_6` DNS, `CURL_7` connexion refusée, `CURL_35`/`CURL_60` TLS, `CURL_56` connexion réinitialisée) ; `API_<n>` est réservé aux statuts HTTP.
- Un enregistrement, un transfert ou un renouvellement auquel la passerelle répond par HTTP 200 mais avec `"success": false` est un refus, pas un succès : la méthode renvoie l'enveloppe d'erreur avec le code `REGISTER_DOMAIN`, `TRANSFER_DOMAIN` ou `RENEW_DOMAIN` et le message de la passerelle.
- `get_current_balance` conserve sa propre enveloppe : `'OperationResult' => 'FAILED'` avec `ErrorCode` et `OperationMessage`.
- `check_availability` renvoie une simple liste en cas de succès et l'enveloppe d'erreur en cas d'échec.

Seules les erreurs de programmation lèvent une exception (par exemple `set_resource_record_set` avec un `contents` qui n'est pas une liste lève `TypeError`).

Les délais d'expiration sont de 30 secondes par appel et de 10 secondes pour la connexion. Les appels aux points de terminaison de zone DNS sont espacés d'au moins une seconde, car la passerelle répond `HTTP 429` aux rafales de requêtes.

### Diagnostic

```ruby
dna.get_request_data         # { 'url' => ..., 'method' => 'GET', 'payload' => {...} } du dernier appel
dna.get_response_data        # dernier corps de réponse décodé (ou { 'raw_response' => body })
dna.get_response_headers     # { 'url', 'http_code', 'headers', 'total_time' }
dna.get_parsed_response_data # dernier corps analysé, ou la dernière erreur { 'Code', 'Message', 'Details' }
dna.get_last_function        # par ex. 'request:GET domains/info'
dna.get_service_url          # https://api.domainresellerapi.com/api/v1
dna.set_service_url('https://ote.domainresellerapi.com/api/v1')
```

## Mode test

Passez `true` comme troisième argument du constructeur pour utiliser la passerelle de test OTE (`https://ote.domainresellerapi.com/api/v1`). Les appels en production sont envoyés à `https://api.domainresellerapi.com/api/v1`. Le mode test utilise des identifiants de test distincts.

## Rapports d'erreurs (télémétrie)

Lorsqu'un appel API échoue, la bibliothèque peut envoyer un rapport d'erreur au système de suivi des erreurs de DomainNameAPI (Sentry). Une petite part aléatoire des appels réussis (4 %, plus chaque appel de plus d'une seconde) peut être envoyée comme enregistrement de performance. Cela aide DomainNameAPI à trouver et corriger les problèmes. Les rapports d'erreurs sont **activés par défaut**.

> ℹ️ Dans la version 1.0.0, le projet Sentry de ruby-dna n'existe pas encore : le DSN intégré est donc vide et **rien n'est envoyé**. Les rapports commenceront lorsqu'une release embarquera le DSN. `DomainNameApi::Client.new(id, key, false, sentry_dsn: '...')` permet d'en définir un explicitement.

**Ce qui est envoyé :**

- le code et le message d'erreur
- le chemin du point de terminaison appelé et la méthode HTTP
- la durée de l'appel
- le nom de la bibliothèque (`DomainNameAPI-Ruby`), la version de la bibliothèque et la version de Ruby
- l'ID revendeur et le nom de domaine
- l'adresse IP publique du serveur (obtenue via `api.ipify.org`, en arrière-plan)
- le nom de l'utilisateur du système d'exploitation sous lequel tourne le processus
- la requête et la réponse API, y compris les coordonnées de contact du domaine ; seuls les identifiants sont masqués — les codes EPP/auth, clés API, mots de passe et jetons sont remplacés par `***`

**Ce qui n'est jamais envoyé :** les codes EPP/auth, clés API, mots de passe ou jetons sous forme lisible ; les arguments des méthodes dans les traces de pile (stack traces).

Les erreurs attendues et très fréquentes (domaine introuvable, solde insuffisant, identifiants invalides, ...) ne sont pas signalées. Les rapports sont envoyés depuis un thread en arrière-plan avec des délais courts : ils ne ralentissent ni n'interrompent jamais votre appel.

**Pourquoi et combien de temps :** les données servent uniquement à mesurer l'utilisation et à diagnostiquer les problèmes au plus tôt ; elles sont conservées 30 jours sur le serveur Sentry propre à DomainNameAPI, puis supprimées automatiquement.

**Comment le désactiver :**

```ruby
dna = DomainNameApi::Client.new(reseller_id, api_key)
dna.set_error_reporting_enabled(false)
```

Le **mode minimal** n'envoie que le code et le message d'erreur, le point de terminaison, la durée, les versions et l'ID revendeur — sans données de requête/réponse, domaine, IP du serveur ni nom d'utilisateur :

```ruby
dna.set_telemetry_minimal(true)
```

> 🔒 **Sécurité :** la vérification des certificats TLS est activée. Sur un serveur dont le bundle CA est obsolète, elle peut être désactivée avec `dna.set_ssl_verification(false)` — déconseillé ; mettre à jour le bundle CA est la meilleure solution.

## Utilisation

Tous les exemples supposent `dna = DomainNameApi::Client.new(reseller_id, api_key)`. Des scripts exécutables pour chaque méthode se trouvent dans [examples](examples).

### Compte

#### Détails du revendeur

```ruby
dna.get_reseller_details
```

<details>
<summary>Exemple de sortie</summary>

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

#### Solde actuel

`get_current_balance(currency = 'USD')` — le compte indique des soldes en `'USD'` et en `'TRY'`. Pour toute autre devise (`'EUR'`, `'GBP'`, ...), l'appel échoue avec `'ErrorCode' => 'BALANCE'` au lieu de répondre `0.00`.

```ruby
dna.get_current_balance('USD')
```

<details>
<summary>Exemple de sortie</summary>

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

### Recherche et listes

#### Vérification de disponibilité de domaine

`check_availability(domains, extensions, period, command = 'create')` — dans le résultat, `DomainName` est le nom sans son suffixe `.tld`.

```ruby
dna.check_availability(['hello', 'world123x0'], ['com', 'net'], 1, 'create')
```

<details>
<summary>Exemple de sortie</summary>

```ruby
[
  { 'TLD' => 'com', 'DomainName' => 'hello', 'Status' => 'notavailable', 'Command' => 'create',
    'Period' => 1, 'IsFee' => false, 'Price' => '10.8100', 'Currency' => 'USD', 'Reason' => 'Domain exists' },
  { 'TLD' => 'com', 'DomainName' => 'world123x0', 'Status' => 'available', 'Command' => 'create',
    'Period' => 1, 'IsFee' => false, 'Price' => '10.8100', 'Currency' => 'USD', 'Reason' => nil }
]
```

</details>

#### Liste des domaines

`get_list(extra_parameters = {})` — `PageNumber` (à partir de 0), `PageSize`, `OrderColumn`, `OrderDirection` et les filtres propres à la passerelle (par ex. `DomainName`).

```ruby
dna.get_list('OrderColumn' => 'Id', 'OrderDirection' => 'ASC', 'PageNumber' => 0, 'PageSize' => 1000)
```

<details>
<summary>Exemple de sortie</summary>

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

#### Liste des TLD

`get_tld_list(count = 20)`

```ruby
dna.get_tld_list(100)
```

<details>
<summary>Exemple de sortie</summary>

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

### Domaine

#### Enregistrement de domaine

`register_with_contact_info(domain, period, contacts, name_servers = [], epp_lock = true, privacy_lock = false, additional_attributes = {})`

Les contacts utilisent les clés de php-dna. La forme plate ci-dessous et la forme imbriquée renvoyée par `get_contacts` (`Address => { Line1, City, ... }`, `Phone => { Phone => { Number, CountryCode } }`) sont toutes deux acceptées ; les champs manquants sont complétés et les noms, téléphones et pays sont normalisés (voir `validate_contact`). En l'absence de serveurs de noms, `ns1.domainnameapi.com` et `ns2.domainnameapi.com` sont utilisés.

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

Pour les domaines `.tr`, passez les attributs TRABIS comme 7e argument :

```ruby
# Propriétaire particulier
{ 'TRABISDOMAINCATEGORY' => 1, 'TRABISCITIZIENID' => '12345678901' }
# Propriétaire société
{ 'TRABISDOMAINCATEGORY' => 0, 'TRABISTAXOFFICE' => 'Istanbul VD', 'TRABISTAXNUMBER' => '1234567890' }
```

La catégorie est envoyée sous la forme `Owner`/`Corporate`, `TRABISCITIZIENID` sous la forme `TRABISCITIZENID`, et les anciennes clés (`TRABISNAMESURNAME`, `TRABISCOUNTRYID`, `TRABISCITYID`, ...) sont supprimées, car la passerelle les lit désormais depuis le contact.

<details>
<summary>Exemple de sortie</summary>

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

#### Renouvellement de domaine

```ruby
dna.renew('example.com', 1)
```

<details>
<summary>Exemple de sortie</summary>

```ruby
{ 'result' => 'OK', 'data' => { 'ExpirationDate' => '2025-03-15T10:00:00' } }
```

</details>

#### Informations de domaine

```ruby
dna.get_details('example.com')
```

<details>
<summary>Exemple de sortie</summary>

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

#### Synchronisation depuis le registre

Même appel et même sortie que `get_details`.

```ruby
dna.sync_from_registry('example.com')
```

#### Modification des serveurs de noms

Passez une liste ou un Hash (ce sont les valeurs qui sont utilisées). Les noms sont débarrassés de leurs espaces, mis en minuscules, privés de leur point final et dédoublonnés ; le résultat renvoie cette liste normalisée.

```ruby
dna.modify_name_server('example.com', ['ns1.example.com', 'ns2.example.com'])
```

<details>
<summary>Exemple de sortie</summary>

```ruby
{ 'result' => 'OK', 'data' => { 'NameServers' => ['ns1.example.com', 'ns2.example.com'] } }
```

</details>

#### Activer le verrouillage du domaine

```ruby
dna.enable_theft_protection_lock('example.com')
```

<details>
<summary>Exemple de sortie</summary>

```ruby
{ 'result' => 'OK', 'data' => { 'LockStatus' => true } }
```

</details>

#### Désactiver le verrouillage du domaine

```ruby
dna.disable_theft_protection_lock('example.com')
```

<details>
<summary>Exemple de sortie</summary>

```ruby
{ 'result' => 'OK', 'data' => { 'LockStatus' => false } }
```

</details>

#### Modifier la protection de la vie privée du domaine

`modify_privacy_protection_status(domain, status, reason = 'Owner request')` — `status` peut valoir `true`/`false` ou une valeur de type panel : `1`, `'1'`, `'true'`, `'on'` et `'yes'` activent la protection de la vie privée, toute autre valeur la désactive. Le résultat renvoie le booléen interprété. `reason` est accepté pour des raisons de compatibilité mais n'est pas envoyé : la passerelle ne possède pas ce champ.

```ruby
dna.modify_privacy_protection_status('example.com', true, 'Owner request')
```

<details>
<summary>Exemple de sortie</summary>

```ruby
{ 'data' => { 'PrivacyProtectionStatus' => true }, 'result' => 'OK' }
```

</details>

#### Obtenir les contacts du domaine

Les types de contact sont reconnus sans tenir compte de la casse (`admin`/`administrative`, `tech`/`technical`, `registrant`/`owner`, `billing`) ; les autres types renvoyés par le registre sont conservés après les quatre types standard.

```ruby
dna.get_contacts('example.com')
```

<details>
<summary>Exemple de sortie</summary>

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
      # tout autre type de contact renvoyé par le registre suit ces quatre-là
    }
  },
  'result' => 'OK'
}
```

</details>

#### Enregistrer les contacts du domaine

```ruby
dna.save_contacts('example.com', {
  'Administrative' => contact,
  'Billing'        => contact,
  'Technical'      => contact,
  'Registrant'     => contact
})
```

<details>
<summary>Exemple de sortie</summary>

```ruby
{ 'result' => 'OK', 'data' => { 'contacts' => {} } }
```

</details>

<hr style="border: 4px solid #000; border-style: dashed;">

### Serveurs de noms enfants

#### Ajouter un serveur de noms enfant

```ruby
dna.add_child_name_server('example.com', 'ns1.example.com', '1.2.3.4')
```

<details>
<summary>Exemple de sortie</summary>

```ruby
{ 'result' => 'OK', 'data' => { 'NameServer' => 'ns1.example.com', 'IPAdresses' => ['1.2.3.4'] } }
```

</details>

#### Supprimer un serveur de noms enfant

```ruby
dna.delete_child_name_server('example.com', 'ns1.example.com')
```

<details>
<summary>Exemple de sortie</summary>

```ruby
{ 'result' => 'OK', 'data' => { 'NameServer' => 'ns1.example.com' } }
```

</details>

#### Mettre à jour un serveur de noms enfant

```ruby
dna.modify_child_name_server('example.com', 'ns1.example.com', '1.2.3.5')
```

<details>
<summary>Exemple de sortie</summary>

```ruby
{ 'result' => 'OK', 'data' => { 'NameServer' => 'ns1.example.com', 'IPAdresses' => ['1.2.3.5'] } }
```

</details>

<hr style="border: 4px solid #000; border-style: dashed;">

### Transferts

#### Transfert de domaine

`transfer(domain, epp_code, period)` — un transfert n'envoie jamais de contacts : c'est le registraire qui les gère, la requête contient donc toujours une liste de contacts vide et la méthode ne prend pas d'argument de contacts. Mettez à jour les contacts avec `save_contacts` une fois le transfert terminé.

```ruby
dna.transfer('example.com', 'Xy9#mK2$', 3)
```

<details>
<summary>Exemple de sortie</summary>

```ruby
{
  'data' => { 'ID' => 0, 'Status' => 'WaitingForIncomingTransfer', 'DomainName' => 'example.com', ... },
  'result' => 'OK'
}
```

</details>

#### Vérifier un transfert

`result` vaut `'OK'` uniquement lorsque le registre indique que le domaine est transférable.

```ruby
dna.check_transfer('example.com', 'Xy9#mK2$')
```

<details>
<summary>Exemple de sortie</summary>

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

#### Annuler, approuver ou rejeter un transfert

`cancel_transfer` annule un transfert entrant en attente ; `approve_transfer` et `reject_transfer` répondent à un transfert sortant en attente.

```ruby
dna.cancel_transfer('example.com')
dna.approve_transfer('example.com')
dna.reject_transfer('example.com')
```

<details>
<summary>Exemple de sortie</summary>

```ruby
{ 'result' => 'OK', 'data' => { 'DomainName' => 'example.com', 'Status' => 'Cancelled' } } # 'Approved' / 'Rejected'
```

</details>

<hr style="border: 4px solid #000; border-style: dashed;">

### Zone DNS

Types d'enregistrements pris en charge : `A`, `AAAA`, `ALIAS`, `CAA`, `CNAME`, `DS`, `MX`, `NAPTR`, `PTR`, `SRV`, `TLSA`, `TXT` (les autres types sont rejetés avant tout appel). Les noms sont relatifs (`'www'`) ; `''` ou `'@'` désigne l'apex de la zone, et un nom complet tel que `'www.example.com'` est réduit à son libellé. Les modifications sont appliquées immédiatement ; passez `apply = false` pour en préparer plusieurs, puis appelez `apply_resource_records` une seule fois. Le TTL est compris entre 1 et 86400 secondes.

Si l'application automatique échoue, la méthode renvoie l'erreur d'application (la modification reste préparée, mais n'est pas en ligne) au lieu de `OK`. Le résultat indique le type en majuscules et le TTL réellement envoyés.

La passerelle stocke un couple nom + type comme un seul **ensemble** (set) : écrire un ensemble remplace toutes ses valeurs, et supprimer une valeur supprime l'ensemble entier. Les méthodes `*_resource_record_value` effectuent pour vous la séquence lecture-fusion-écriture.

#### Lister les enregistrements

```ruby
dna.get_resource_records('example.com')
```

<details>
<summary>Exemple de sortie</summary>

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

#### Remplacer un ensemble d'enregistrements

`set_resource_record_set(domain, name, type, contents, ttl = 3600, apply = true)` — une liste vide supprime l'ensemble.

```ruby
dna.set_resource_record_set('example.com', 'www', 'A', ['192.0.2.10', '192.0.2.11'], 3600)
```

<details>
<summary>Exemple de sortie</summary>

```ruby
{ 'result' => 'OK', 'data' => { 'Name' => 'www', 'Type' => 'A', 'TTL' => 3600, 'Contents' => ['192.0.2.10', '192.0.2.11'] } }
```

</details>

#### Ajouter, remplacer ou retirer une valeur

`add_resource_record_value(domain, name, type, value, ttl = nil, apply = true)`, `replace_resource_record_value(domain, name, type, old_value, new_value, ttl = nil, apply = true)`, `remove_resource_record_value(domain, name, type, value, apply = true)`. Un TTL `nil` conserve le TTL actuel de l'ensemble ; ajouter une valeur déjà présente ou retirer une valeur absente n'a aucun effet (`'Changed' => false`).

```ruby
dna.add_resource_record_value('example.com', '', 'MX', '10 mail.example.com.')
dna.replace_resource_record_value('example.com', '', 'MX', '10 mail.example.com.', '20 mail.example.com.')
dna.remove_resource_record_value('example.com', '', 'MX', '20 mail.example.com.')
```

<details>
<summary>Exemple de sortie</summary>

```ruby
{ 'result' => 'OK', 'data' => { 'Name' => '', 'Type' => 'MX', 'TTL' => 3600, 'Contents' => ['10 mail.example.com.'] } }
# valeur déjà présente :
{ 'result' => 'OK', 'data' => { 'Name' => '', 'Type' => 'MX', 'Contents' => ['10 mail.example.com.'], 'Changed' => false } }
```

</details>

#### Supprimer un ensemble d'enregistrements

`delete_resource_record_set(domain, name, type, apply = true, known_value = '')` — supprime toutes les valeurs de l'ensemble ; s'il n'y a rien à supprimer, l'appel réussit avec `'Removed' => false`.

```ruby
dna.delete_resource_record_set('example.com', 'www', 'A')
```

<details>
<summary>Exemple de sortie</summary>

```ruby
{ 'result' => 'OK', 'data' => { 'Name' => 'www.example.com.', 'Type' => 'A', 'Content' => '192.0.2.10' } }
```

</details>

#### Appels bas niveau sur les enregistrements

```ruby
dna.add_resource_record('example.com', 'www', 'A', '192.0.2.10', 3600, true)
dna.edit_resource_record('example.com', 'www', 'www', 'A', '192.0.2.20', 3600, true)
dna.delete_resource_record('example.com', 'www.example.com.', '192.0.2.20', 'A', true)
dna.apply_resource_records('example.com')
```

<details>
<summary>Exemple de sortie</summary>

```ruby
{ 'result' => 'OK', 'data' => { 'Name' => 'www', 'Type' => 'A', 'TTL' => 3600, 'Content' => '192.0.2.10' } }   # add / edit
{ 'result' => 'OK', 'data' => { 'Name' => 'www.example.com.', 'Type' => 'A', 'Content' => '192.0.2.20' } }    # delete
{ 'result' => 'OK', 'data' => { 'DomainName' => 'example.com' } }                                              # apply
```

</details>

<hr style="border: 4px solid #000; border-style: dashed;">

### Redirection d'URL

Types de redirection : `'Standard'` (redirection simple) et `'Frame'` (masquée). La passerelle répond `Redirect information not found` lorsqu'aucune redirection n'est configurée : `get_forwarding` renvoie alors `'Enabled' => false` et `delete_forwarding` réussit avec `'Removed' => false`. Toute autre erreur, par exemple un domaine inconnu, est renvoyée comme une erreur.

```ruby
dna.set_forwarding('example.com', 'https://www.example.org', 'Standard')
dna.get_forwarding('example.com')
dna.delete_forwarding('example.com')
```

<details>
<summary>Exemple de sortie</summary>

```ruby
# set_forwarding
{ 'result' => 'OK', 'data' => { 'RedirectAddress' => 'https://www.example.org', 'ForwardType' => 'Standard' } }
# get_forwarding (sans configuration, renvoie Enabled => false, pas une erreur)
{ 'result' => 'OK', 'data' => { 'Enabled' => true, 'RedirectAddress' => 'https://www.example.org', 'ForwardType' => 'Standard' } }
# delete_forwarding (Removed => false si rien n'était configuré)
{ 'result' => 'OK', 'data' => { 'DomainName' => 'example.com', 'Removed' => true } }
```

</details>

<hr style="border: 4px solid #000; border-style: dashed;">

### Utilitaires (sans réseau)

#### Est-ce un domaine .tr ?

```ruby
dna.is_tr_tld('example.com.tr') # => true
dna.is_tr_tld('example.com')    # => false
```

#### Valider un contact

Complète et normalise un contact de la même manière que l'enregistrement : les chiffres et la ponctuation sont retirés des noms, un état (State) manquant prend la valeur de la ville, les noms de pays deviennent des codes ISO et les numéros de téléphone sont séparés en numéro et indicatif pays. Un numéro écrit avec son propre indicatif `+` ou `00` conserve cet indicatif même si un autre `PhoneCountryCode` a été fourni (`'+1 202 555 0100'` → `'2025550100'` / `'1'`).

```ruby
dna.validate_contact('FirstName' => 'J0hn', 'Phone' => '+90 532 374 33 88', 'Country' => 'Turkey')
```

<details>
<summary>Exemple de sortie</summary>

```ruby
{
  'FirstName' => 'Jhn', 'Phone' => '5323743388', 'Country' => 'TR', 'LastName' => 'Isimyok',
  'AddressLine1' => 'Addres yok', 'City' => 'ISTANBUL', 'State' => 'ISTANBUL', 'ZipCode' => '34000',
  'PhoneCountryCode' => '90', 'Fax' => '', 'FaxCountryCode' => ''
}
```

</details>

<hr style="border: 4px solid #000; border-style: dashed;">

### Paramètres

| Méthode | Effet |
|---|---|
| `set_error_reporting_enabled(false)` | Désactive la télémétrie |
| `set_telemetry_minimal(true)` | Envoie la charge utile de télémétrie minimale |
| `set_ssl_verification(false)` | Ignore la vérification des certificats TLS (déconseillé) |
| `set_service_url(url)` | Utilise une autre URL de passerelle |
| `set_transport(callable)` | Remplace le transport HTTP (voir ci-dessous) |

Le transport HTTP est n'importe quel objet qui répond à `call(request)`, où `request` est un Hash contenant `:method`, `:url`, `:headers`, `:body`, `:timeout`, `:connect_timeout` et `:verify_ssl`, et qui renvoie un `DomainNameApi::Response` (ou un Hash avec `:status`, `:body`, `:headers`). Le transport par défaut est `DomainNameApi::NetHttpTransport` (Net::HTTP). C'est ainsi que les tests s'exécutent sans réseau :

```ruby
fake = ->(request) { DomainNameApi::Response.new(status: 200, body: '{"resellerId":"abc"}', headers: {}) }
dna = DomainNameApi::Client.new(reseller_id, api_key, false, transport: fake)
```

<hr style="border: 4px solid #000; border-style: dashed;">

## Tests

La suite de tests n'utilise que Minitest et n'accède jamais au réseau :

```bash
bundle install
bundle exec rake test
```

`test/conformance_test.rb` exécute les 126 fixtures de conformité de php-dna (`test/fixtures/conformance/`) : pour chaque scénario, il compare les requêtes envoyées (méthode, chemin, query, corps JSON, en-têtes d'authentification) et la valeur renvoyée avec ce que php-dna a produit. Les autres tests couvrent la couche HTTP, la correspondance des erreurs, le masquage de la télémétrie, le transport Net::HTTP et les utilitaires.

<hr style="border: 4px solid #000; border-style: dashed;">

## Codes de Retour et d'Erreur avec Descriptions

| Code | Description | Détail |
|------|-------------|--------|
| 1000 | Commande complétée avec succès | Opération réussie. |
| 1001 | Commande complétée avec succès ; action en attente | Opération réussie. Cependant, l'opération est actuellement en file d'attente pour completion. |
| 2003 | Paramètre requis manquant | Erreur de paramètre manquant. Par exemple : aucune entrée de téléphone dans les informations de contact. |
| 2105 | L'objet n'est pas éligible pour le renouvellement | Le statut du domaine n'est pas adapté pour le renouvellement, verrouillé pour les opérations de mise à jour. Le statut ne doit pas être "clientupdateprohibited". Peut être dû à d'autres conditions de statut. |
| 2200 | Erreur d'authentification | Erreur d'autorisation, code de sécurité incorrect ou domaine enregistré avec un autre registraire. |
| 2302 | L'objet existe | Le nom de domaine ou les informations de serveur de noms existent déjà dans la base de données. Ne peut pas être enregistré. |
| 2303 | L'objet n'existe pas | Le nom de domaine ou les informations de serveur de noms n'existent pas dans la base de données. Nouvel enregistrement requis. |
| 2304 | Le statut de l'objet interdit l'opération | Le statut du domaine n'est pas adapté pour les mises à jour, verrouillé pour les opérations de mise à jour. Le statut ne doit pas être "clientupdateprohibited". Peut être dû à d'autres conditions de statut. |

| CODE | DÉTAIL |
|------|--------|
| 101 | Erreur système détaillée pour ({0})! |
| 102 | Erreurs multiples détaillées pour ({0})! |
| 103 | Erreurs inconnues détaillées pour ({0})! |
| 200 | Commande API introuvable ({0})! |
| 210 | Service API introuvable ({0})! |
| 211 | Fournisseur de service API non défini! |
| 300 | Revendeur introuvable! |
| 301 | Votre adresse IP actuelle n'est pas autorisée à accéder. Veuillez vous assurer que vous vous connectez depuis une adresse IP autorisée et réessayez |
| 310 | TLD non supporté! |
| 320 | API introuvable! |
| 321 | Devise non supportée! |
| 330 | Paramètre(s) requis non défini(s) ({0}). |
| – | Assurez-vous d'envoyer tous les objets de contact complets |
| 340 | Définition de prix introuvable ({0}[{1}]-{2}{3}). |
| 350 | Solde de revendeur insuffisant. (Id Revendeur : {0} - Solde Actuel : {1} {2}). |
| 350 | La devise comptable ne correspond pas ou le solde est insuffisant. |
| 360 | Requête API invalide pour le champ ({0}). |
| 360 | Quota API dépassé! |
| 361 | Erreur de limitation! |
| 362 | Le domaine premium n'est pas disponible pour l'enregistrement pour le moment. |
| 363 | Opération annulée car le domaine est en période de renouvellement automatique |
| 364 | Ce domaine est actuellement indisponible pour une transaction en raison d'un problème avec le registre |

| CODE | DÉTAIL |
|------|--------|
| 400 | Contact invalide ({0}). |
| 401 | Les informations de contact ne peuvent pas être synchronisées. |
| 402 | Aucun accès aux informations de contact depuis le registre. |
| 403 | LE SYSTÈME A DES INFORMATIONS MANQUANTES. ENTREZ VOS INFORMATIONS PAR DÉFAUT OU CONTACTEZ L'ÉQUIPE DE SUPPORT. |
| 404 | LE CONTACT DE DOMAINE NE PEUT PAS ÊTRE MIS À JOUR. PERMISSION DU REGISTRE. |
| 410 | Contact introuvable. |
| 410 | Contact introuvable ({0}). |
| 420 | Commande Api invalide pour le contact {0}. |
| 430 | API de contact introuvable. |
| 440 | Le contact n'est pas synchronisé. |
| 450 | Trop de contacts de domaine.. ! |
| 451 | Échec de la poursuite de la mise à jour du contact. |

| CODE | DÉTAIL |
|------|--------|
| 500 | ID de domaine invalide. |
| 500 | ID de domaine invalide ({0}). |
| 501 | Le domaine n'a pas pu être synchronisé({0}) |
| 502 | Transfert interne échoué |
| 503 | L'enregistrement de domaine n'est pas disponible. |
| 504 | Les informations de domaine ne correspondent pas .. Avant :{0} |
| 505 | Entrez l'adresse IP. |
| 506 | Le transfert de domaine a été initié mais les informations de contact n'ont pas pu être lues .. |
| 507 | Erreur d'autorisation. |
| 510 | Domaine introuvable. |
| 511 | Les domaines expirés ne peuvent pas être trouvés. |
| 512 | Le domaine n'est pas renouvelable. |
| 513 | Le domaine n'est pas dans un état modifiable. Il doit être actif pour être mis à jour |
| 514 | Période de rachat attendue. |
| 520 | Commande Api invalide pour le domaine "{0}". |
| 530 | Période de domaine invalide. La période doit être de {0} à {1} ans. La période demandée est de {2} ans. |
| 540 | Le domaine ne peut pas être étendu au-delà de {0} ans à partir de la date actuelle. |
| 550 | Nom de domaine invalide. Le domaine doit avoir une longueur de {0} à {1} caractères. Le nom de domaine demandé fait {2} caractères. |
| 560 | Nombre de serveurs de noms invalide. Le domaine doit avoir {0} à {1} serveurs de noms. Le nombre de serveurs de noms demandé est {2}. |
| 561 | Aucune information de serveur de noms trouvée dans la requête entrante |
| 570 | Idn non supporté pour le tld "{0}". |
| 571 | Période invalide. |
| 572 | Commande invalide. |
| 573 | Noms de domaine introuvables. |
| 574 | Noms TLD introuvables. |
| 575 | Le domaine n'est pas dans un état modifiable. Il doit être actif pour que les serveurs de noms soient mis à jour |
| 576 | Le domaine peut être renouvelé dans le dernier mois avant la date d'expiration |
| 580 | Transfert non supporté pour le tld "{0}". |
| 581 | Serveur de noms enfant introuvable |
| 582 | Transfert initié par un autre revendeur. |
| 583 | Transfert non initialisé. Veuillez contacter l'équipe de support. |
| 584 | Le statut de l'objet interdit l'opération |
| 590 | Le code d'autorisation est requis pour ce transfert. |
| 591 | Le code d'autorisation n'est pas valide. |
| 592 | Un verrou de transfert existe sur le domaine. |
| 593 | Le domaine ne peut pas être transféré, les informations de statut et le verrou de transfert doivent respecter les critères requis. (Informations de statut: #ok) |
| 594 | L'adresse du serveur de noms de domaine n'a pas pu être résolue ({0}) |
| 595 | Les informations de contact ne peuvent pas être lues (whois.registrar.tld) Veuillez vous assurer que le statut de protection de la vie privée est ouvert |
| 596 | Les informations de contact n'ont pas pu être vérifiées |
| 597 | Tld introuvable |
| 598 | Erreur inconnue survenue |
| 599 | Redirection de domaine introuvable |

## Licence

Apache License 2.0 — voir [LICENSE](LICENSE).
