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

# ruby-dna: Domain Name API üçün Ruby SDK-sı

[![CI](https://github.com/domainreseller/ruby-dna/actions/workflows/ci.yml/badge.svg)](https://github.com/domainreseller/ruby-dna/actions/workflows/ci.yml)
[![License](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](LICENSE)

[Domain Name API](https://www.domainnameapi.com) reseller REST API-si üçün Ruby klienti: domen axtarışı,
qeydiyyat, yenilənmə və transfer, DNS, DNSSEC, kontaktlar, SSL sertifikatları, hosting, sifarişlər, məhsul
kataloqu və balansınız.

- **API-nin bütün 67 əməliyyatı**, [`dna` CLI](https://github.com/domainreseller/cli) ilə eyni şəkildə qruplaşdırılıb:
  `dna domain info` əmri `client.domains.info`, `dna dns add` əmri `client.dns.add` qarşılığıdır.
- **Hash-lər deyil, real obyektlər**: `domain.status.pending_delete?`, `domain.expiration_date` `Time` obyektidir,
  `availability.available?`, `tld.register_price(1)`.
- **Hər əməliyyat bir sorğu sinfidir**; `DomainNameApi::BaseRequest` sinfindən miras alır və hər hansı bir şey göndərilməzdən
  əvvəl özünü yoxlayır. Öz sorğularınızı da eyni qaydada yaza bilərsiniz.
- **Susmaya görə təhlükəsiz**: ödənişli sorğular kor-koranə təkrarlanmır, `read_only: true` dəyişiklikləri bloklayır, klient
  özünü sürət limitlərinin altında saxlayır və thread-lər arasında təhlükəsiz paylaşıla bilər.
- **Asılılıq yoxdur.** Ruby 3.1 və ya daha yeni, yalnız standart kitabxana.

```ruby
client = DomainNameApi::Client.new(reseller_id: reseller_id, api_key: api_key, environment: :ote)

a = client.domains.search('example.com')
puts "#{a.domain_name} is available for #{a.price} #{a.currency}" if a.available?
```

## Mündəricat

- [Quraşdırma](#quraşdırma)
- [Giriş məlumatları və mühitlər](#giriş-məlumatları-və-mühitlər)
- [Servislər](#servislər)
- [Nümunələr](#nümunələr)
- [Nəticələr, modellər və enum-lar](#nəticələr-modellər-və-enum-lar)
- [Sorğular və BaseRequest](#sorğular-və-baserequest)
- [Xətalar](#xətalar)
- [Təhlükəsizlik və etibarlılıq](#təhlükəsizlik-və-etibarlılıq)
- [Client seçimləri](#client-seçimləri)
- [Kodunuzun test edilməsi](#kodunuzun-test-edilməsi)
- [v1-dən keçid](#v1-dən-keçid)
- [Layihənin hazırlanması](#layihənin-hazırlanması)

## Quraşdırma

> ⬇️ [Releases](https://github.com/domainreseller/ruby-dna/releases/latest) bölməsindən teqlənmiş versiyadan istifadə edin.
> Yaşıl **Code → Download ZIP** düyməsi sizə inkişaf branch-ını (development branch) verir.

Bundler ilə:

```ruby
# Gemfile
gem 'domainnameapi', git: 'https://github.com/domainreseller/ruby-dna.git', tag: 'v2.0.0'
```

Və ya release-ə əlavə olunmuş `.gem` faylını quraşdırın:

```bash
gem install ./domainnameapi-2.0.0.gem
```

```ruby
require 'domainnameapi'
```

İşlək proqramlar [examples](examples) qovluğundadır: `quickstart`, `register`, `expiring`, `dns`, `ssl` və
`custom_request`.

```bash
DNA_RESELLER_ID=... DNA_API_KEY=... DNA_ENV=ote ruby examples/quickstart.rb example.com
```

## Giriş məlumatları və mühitlər

Reseller panelindən (**API settings**) iki API giriş məlumatı götürməlisiniz. Panelə giriş məlumatları işləmir.

| Giriş məlumatı | Necə görünür                           |
|----------------|----------------------------------------|
| Reseller ID    | `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx` |
| API key        | uzun gizli sətir                       |

İki mühit var. **Test mühiti olan OTE ilə başlayın**: onun öz məlumatları və öz API açarı var; orada
etdiyiniz heç bir şey pul tutmur və canlı domenlərə toxunmur.

```ruby
# Test mühiti (OTE)
client = DomainNameApi::Client.new(reseller_id: reseller_id, api_key: ote_api_key, environment: :ote)

# Production (susmaya görə): real qeydiyyatlar, real ödənişlər
client = DomainNameApi::Client.new(reseller_id: reseller_id, api_key: api_key)
```

`environment:` panellərin saxladığı sətirləri də qəbul edir: `'production'`, `'ote'`, `'test'` və test rejimi bayraqları
(`'true'`, `'1'`, `true`). `Client.from_env`, `dna` CLI ilə eyni dəyişənləri oxuyur:

| Dəyişən           | Mənası                                                        |
|-------------------|---------------------------------------------------------------|
| `DNA_RESELLER_ID` | reseller ID                                                   |
| `DNA_API_KEY`     | seçilmiş mühitin API açarı                                    |
| `DNA_ENV`         | `production` (susmaya görə) və ya `ote`                       |
| `DNA_TEST_MODE`   | `true` OTE-ni seçir (digər DomainNameAPI SDK-larındakı kimi)  |
| `DNA_BASE_URL`    | xüsusi baza URL, məsələn proksi                               |

```ruby
client = DomainNameApi::Client.from_env(user_agent: 'my-panel/1.4')
```

Yanlış açar və ya mühit ilk sorğuda `auth?` dəyəri true olan və `hint` dəyəri nəyi yoxlamaq lazım olduğunu göstərən
`APIError` xətası verir; yoxlamağın ən ucuz yolu `client.account.get` çağırışıdır.

## Servislər

| Servis             | CLI qrupu     | Əməliyyatlar                                                                                                                                                      |
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

Məcburi girişlər mövqeli arqument kimi verilir (`info('example.com')`), qalan hər şey keyword arqumentidir
(`renew('example.com', years: 1)`). Çoxlu istəyə bağlı girişi olan əməliyyatlar keyword arqumentləri və ya sorğu obyekti qəbul edir:
`register(domain_name: ..., years: 1, ...)` və `register(DomainNameApi::DomainRegisterRequest.new(...))` eynidir.
`ssl.purchase` CLI-dakı `dna ssl initialize` əmrinin qarşılığıdır (`initialize` Ruby-də rezerv olunmuş addır).

## Nümunələr

Bütün kod parçaları bir `client` olduğunu fərz edir.

### Axtarış

```ruby
a = client.domains.search('example.com')
a.available?            # a.price, a.currency, a.premium?, a.document_required?, a.reason

client.domains.bulk_search('example.com', 'example.net', 'example.org').each do |r|
  puts "#{r.domain_name} #{r.status} #{r.price}"
end
```

`bulk_search` 30 domendən uzun siyahıları bir neçə sorğuya bölür. Qiymətlər hesabın valyutası ilə, klientin
`currency: 'TRY'` seçimi ilə və ya `search('example.com', currency: 'USD')` ilə verilmiş valyuta ilə gəlir.

### Qeydiyyat

Kontakt handle-ları ilə (birini `contacts.create` ilə yaradın):

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
  handles: handle # dörd rolun hamısı üçün bir handle və ya { registrant: 'DNA-1', admin: 'DNA-2', tech: ..., billing: ... }
)
result.status           # result.domain_id, result.expiration_date
```

Sətir daxili kontaktlarla:

```ruby
client.domains.register_with_contacts(
  domain_name: 'example.com',
  name_servers: %w[ns1.example.net ns2.example.net],
  contacts: owner # dörd rolun hamısı üçün bir Contact və ya { registrant: owner, admin: admin, tech: admin, billing: admin }
)
```

Kontaktlar `DomainNameApi::Contact` obyektləri və ya eyni sahələrdən ibarət Hash-lər ola bilər. Göndərilməzdən əvvəl səliqəyə salınırlar:
sahələrin əvvəlindəki və sonundakı boşluqlar silinir, ölkə kodu böyük hərflərə çevrilir, telefon sahələrində isə yalnız rəqəmlər saxlanılır
(`'+90 (555) 123-45-67'` işləyir). Bəzi TLD-lər reyestr (registry) atributları tələb edir: onları
`client.products.tld('com.tr').required_attributes` ilə tapın və `tld_attributes:` kimi ötürün.

API cavab verib sorğunu rədd edərsə (`"success": false`), metod API-nin mesajını daşıyan `DomainNameApi::OperationError`
xətası qaldırır.

### Yenilənmə, transfer, bərpa

```ruby
check = client.domains.renew_check('example.com', years: 1)   # check.renewable?, check.premium_price
client.domains.renew('example.com', years: 1)

tc = client.domains.transfer_check('example.com', 'auth-code') # tc.transferable?, tc.auth_code_valid?
client.domains.transfer('example.com', auth_code: 'auth-code')
client.domains.transfer_status('example.com').status

client.domains.restore('example.com') # bərpa (redemption) dövründə
```

### Domen təfərrüatları və domen siyahısı

```ruby
d = client.domains.info('example.com')
d.status                # => #<DomainNameApi::DomainStatus Active (0)>
d.expiration_date       # => 2027-03-15 10:20:30 UTC
d.remaining_days, d.locked?, d.privacy_protection?, d.name_servers, d.auth_code, d.hosts
d.contact(:registrant)&.email

# Bir səhifə
page = client.domains.list(limit: 50, sort: 'expirationDate')
page.total_count
page.each { |domain| puts domain.domain_name }

# Bütün domenlər; səhifələr irəlilədikcə gətirilir
client.domains.all(statuses: [:active]) do |domain|
  puts "#{domain.domain_name} #{domain.expiration_date}"
end
client.domains.all.first(10) # blok verilmədikdə Enumerator qaytarır: bir səhifə gətirir
```

### Kilid, məxfilik, name server-lər, child name server-lər

```ruby
client.domains.lock('example.com')
client.domains.unlock('example.com')
client.domains.set_privacy('example.com', true)
code = client.domains.update_auth_code('example.com')

client.domains.set_name_servers('example.com', %w[ns1.example.net ns2.example.net])
client.domains.set_name_servers('example.com', %w[ns1.other.net ns2.other.net], dnssec_mode: :disable) # DNSSEC ilə imzalanmış domenlər üçün

client.domains.add_host('example.com', 'ns1.example.com', '192.0.2.10', '2001:db8::10') # IP versiyası avtomatik aşkarlanır
client.domains.update_host('example.com', 'ns1.example.com', ip_addresses: ['192.0.2.20'])
client.domains.delete_host('example.com', 'ns1.example.com')
```

### Domenin kontaktları

```ruby
client.domains.set_contact_handles('example.com', admin: 'DNA-2', tech: 'DNA-2') # digər rollar dəyişmir
client.domains.update_contacts('example.com', billing: billing_contact)

details = client.contacts.get('DNA-1')               # kontakt və onun doğrulama vəziyyəti
result = client.contacts.update('DNA-1', contact)    # handle-dan istifadə edən bütün domenləri yeniləyir
result.affected_domains.each { |a| puts "#{a.domain_name} #{a.new_handle}" }
client.contacts.resend_verification('DNA-1')          # doğrulanacaq bir şey yoxdursa false
```

### DNS zonası

```ruby
client.dns.add('example.com', name: 'www', type: :a, values: '192.0.2.10', ttl: 600)
client.dns.update('example.com', record_name: 'www', type: :a, values: %w[192.0.2.20 192.0.2.21]) # çoxluğu tamamilə əvəz edir
client.dns.delete('example.com', name: 'www', type: :a, value: '192.0.2.20')

client.dns.list('example.com').each do |set|
  puts "#{set.name} #{set.type} #{set.ttl} #{set.values.join(', ')}"
end

client.dns.apply('example.com') # domeni platformanın name server-lərinə keçirir
```

Adlar nisbi (`'www'`), kök (`''` və ya `'@'`) ya da tam ixtisaslaşmış ola bilər. Qeyd növləri istənilən hərf registrində simvol və ya
sətir ola bilər (`:txt` və `'txt'`, `TXT` kimi göndərilir). Doğrulama API-nin rədd edəcəyi halları tutur: kökdə CNAME,
üç hissəsi olmayan CAA dəyəri, prioriteti olmayan MX dəyəri, IPv6 ünvanlı A qeydi. Test mühiti hər zona çağırışına
HTTP 500 ilə cavab verir; buna görə zona kodunu yalnız production-da sınamaq mümkündür.

### DNSSEC

```ruby
results = client.dnssec.add('example.com', '2371 13 2 1F987CC6583E92DF0890718C42...') # DNS provayderinizin göstərdiyi şəkildə
info = client.dnssec.get('example.com') # info.status.signed?, info.ds_records
client.dnssec.disable('example.com')
```

`DomainNameApi::DS.parse` təqdimat formatını (presentation format) və zona faylının tam sətirlərini oxuyur; `DS.new(key_tag: ...,
algorithm: :ecdsa_p256_sha256, digest_type: :sha256, digest: '...')` da işləyir.

### URL yönləndirmə

```ruby
client.domains.set_forwarding('example.com', 'https://www.example.org')              # 301 yönləndirmə
client.domains.set_forwarding('example.com', 'https://www.example.org', type: :frame) # maskalanmış
f = client.domains.forwarding('example.com') # domendə yönləndirmə yoxdursa nil
client.domains.delete_forwarding('example.com')
```

### Reyestr sənədləri (.tr)

```ruby
doc = DomainNameApi::DocumentUpload.from_file(:identity_card, 'id.pdf')
client.domains.upload_documents('example.com.tr', doc)
client.domains.documents('example.com.tr').each { |d| puts "#{d.name} #{d.status}" }
```

Fayllar sizin üçün base64 ilə kodlaşdırılır; format (PDF, JPG, PNG, DOC, DOCX, ODT) və ölçü (hər fayl üçün 10 MB,
hər sorğu üçün 50 MB) yükləmədən əvvəl yoxlanılır.

### SSL sertifikatları

```ruby
csr = client.ssl.generate_csr(domain_name: 'example.com', country: 'TR', state: 'Istanbul', locality: 'Istanbul',
                              organization: 'Example Ltd', organization_unit: 'IT')
# balansdan ödəniş çıxır (CLI: dna ssl initialize)
order = client.ssl.purchase('example.com', package_code: 'PositiveSSL')
id = order.certificate_id # saxlayın: sonrakı hər çağırış bunu tələb edir
client.ssl.configure(certificate_id: id, csr: csr.csr, approver_mail: 'admin@example.com',
                     authentication_type: :email, web_server_type: :apache, contact: ssl_contact)
client.ssl.status(id).issued? # true olana qədər sorğulayın
File.write('example.com.crt', client.ssl.content(id).chain)
```

Bir domenin bir neçə sertifikatı ola bilər; buna görə mövcud sertifikat domen adı ilə deyil, `certificate_id`
dəyəri (GUID) ilə göstərilir: `purchase` və `renew` onu qaytarır, `list` isə onu tapır. İdentifikator gözlənilən
yerə domen adı verilərsə, heç nə göndərilmədən `InputError` xətası qaldırılır. Sertifikatı aldıqdan və ya
yenilədikdən sonra 15 gün ərzində konfiqurasiya edin.

```ruby
client.ssl.list(domain_name: 'example.com').each { |c| puts "#{c.certificate_id} #{c.status}" } # ən yenisi əvvəldə
client.ssl.all { |c| puts "#{c.domain_name} #{c.subscription_expires_at}" } # bütün sertifikatlar, səhifə-səhifə

client.ssl.approvers(certificate_id: id)                                      # mövcud sertifikat üçün
client.ssl.approvers(domain_name: 'example.com', package_code: 'PositiveSSL') # satınalmadan əvvəl

renewal = client.ssl.renew(id) # balansdan ödəniş çıxır; abunəliyin bitməsinə 30 gün qalmış mümkün olur
client.ssl.configure(certificate_id: renewal.certificate_id, csr: new_csr.csr, approver_mail: 'admin@example.com',
                     authentication_type: :email, web_server_type: :apache, contact: ssl_contact)
```

Yeniləmək üçün `renew` çağırın və qaytardığı yeni sertifikatı `configure` ilə konfiqurasiya edin. Yenidən
`purchase` çağırmayın: bu, alış qiyməti ilə əlaqəsiz yeni sifarişdir və köhnə sertifikat heç vaxt `Renewed`
statusuna keçmir.

### Hosting

```ruby
client.hosting.packages.each { |p| puts p.service_plans.map(&:service_plan) }
created = client.hosting.create('example.com', service_plan: 'Linux-Starter') # balansdan ödəniş çıxır

st = client.hosting.wait(created.service_id, timeout: 30 * 60) # aktiv olana qədər sorğulayır
puts st.panel_address, st.username, st.password
```

Hələ hazırlanmaqda olan hosting üçün `create`-i bir daha çağırmayın: iki dəfə ödəniş çıxılır.

### Balans, qiymətlər və sifarişlər

```ruby
account = client.account.get
account.balance('USD')
profile = client.account.profile # profile.company_name, profile.account_currency, profile.status.active?

client.account.all_transactions(from: Date.new(2026, 11, 1)) do |tx|
  puts "#{tx.creation_time} #{tx.type} #{tx.change}"
end

tld = client.products.tld('com.tr')
tld&.register_price(1)&.to_s   # => "12.50 USD"

client.products.info('com', order_type: :renew, years: 2) # 2 illik .com yenilənməsinin qiyməti
client.orders.get('ORDER-CODE')
```

## Nəticələr, modellər və enum-lar

Hər nəticə `DomainNameApi::Model` obyektidir: snake_case oxuma metodları, bayraqlar üçün `?` ilə bitən yoxlama metodları, tarixlər
üçün `Time` obyektləri, iç-içə modellər və siyahılar.

```ruby
d = client.domains.info('example.com')
d.locked?                 # həmçinin d.locked
d.hosts.first.ip_addresses.first.address
d.to_h                    # snake_case açarlı adi Hash
d.raw                     # API-nin göndərdiyi şəkildə JSON obyekti; bu gem-in modelləşdirmədiyi sahələr üçün
```

Rəqəmli və sabit sətirli dəyərlər enum-lardır (`DomainStatus`, `RecordType`, `ContactType`, `DocumentType`, ...):

```ruby
d.status.pending_delete?                       # hər üzv üçün bir yoxlama metodu
d.status == DomainNameApi::DomainStatus::ACTIVE
d.status == :active                            # simvollar, adlar və rəqəmlərlə də müqayisə olunur
d.status.to_s                                  # => "Active"
d.status.to_i                                  # => 0
DomainNameApi::DomainStatus.members            # hamısı
```

Sorğular enum-ları, simvolları, istənilən hərf registrində adları və ya rəqəmləri qəbul edir: `statuses: [:active, 'PendingDelete', 7]`.

Dekodlama tolerantdır: saat qurşağı olmayan tarixlər, `null`, `{}` əvəzinə `[]`, sətir kimi göndərilmiş rəqəmlər, istənilən hərf
registrində rollar (`"registrant"`, `"ADMINISTRATIVE"`) və bu gem-in hələ tanımadığı dəyərlər çağırışı uğursuz etmək əvəzinə
dekodlanır (sonuncu üçün `status.known?` false olur).

## Sorğular və BaseRequest

Hər API əməliyyatı bir sorğu sinfidir: `DomainInfoRequest`, `DNSAddRequest`, `SSLConfigureRequest`, ... Adlarını CLI əmrindən
alırlar (`dna domain renew` əmri `DomainRenewRequest` qarşılığıdır). Hamısı `DomainNameApi::BaseRequest` sinfindən miras alır; bu sinif
əsas infrastrukturu təmin edir: sinif səviyyəsində `endpoint` və `attribute` DSL-i, keyword arqumentləri ilə inisializasiya, doğrulama
köməkçiləri, yol şablonları və query/gövdə qurucuları. Siyahı sorğuları `skip`, `limit` və `sort` əlavə edən `PagedRequest`
sinfindən miras alır. Bu gem-dəki sorğu belə görünür:

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

Servis metodları bunları sizin üçün yaradır. `client.call` öz sinifləriniz də daxil olmaqla istənilən sorğunu göndərir; məsələn,
yalnız lazım olan sahələri oxumaq və ya bu gem-in hələ əhatə etmədiyi endpoint-i çağırmaq üçün:

```ruby
class Expiry < DomainNameApi::Model
  field :expiration_date, :time
  field :remaining_days, :integer, from: 'remainingDay'
end

class ExpiryRequest < DomainNameApi::BaseRequest
  endpoint :get, '/api/v1/domains/info', safety: :read
  returns Expiry            # yazmasanız, parse edilmiş JSON qaytarılır
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

| Əvəz edilən    | Susmaya görə          | Məqsədi                                                                     |
|----------------|-----------------------|-----------------------------------------------------------------------------|
| `query`        | `nil`                 | `Query` (`params.string(...)`), Hash və ya cütlərdən ibarət Array           |
| `body`         | `nil`                 | API-nin adları ilə Hash və ya Array; enum-lar, modellər və vaxtlar çevrilir |
| `validate`     | yoxlanılacaq heç nə   | problemləri `required`, `check`, `between`, `max_length`, `enum` ilə bildirin |
| `decode(data)` | `returns` istifadə olunur | parse edilmiş JSON-u nəticənizə çevirin                                 |

Yoldakı yer tutucular atributlardan doldurulur və escape edilir: `endpoint :get, '/api/v1/contacts/{handle}'`.

Sorğunuz daxili sorğuların aldığı hər şeyi alır: giriş məlumatları, təkrar cəhdlər, sürət tənzimi, xətaların normallaşdırılması,
korrelyasiya ID-ləri, izləmə və yalnız oxumaq məhdudiyyəti. `client.execute(request)` dekodlanmış nəticə `value` daxilində olmaqla bütün
`Response` obyektini (status, başlıqlar, xam gövdə, korrelyasiya ID-si, kvota, cəhdlər) qaytarır.
`client.prepare(request)` ödənişli sorğunu göndərilməzdən əvvəl loglamaq və ya nəzərdən keçirmək üçün dəqiq HTTP sorğusunu yoxlayır və
göndərmədən qurur (API açarı `inspect` çıxışında maskalanır).

## Xətalar

| Xəta                             | Nə vaxt                                                    | Faydalı metodlar                                                               |
|----------------------------------|------------------------------------------------------------|--------------------------------------------------------------------------------|
| `DomainNameApi::InputError`      | doğrulama sorğunu rədd etdi; **heç nə göndərilmədi**       | `request`, `fields`                                                            |
| `DomainNameApi::APIError`        | API 2xx olmayan status ilə cavab verdi                     | `status`, `code`, `api_message`, `details`, `fields`, `data`, `correlation_id`, `hint` |
| `DomainNameApi::OperationError`  | API 2xx və `"success": false` ilə cavab verdi              | `code`, `api_message`, `correlation_id`                                        |
| `DomainNameApi::NetworkError`    | sorğu tamamlanmadı (DNS, TLS, vaxt aşımı, bağlantının kəsilməsi) | `original`, `timeout?`                                                   |
| `DomainNameApi::ReadOnlyError`   | yalnız oxumaq rejimindəki klient dəyişikliyi blokladı; heç nə göndərilmədi | `safety`                                                       |

Hamısı tez-tez verilən suallara cavab verən `DomainNameApi::Error` sinfindən miras alır: `kind` (`:auth`,
`:not_found`, `:validation`, `:rejected`, `:conflict`, `:rate_limited`, `:server`, `:network`, `:invalid_input`,
`:read_only`), `not_found?`, `auth?`, `rate_limited?`, `insufficient_balance?`, `outcome_unknown?`,
`retryable?` və `code?(code)`.

```ruby
begin
  client.domains.renew('example.com', years: 1)
rescue DomainNameApi::Error => e
  if e.outcome_unknown?
    # Yenilənmə həyata keçmiş ola bilər. Yenidən cəhd etməzdən əvvəl domeni yoxlayın.
  elsif e.insufficient_balance?
  elsif e.not_found?
  elsif e.code?(DomainNameApi::ErrorCode::PRIVACY_NOT_SUPPORTED)
  elsif e.is_a?(DomainNameApi::APIError)
    logger.error("#{e.code} #{e.api_message} #{e.hint} #{e.correlation_id}")
  end
end
```

Mesaj üzrə yox, `code` üzrə budaqlandırın: mesajlar lokallaşdırılır. API kodları
`Dna.DomainService:Domain:10007` kimi görünür; ən çox rast gəlinənlər `DomainNameApi::ErrorCode` daxilində sabitlərdir, qalanları isə
[xəta sorğu-məlumatında](https://www.domainnameapi.com/docs/reference/errors.md) verilib. Dəstək xidmətinə müraciət edərkən `correlation_id`
dəyərini qeyd edin.

## Təhlükəsizlik və etibarlılıq

- **Təhlükəsizlik sinifləri.** Hər sorğu `:read`, `:write`, `:destructive` və ya `:billable` sinfindədir (`request.safety`,
  `request.billable?`). Bəzi POST və PUT sorğuları oxumadır (`DomainSearchRequest`, `SSLStatusRequest`).
- **Yalnız oxumaq rejimi.** `read_only: true` oxuma olmayan hər şeyi bloklayır; hesabat işləri və production-u təhlükəsiz
  araşdırmaq üçündür.
- **Təkrar cəhdlər.** 429 cavabları həmişə, `Retry-After` nəzərə alınmaqla təkrarlanır: API onları heç bir əməliyyat
  etmədən rədd edir. Şəbəkə xətaları və 502/503/504 yalnız oxumalar və idempotent yazmalar üçün təkrarlanır; beləliklə qeydiyyat
  və ya yenilənmə heç vaxt iki dəfə göndərilmir. Ödənişli sorğu uğursuz olduqdan sonra `e.outcome_unknown?` dəyərini yoxlayın.
- **Sürət tənzimi.** Klient açar başına limitlərin altında qalmaq üçün sorğular arasında fasilə qoyur (saniyədə 5 sorğu, saniyədə 2 axtarış,
  saniyədə bir zona çağırışı). Sürəti özünüz tənzimləyirsinizsə, `pacing: false` ilə söndürün.
- **Kvota.** `client.execute(request).quota` yumşaq kvota başlıqlarını təqdim edir. Limit aşıldıqda API cavabları rədd etmək əvəzinə
  yavaşladır (ən çoxu 5 san); susmaya görə 60 san vaxt aşımı buna yer buraxır.
- **Korrelyasiya ID-ləri.** Hər sorğu `X-Correlation-ID` daşıyır. API çağırışlarını loglarınızla əlaqələndirmək üçün öz dəyərinizi təyin edin:
  `DomainNameApi.with_correlation_id(job.id) { ... }` və ya `client.call(request, correlation_id: job.id)`.
- **Müşahidə oluna bilmə.** `logger: Logger.new($stdout)` hər mübadiləni loglayır; `on_trace: ->(event) { ... }` sizə hər sorğunu, cavabı
  və təkrar cəhdi `TraceEvent` kimi ötürür; metrikalar və ya xəta hesabatı üçün istifadə edilə bilər. API açarı onların heç birində yer
  almır; gövdələrdə kontakt məlumatları ola bilər, buna görə saxlamazdan əvvəl onları maskalayın.
- **Thread-lər.** Klient thread-lər arasında təhlükəsiz paylaşıla bilər. Bir dənə yaradın və təkrar istifadə edin.
- **Prosesinizdən kənara başqa heç nə çıxmır.** Telemetriya yoxdur, üçüncü tərəf xidmətləri yoxdur.

## Client seçimləri

| Seçim                        | Təsiri                                                                              |
|------------------------------|-------------------------------------------------------------------------------------|
| `environment: :ote`          | test mühitindən istifadə edir (susmaya görə `:production`)                          |
| `base_url: 'https://...'`    | sorğuları proksiyə və ya test serverinə göndərir                                    |
| `timeout: 60`                | HTTP cəhdi başına saniyə                                                            |
| `open_timeout: 10`           | qoşulma üçün saniyə                                                                 |
| `user_agent: 'app/1.0'`      | məhsulunuzu User-Agent-in əvvəlinə əlavə edir                                       |
| `currency: 'TRY'`            | axtarış və kataloq qiymətlərinin valyutası                                          |
| `retries: 2`                 | təkrar cəhd sayı                                                                    |
| `max_retry_wait: 30`         | klientin gözlədiyi ən uzun `Retry-After`                                            |
| `pacing: false`              | klient tərəfi sürət tənzimini söndürür                                              |
| `read_only: true`            | oxuma olmayan hər sorğunu bloklayır                                                 |
| `logger: Logger.new($stdout)`| mübadilələri loglayır: sorğuları debug, təkrar cəhdləri warn, uğursuzluqları error səviyyəsində |
| `on_trace: ->(event) {}`     | hər sorğunu, cavabı və təkrar cəhdi müşahidə edir                                   |
| `transport: my_transport`    | öz HTTP qatınız (proksi, bağlantı hovuzu, ...): `call(request)` metodu olan istənilən obyekt |

`DomainNameApi::NetHTTPTransport.new(proxy: 'http://proxy:8080', ca_file: 'corp-ca.pem')` proksi və ya öz CA paketinizlə
işləyən susmaya görə transport-dur. Yönləndirmələr heç vaxt izlənmir: API naməlum və ya dayandırılmış reseller ID üçün 302 ilə cavab
verir, bu da autentifikasiya xətasına çevrilir.

## Kodunuzun test edilməsi

API kimi cavab verən transport ötürün; başqa heç nəyi mock etmək lazım deyil:

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

`request` `DomainNameApi::PreparedRequest` obyektidir (`http_method`, `url`, `headers`, `body`), buna görə saxta transport nəyin
göndərildiyini də yoxlaya bilər. Susmaya görə transport `Net::HTTP` olduğu üçün WebMock və VCR də işləyir.

## v1-dən keçid

v2 yeni dizayndır: String açarlı Hash-lər əvəzinə tipli nəticələr, `{'result' => 'ERROR'}` zərfləri əvəzinə
exception-lar və php-dna metod dəsti əvəzinə bütün API. Gem adı `domainnameapi` olaraq qalır; keçid edənə qədər v1-də qalmaq üçün
`tag: 'v1.0.1'` ilə sabitləyin.

| v1                                                   | v2                                                                       |
|------------------------------------------------------|--------------------------------------------------------------------------|
| `Client.new(id, key, true)`                          | `Client.new(reseller_id: id, api_key: key, environment: :ote)`           |
| `res['result'] == 'OK'`                              | exception qaldırılmaması                                                 |
| `get_reseller_details`, `get_current_balance`        | `account.get` (+ `account.balance('USD')`)                               |
| `check_availability`                                 | `domains.search`, `domains.bulk_search`                                  |
| `get_list`                                           | `domains.list`, `domains.all`                                            |
| `get_tld_list`                                       | `products.tlds`, `products.all_tlds`, `products.tld`                     |
| `get_details`, `get_contacts`, `sync_from_registry`  | `domains.info`                                                           |
| `register_with_contact_info`                         | `domains.register_with_contacts` (və ya `contacts.create` + `domains.register`) |
| `renew`, `transfer`, `check_transfer`                | `domains.renew`, `domains.transfer`, `domains.transfer_check`            |
| `modify_name_server`                                 | `domains.set_name_servers`                                               |
| `enable_theft_protection_lock` / `disable_...`       | `domains.lock` / `domains.unlock`                                        |
| `modify_privacy_protection_status`                   | `domains.set_privacy`                                                    |
| `save_contacts`                                      | `domains.update_contacts`, `domains.set_contact_handles`                 |
| `add_child_name_server`, `modify_child_name_server`, `delete_child_name_server` | `domains.add_host`, `domains.update_host`, `domains.delete_host` |
| `get_resource_records`                               | `dns.list`                                                               |
| `add_resource_record`, `add_resource_record_value`   | `dns.add`                                                                |
| `edit_resource_record`, `set_resource_record_set`, `replace_resource_record_value` | `dns.update`                               |
| `delete_resource_record`, `remove_resource_record_value`, `delete_resource_record_set` | `dns.delete` (hər dəyər üçün bir dəfə) |
| `apply_resource_records`                             | `dns.apply`                                                              |
| `get_forwarding`, `set_forwarding`, `delete_forwarding` | `domains.forwarding`, `domains.set_forwarding`, `domains.delete_forwarding` |
| `cancel_transfer`, `approve_transfer`, `reject_transfer` | dərc edilmiş API-də yoxdur; hesabınızda varsa [öz sorğunuzu](#sorğular-və-baserequest) göndərin |
| `is_tr_tld`, `validate_contact`                      | `name.end_with?('.tr')`; doğrulama hər sorğuda işləyir                   |
| `get_request_data`, `get_response_data`, ...         | `on_trace:`, `logger:`, `client.execute(request)`                        |
| telemetry (`set_error_reporting_enabled`, Sentry)    | silindi: prosesinizdən kənara heç nə çıxmır; `on_trace` hadisələrini öz hesabat sisteminizə yönləndirin |
| `set_ssl_verification(false)`                        | öz CA paketinizlə `transport: NetHTTPTransport.new(ca_file: ...)`        |

## Layihənin hazırlanması

```bash
bundle install
bundle exec rake test   # vahid testlər; heç biri şəbəkəyə çıxmır
```

`test/fixtures/openapi.json` API-nin OpenAPI sənədidir. Testlər hər sorğu sinfini bu sənədə qarşı (metod, yol, query adları,
gövdə sahələri, məcburi sahələr), hər cavab modelinin JSON adlarını cavab sxemlərinə qarşı və hər enum dəyərini yoxlayır;
API-yə sorğu sinfi olmayan yeni əməliyyat əlavə olunduqda uğursuz olur. Yeniləmək üçün:

```bash
curl -fsSL -A "ruby-dna-spec-update" -o test/fixtures/openapi.json https://api.domainresellerapi.com/swagger/v1/swagger.json
bundle exec rake test
```

Bu repozitoriyanın qaydaları üçün [AGENTS.md](AGENTS.md) faylına baxın.

## Dəstək

- API sənədləşməsi: <https://www.domainnameapi.com/docs/>
- CLI və MCP serveri: <https://github.com/domainreseller/cli>
- Veb sayt: <https://www.domainnameapi.com>

## Lisenziya

Apache License 2.0. [LICENSE](LICENSE) faylına baxın.
