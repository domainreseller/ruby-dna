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

# ruby-dna: Domain Name API için Ruby SDK'sı

[![CI](https://github.com/domainreseller/ruby-dna/actions/workflows/ci.yml/badge.svg)](https://github.com/domainreseller/ruby-dna/actions/workflows/ci.yml)
[![License](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](LICENSE)

[Domain Name API](https://www.domainnameapi.com) bayi REST API'si için Ruby istemcisi: alan adı sorgulama,
kayıt, yenileme ve transfer, DNS, DNSSEC, iletişim kayıtları, SSL sertifikaları, hosting, siparişler, ürün
kataloğu ve bakiyeniz.

- **API'nin 67 işleminin tamamı**, [`dna` CLI](https://github.com/domainreseller/cli) ile aynı şekilde gruplanmıştır:
  `dna domain info` komutu `client.domains.info`, `dna dns add` komutu `client.dns.add` karşılığıdır.
- **Hash'ler değil, gerçek nesneler**: `domain.status.pending_delete?`, `domain.expiration_date` bir `Time` nesnesidir,
  `availability.available?`, `tld.register_price(1)`.
- **Her işlem bir istek sınıfıdır**; `DomainNameApi::BaseRequest` sınıfından türer ve herhangi bir şey gönderilmeden önce
  kendini doğrular. Kendi isteklerinizi de aynı şekilde yazabilirsiniz.
- **Varsayılan olarak güvenli**: ücretlendirilen istekler körlemesine yeniden denenmez, `read_only: true` değişiklikleri engeller,
  istemci hız sınırlarının altında kalacak şekilde kendini ayarlar ve thread'ler arasında güvenle paylaşılabilir.
- **Bağımlılık yok.** Ruby 3.1 veya üzeri, yalnızca standart kütüphane.

```ruby
client = DomainNameApi::Client.new(reseller_id: reseller_id, api_key: api_key, environment: :ote)

a = client.domains.search('example.com')
puts "#{a.domain_name} is available for #{a.price} #{a.currency}" if a.available?
```

## İçindekiler

- [Kurulum](#kurulum)
- [Kimlik bilgileri ve ortamlar](#kimlik-bilgileri-ve-ortamlar)
- [Servisler](#servisler)
- [Kullanım](#kullanım)
- [Sonuçlar, modeller ve enum'lar](#sonuçlar-modeller-ve-enumlar)
- [API istekleri ve BaseRequest](#api-istekleri-ve-baserequest)
- [Hatalar](#hatalar)
- [Güvenlik ve güvenilirlik](#güvenlik-ve-güvenilirlik)
- [Client seçenekleri](#client-seçenekleri)
- [Kodunuzu test etme](#kodunuzu-test-etme)
- [v1'den geçiş](#v1den-geçiş)
- [Geliştirme](#geliştirme)

## Kurulum

> ⬇️ [Releases](https://github.com/domainreseller/ruby-dna/releases/latest) sayfasından etiketlenmiş bir sürüm kullanın.
> Yeşil **Code → Download ZIP** butonu size geliştirme dalını (development branch) verir.

Bundler ile:

```ruby
# Gemfile
gem 'domainnameapi', git: 'https://github.com/domainreseller/ruby-dna.git', tag: 'v2.1.0'
```

Ya da sürüme eklenmiş `.gem` dosyasını kurun:

```bash
gem install ./domainnameapi-2.1.0.gem
```

```ruby
require 'domainnameapi'
```

Çalıştırılabilir programlar [examples](examples) klasöründedir: `quickstart`, `register`, `expiring`, `dns`, `ssl` ve
`custom_request`.

```bash
DNA_RESELLER_ID=... DNA_API_KEY=... DNA_ENV=ote ruby examples/quickstart.rb example.com
```

## Kimlik bilgileri ve ortamlar

Bayi panelinden (**API ayarları**) iki API kimlik bilgisi almanız gerekir. Panel giriş bilgileri çalışmaz.

| Kimlik bilgisi | Görünümü                               |
|----------------|----------------------------------------|
| Reseller ID    | `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx` |
| API key        | uzun bir gizli dize                    |

İki ortam vardır. **Test ortamı olan OTE ile başlayın**: kendi verisi ve kendi API anahtarı vardır; orada
yaptığınız hiçbir şey ücret doğurmaz ve canlı alan adlarına dokunmaz.

```ruby
# Test ortamı (OTE)
client = DomainNameApi::Client.new(reseller_id: reseller_id, api_key: ote_api_key, environment: :ote)

# Production (varsayılan): gerçek kayıtlar, gerçek ücretlendirme
client = DomainNameApi::Client.new(reseller_id: reseller_id, api_key: api_key)
```

`environment:`, panellerin sakladığı dizeleri de kabul eder: `'production'`, `'ote'`, `'test'` ve test modu bayrakları
(`'true'`, `'1'`, `true`). `Client.from_env`, `dna` CLI ile aynı değişkenleri okur:

| Değişken          | Anlamı                                                        |
|-------------------|---------------------------------------------------------------|
| `DNA_RESELLER_ID` | reseller ID                                                   |
| `DNA_API_KEY`     | seçilen ortamın API anahtarı                                  |
| `DNA_ENV`         | `production` (varsayılan) veya `ote`                          |
| `DNA_TEST_MODE`   | `true` OTE'yi seçer (diğer DomainNameAPI SDK'larındaki gibi)  |
| `DNA_BASE_URL`    | özel bir temel URL, ör. bir proxy                             |
| `DNA_APP`         | uygulamanız, `X-App` olarak gönderilir (varsayılan `ruby`)    |
| `DNA_APP_VERSION` | uygulamanın sürümü, `X-Version` olarak gönderilir (varsayılan: gem sürümü) |

```ruby
client = DomainNameApi::Client.from_env(user_agent: 'my-panel/1.4')
```

Yanlış bir anahtar veya ortam, ilk istekte `auth?` değeri true olan ve `hint` değeri neyin kontrol edileceğini söyleyen bir
`APIError` ile başarısız olur; denemenin en ucuz yolu `client.account.get` çağrısıdır.

## Servisler

| Servis             | CLI grubu     | İşlemler                                                                                                                                                         |
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

Zorunlu girdiler konumsal argüman olarak verilir (`info('example.com')`), geri kalan her şey keyword argümanıdır
(`renew('example.com', years: 1)`). Çok sayıda isteğe bağlı girdisi olan işlemler keyword argümanları ya da bir istek nesnesi alır:
`register(domain_name: ..., years: 1, ...)` ile `register(DomainNameApi::DomainRegisterRequest.new(...))` aynıdır.
`ssl.purchase`, CLI'daki `dna ssl initialize` komutunun karşılığıdır (`initialize`, Ruby'de ayrılmış bir addır).

## Kullanım

Tüm kod parçaları bir `client` olduğunu varsayar.

### Arama

```ruby
a = client.domains.search('example.com')
a.available?            # a.price, a.currency, a.premium?, a.document_required?, a.reason

client.domains.bulk_search('example.com', 'example.net', 'example.org').each do |r|
  puts "#{r.domain_name} #{r.status} #{r.price}"
end
```

`bulk_search`, 30 alan adından uzun listeleri birkaç isteğe böler. Fiyatlar hesabın para birimiyle, istemcinin
`currency: 'TRY'` seçeneğiyle ya da `search('example.com', currency: 'USD')` ile verilen para birimiyle gelir.

### Kayıt

İletişim handle'ları ile (bir tane `contacts.create` ile oluşturun):

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
  handles: handle # dört rolün tümü için tek bir handle veya { registrant: 'DNA-1', admin: 'DNA-2', tech: ..., billing: ... }
)
result.status           # result.domain_id, result.expiration_date
```

Satır içi iletişim bilgileri ile:

```ruby
client.domains.register_with_contacts(
  domain_name: 'example.com',
  name_servers: %w[ns1.example.net ns2.example.net],
  contacts: owner # dört rolün tümü için tek bir Contact veya { registrant: owner, admin: admin, tech: admin, billing: admin }
)
```

İletişim bilgileri `DomainNameApi::Contact` nesneleri ya da aynı alanları içeren Hash'ler olabilir. Gönderilmeden önce düzenlenirler:
alanların baş ve sonundaki boşluklar silinir, ülke kodu büyük harfe çevrilir ve telefon alanlarında yalnızca rakamlar tutulur
(`'+90 (555) 123-45-67'` çalışır). Bazı TLD'ler sicil (registry) öznitelikleri ister: bunları
`client.products.tld('com.tr').required_attributes` ile bulun ve `tld_attributes:` olarak iletin.

API yanıt verip isteği reddederse (`"success": false`), metot API'nin mesajını taşıyan bir `DomainNameApi::OperationError`
hatası fırlatır.

### Yenileme, transfer, geri alma

```ruby
check = client.domains.renew_check('example.com', years: 1)   # check.renewable?, check.premium_price
client.domains.renew('example.com', years: 1)

tc = client.domains.transfer_check('example.com', 'auth-code') # tc.transferable?, tc.auth_code_valid?
client.domains.transfer('example.com', auth_code: 'auth-code')
client.domains.transfer_status('example.com').status

client.domains.restore('example.com') # itfa (redemption) döneminde
```

### Alan adı ayrıntıları ve alan adı listesi

```ruby
d = client.domains.info('example.com')
d.status                # => #<DomainNameApi::DomainStatus Active (0)>
d.expiration_date       # => 2027-03-15 10:20:30 UTC
d.remaining_days, d.locked?, d.privacy_protection?, d.name_servers, d.auth_code, d.hosts
d.contact(:registrant)&.email

# Tek sayfa
page = client.domains.list(limit: 50, sort: 'expirationDate')
page.total_count
page.each { |domain| puts domain.domain_name }

# Tüm alan adları; sayfalar ilerledikçe getirilir
client.domains.all(statuses: [:active]) do |domain|
  puts "#{domain.domain_name} #{domain.expiration_date}"
end
client.domains.all.first(10) # blok verilmezse bir Enumerator döner: tek sayfa getirir
```

### Kilit, gizlilik, name server'lar, child name server'lar

```ruby
client.domains.lock('example.com')
client.domains.unlock('example.com')
client.domains.set_privacy('example.com', true)
code = client.domains.update_auth_code('example.com')

client.domains.set_name_servers('example.com', %w[ns1.example.net ns2.example.net])
client.domains.set_name_servers('example.com', %w[ns1.other.net ns2.other.net], dnssec_mode: :disable) # DNSSEC imzalı alan adları için

client.domains.add_host('example.com', 'ns1.example.com', '192.0.2.10', '2001:db8::10') # IP sürümü otomatik algılanır
client.domains.update_host('example.com', 'ns1.example.com', ip_addresses: ['192.0.2.20'])
client.domains.delete_host('example.com', 'ns1.example.com')
```

### Bir alan adının iletişim kayıtları

```ruby
client.domains.set_contact_handles('example.com', admin: 'DNA-2', tech: 'DNA-2') # diğer roller aynı kalır
client.domains.update_contacts('example.com', billing: billing_contact)

details = client.contacts.get('DNA-1')               # iletişim kaydı ve doğrulama durumu
result = client.contacts.update('DNA-1', contact)    # handle'ı kullanan tüm alan adlarını günceller
result.affected_domains.each { |a| puts "#{a.domain_name} #{a.new_handle}" }
client.contacts.resend_verification('DNA-1')          # doğrulanacak bir şey yoksa false
```

### DNS bölgesi

```ruby
client.dns.add('example.com', name: 'www', type: :a, values: '192.0.2.10', ttl: 600)
client.dns.update('example.com', record_name: 'www', type: :a, values: %w[192.0.2.20 192.0.2.21]) # kümenin tamamını değiştirir
client.dns.delete('example.com', name: 'www', type: :a, value: '192.0.2.20')

client.dns.list('example.com').each do |set|
  puts "#{set.name} #{set.type} #{set.ttl} #{set.values.join(', ')}"
end

client.dns.apply('example.com') # alan adını platformun name server'larına geçirir
```

İsimler göreli (`'www'`), kök (`''` veya `'@'`) ya da tam nitelikli olabilir. Kayıt türleri, herhangi bir harf biçiminde sembol veya
dize olabilir (`:txt` ve `'txt'`, `TXT` olarak gönderilir). Doğrulama, API'nin reddedeceği durumları yakalar: kökte CNAME,
üç parçası olmayan CAA değeri, önceliği olmayan MX değeri, IPv6 adresi içeren A kaydı. Test ortamı her bölge çağrısına
HTTP 500 yanıtı verir; bu yüzden bölge kodu yalnızca production'da denenebilir.

### DNSSEC

```ruby
results = client.dnssec.add('example.com', '2371 13 2 1F987CC6583E92DF0890718C42...') # DNS sağlayıcınızın gösterdiği haliyle
info = client.dnssec.get('example.com') # info.status.signed?, info.ds_records
client.dnssec.disable('example.com')
```

`DomainNameApi::DS.parse`, sunum biçimini (presentation format) ve zone dosyası satırlarının tamamını okur; `DS.new(key_tag: ...,
algorithm: :ecdsa_p256_sha256, digest_type: :sha256, digest: '...')` da çalışır.

### URL yönlendirme

```ruby
client.domains.set_forwarding('example.com', 'https://www.example.org')              # 301 yönlendirmesi
client.domains.set_forwarding('example.com', 'https://www.example.org', type: :frame) # maskeli
f = client.domains.forwarding('example.com') # alan adında yönlendirme yoksa nil
client.domains.delete_forwarding('example.com')
```

### Sicil belgeleri (.tr)

```ruby
doc = DomainNameApi::DocumentUpload.from_file(:identity_card, 'id.pdf')
client.domains.upload_documents('example.com.tr', doc)
client.domains.documents('example.com.tr').each { |d| puts "#{d.name} #{d.status}" }
```

Dosyalar sizin için base64 ile kodlanır; biçim (PDF, JPG, PNG, DOC, DOCX, ODT) ve boyut (dosya başına 10 MB,
istek başına 50 MB) yüklemeden önce kontrol edilir.

### SSL sertifikaları

```ruby
csr = client.ssl.generate_csr(domain_name: 'example.com', country: 'TR', state: 'Istanbul', locality: 'Istanbul',
                              organization: 'Example Ltd', organization_unit: 'IT')
# bakiyeden ücret keser (CLI: dna ssl initialize)
order = client.ssl.purchase('example.com', package_code: 'PositiveSSL')
id = order.certificate_id # saklayın: sonraki her çağrıda gerekir
client.ssl.configure(certificate_id: id, csr: csr.csr, approver_mail: 'admin@example.com',
                     authentication_type: :email, web_server_type: :apache, contact: ssl_contact)
client.ssl.status(id).issued? # true olana kadar sorgulayın
File.write('example.com.crt', client.ssl.content(id).chain)
```

Bir alan adının birden fazla sertifikası olabilir; bu nedenle mevcut bir sertifika alan adıyla değil,
`certificate_id` değeriyle (bir GUID) belirtilir: `purchase` ve `renew` bu değeri döndürür, `list` ise onu bulur.
Kimlik beklenen yere alan adı verilirse, hiçbir şey gönderilmeden `InputError` fırlatılır. Sertifikayı satın
aldıktan veya yeniledikten sonra 15 gün içinde yapılandırın.

```ruby
client.ssl.list(domain_name: 'example.com').each { |c| puts "#{c.certificate_id} #{c.status}" } # en yeni en başta
client.ssl.all { |c| puts "#{c.domain_name} #{c.subscription_expires_at}" } # tüm sertifikalar, sayfa sayfa

client.ssl.approvers(certificate_id: id)                                      # mevcut bir sertifika için
client.ssl.approvers(domain_name: 'example.com', package_code: 'PositiveSSL') # satın almadan önce

renewal = client.ssl.renew(id) # bakiyeden ücret keser; abonelik bitimine 30 gün kala mümkün olur
client.ssl.configure(certificate_id: renewal.certificate_id, csr: new_csr.csr, approver_mail: 'admin@example.com',
                     authentication_type: :email, web_server_type: :apache, contact: ssl_contact)
```

Yenilemek için `renew` çağırın ve döndürdüğü yeni sertifikayı `configure` ile yapılandırın. Yeniden `purchase`
çağırmayın: bu, satın alma fiyatı üzerinden ilgisiz yeni bir sipariştir ve eski sertifika hiçbir zaman `Renewed`
durumuna geçmez.

### Hosting

```ruby
client.hosting.packages.each { |p| puts p.service_plans.map(&:service_plan) }
created = client.hosting.create('example.com', service_plan: 'Linux-Starter') # bakiyeden ücret keser

st = client.hosting.wait(created.service_id, timeout: 30 * 60) # aktif olana kadar sorgular
puts st.panel_address, st.username, st.password
```

Hâlâ hazırlanmakta olan bir hosting için `create` metodunu bir daha çağırmayın: iki kez ücret alınır.

### Bakiye, fiyatlar ve siparişler

```ruby
account = client.account.get
account.balance('USD')
profile = client.account.profile # profile.company_name, profile.account_currency, profile.status.active?

client.account.all_transactions(from: Date.new(2026, 11, 1)) do |tx|
  puts "#{tx.creation_time} #{tx.type} #{tx.change}"
end

tld = client.products.tld('com.tr')
tld&.register_price(1)&.to_s   # => "12.50 USD"

client.products.info('com', order_type: :renew, years: 2) # 2 yıllık .com yenilemesinin fiyatı
client.orders.get('ORDER-CODE')
```

## Sonuçlar, modeller ve enum'lar

Her sonuç bir `DomainNameApi::Model` nesnesidir: snake_case okuma metotları, bayraklar için `?` ile biten sorgu metotları, tarihler
için `Time` nesneleri, iç içe modeller ve listeler.

```ruby
d = client.domains.info('example.com')
d.locked?                 # ayrıca d.locked
d.hosts.first.ip_addresses.first.address
d.to_h                    # snake_case anahtarlı düz bir Hash
d.raw                     # API'nin gönderdiği haliyle JSON nesnesi; bu gem'in modellemediği alanlar için
```

Sayısal ve sabit dizeli değerler enum'dur (`DomainStatus`, `RecordType`, `ContactType`, `DocumentType`, ...):

```ruby
d.status.pending_delete?                       # her üye için bir sorgu metodu
d.status == DomainNameApi::DomainStatus::ACTIVE
d.status == :active                            # semboller, adlar ve sayılarla da karşılaştırılabilir
d.status.to_s                                  # => "Active"
d.status.to_i                                  # => 0
DomainNameApi::DomainStatus.members            # hepsi
```

İstekler enum'ları, sembolleri, herhangi bir harf biçimindeki adları veya sayıları kabul eder: `statuses: [:active, 'PendingDelete', 7]`.

Çözümleme toleranslıdır: saat dilimi olmayan tarihler, `null`, `{}` yerine `[]`, dize olarak gönderilen sayılar, herhangi bir harf
biçimindeki roller (`"registrant"`, `"ADMINISTRATIVE"`) ve bu gem'in henüz tanımadığı değerler, çağrıyı başarısız kılmak yerine
çözümlenir (sonuncusu için `status.known?` false döner).

## API istekleri ve BaseRequest

Her API işlemi bir istek sınıfıdır: `DomainInfoRequest`, `DNSAddRequest`, `SSLConfigureRequest`, ... Adlarını CLI komutundan
alırlar (`dna domain renew` komutu `DomainRenewRequest` karşılığıdır). Hepsi `DomainNameApi::BaseRequest` sınıfından türer; bu sınıf
altyapıyı sağlar: sınıf düzeyinde `endpoint` ve `attribute` DSL'i, keyword argümanlarıyla başlatma, doğrulama yardımcıları, yol
şablonları ve sorgu/gövde oluşturucuları. Liste istekleri, `skip`, `limit` ve `sort` ekleyen `PagedRequest` sınıfından
türer. Bu gem'deki bir istek şöyle görünür:

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

Servis metotları bunları sizin için oluşturur. `client.call`, kendi sınıflarınız dahil herhangi bir isteği gönderir; örneğin
yalnızca ihtiyacınız olan alanları okumak ya da bu gem'in henüz sarmalamadığı bir uç noktayı çağırmak için:

```ruby
class Expiry < DomainNameApi::Model
  field :expiration_date, :time
  field :remaining_days, :integer, from: 'remainingDay'
end

class ExpiryRequest < DomainNameApi::BaseRequest
  endpoint :get, '/api/v1/domains/info', safety: :read
  returns Expiry            # yazmazsanız ayrıştırılmış JSON döner
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

| Geçersiz kılınan | Varsayılan        | Amacı                                                                                    |
|------------------|-------------------|------------------------------------------------------------------------------------------|
| `query`          | `nil`             | bir `Query` (`params.string(...)`), bir Hash veya ikililerden oluşan bir Array            |
| `body`           | `nil`             | API'nin adlarını kullanan bir Hash veya Array; enum'lar, modeller ve zamanlar dönüştürülür |
| `validate`       | kontrol yok       | sorunları `required`, `check`, `between`, `max_length`, `enum` ile bildirin              |
| `decode(data)`   | `returns` kullanılır | ayrıştırılmış JSON'u sonucunuza dönüştürün                                           |

Yoldaki yer tutucular attribute'lardan doldurulur ve kaçışlanır (escape): `endpoint :get, '/api/v1/contacts/{handle}'`.

İsteğiniz, yerleşik isteklerin sahip olduğu her şeye sahip olur: kimlik bilgileri, yeniden denemeler, hız ayarı, hata normalleştirme,
korelasyon ID'leri, izleme ve salt okunur kısıtlama. `client.execute(request)`, çözümlenmiş sonuç `value` içinde olmak üzere `Response`
nesnesinin tamamını (durum, başlıklar, ham gövde, korelasyon ID'si, kota, deneme sayısı) döndürür.
`client.prepare(request)`, ücretlendirilen bir isteği gönderilmeden önce loglamak veya gözden geçirmek için tam HTTP isteğini doğrular ve
göndermeden oluşturur (API anahtarı `inspect` çıktısında maskelenir).

## Hatalar

| Hata                             | Ne zaman                                                   | Faydalı metotlar                                                               |
|----------------------------------|------------------------------------------------------------|--------------------------------------------------------------------------------|
| `DomainNameApi::InputError`      | doğrulama isteği reddetti; **hiçbir şey gönderilmedi**     | `request`, `fields`                                                            |
| `DomainNameApi::APIError`        | API 2xx olmayan bir durum koduyla yanıt verdi              | `status`, `code`, `api_message`, `details`, `fields`, `data`, `correlation_id`, `hint` |
| `DomainNameApi::OperationError`  | API 2xx ve `"success": false` ile yanıt verdi              | `code`, `api_message`, `correlation_id`                                        |
| `DomainNameApi::NetworkError`    | istek tamamlanmadı (DNS, TLS, zaman aşımı, bağlantı kopması) | `original`, `timeout?`                                                       |
| `DomainNameApi::ReadOnlyError`   | salt okunur bir istemci bir değişikliği engelledi; hiçbir şey gönderilmedi | `safety`                                                       |

Hepsi, sık sorulan soruları yanıtlayan `DomainNameApi::Error` sınıfından türer: `kind` (`:auth`,
`:not_found`, `:validation`, `:rejected`, `:conflict`, `:rate_limited`, `:server`, `:network`, `:invalid_input`,
`:read_only`), `not_found?`, `auth?`, `rate_limited?`, `insufficient_balance?`, `outcome_unknown?`,
`retryable?` ve `code?(code)`.

```ruby
begin
  client.domains.renew('example.com', years: 1)
rescue DomainNameApi::Error => e
  if e.outcome_unknown?
    # Yenileme gerçekleşmiş olabilir. Tekrar denemeden önce alan adını kontrol edin.
  elsif e.insufficient_balance?
  elsif e.not_found?
  elsif e.code?(DomainNameApi::ErrorCode::PRIVACY_NOT_SUPPORTED)
  elsif e.is_a?(DomainNameApi::APIError)
    logger.error("#{e.code} #{e.api_message} #{e.hint} #{e.correlation_id}")
  end
end
```

Mesaj üzerinden değil, `code` üzerinden dallanın: mesajlar yerelleştirilir. API kodları
`Dna.DomainService:Domain:10007` gibi görünür; sık kullanılanlar `DomainNameApi::ErrorCode` içinde sabit olarak bulunur, geri kalanlar
[hata başvurusunda](https://www.domainnameapi.com/docs/reference/errors.md) yer alır. Destekle iletişime geçerken `correlation_id` değerini
belirtin.

## Güvenlik ve güvenilirlik

- **Güvenlik sınıfları.** Her istek `:read`, `:write`, `:destructive` veya `:billable` sınıfındandır (`request.safety`,
  `request.billable?`). Bazı POST ve PUT istekleri okumadır (`DomainSearchRequest`, `SSLStatusRequest`).
- **Salt okunur mod.** `read_only: true`, okuma olmayan her şeyi engeller; raporlama işleri ve production'ı güvenle
  keşfetmek içindir.
- **Yeniden denemeler.** 429 yanıtları her zaman, `Retry-After` değerine uyularak yeniden denenir: API bunları herhangi bir
  işlem yapmadan reddeder. Ağ hataları ve 502/503/504 yalnızca okumalar ve idempotent yazmalar için yeniden denenir; böylece bir kayıt
  veya yenileme asla iki kez gönderilmez. Ücretlendirilen bir istek başarısız olduktan sonra `e.outcome_unknown?` değerini kontrol edin.
- **Hız ayarı.** İstemci, anahtar başına sınırların altında kalmak için istekleri aralıklandırır (saniyede 5 istek, saniyede 2 arama,
  saniyede bir bölge çağrısı). Hız ayarını kendiniz yapıyorsanız `pacing: false` ile kapatın.
- **Kota.** `client.execute(request).quota`, yumuşak kota başlıklarını sunar. Sınır aşıldığında API yanıtları reddetmek yerine
  yavaşlatır (en fazla 5 sn); varsayılan 60 sn zaman aşımı buna yer bırakır.
- **Korelasyon ID'leri.** Her istek bir `X-Correlation-ID` taşır. API çağrılarını loglarınızla ilişkilendirmek için kendi değerinizi ayarlayın:
  `DomainNameApi.with_correlation_id(job.id) { ... }` veya `client.call(request, correlation_id: job.id)`.
- **Gözlemlenebilirlik.** `logger: Logger.new($stdout)` her alışverişi loglar; `on_trace: ->(event) { ... }` size her isteği, yanıtı
  ve yeniden denemeyi bir `TraceEvent` olarak iletir; metrikler veya hata raporlama için kullanılabilir. API anahtarı bunların hiçbirinde
  yer almaz; gövdeler iletişim bilgileri içerebilir, bu yüzden saklamadan önce maskeleyin.
- **Thread'ler.** Bir istemci thread'ler arasında güvenle paylaşılabilir. Bir tane oluşturun ve yeniden kullanın.
- **Sürecinizin dışına başka hiçbir şey çıkmaz.** Telemetri yok, üçüncü taraf servis yok.

## Client seçenekleri

| Seçenek                      | Etkisi                                                                              |
|------------------------------|-------------------------------------------------------------------------------------|
| `environment: :ote`          | test ortamını kullanır (varsayılan `:production`)                                   |
| `base_url: 'https://...'`    | istekleri bir proxy'ye veya test sunucusuna gönderir                                |
| `timeout: 60`                | HTTP denemesi başına saniye                                                         |
| `open_timeout: 10`           | bağlantı kurmak için saniye                                                         |
| `user_agent: 'app/1.0'`      | ürününüzü User-Agent'ın başına ekler                                                |
| `app_name: 'whmcs'`          | uygulamanız, `X-App` başlığında gönderilir (varsayılan `ruby`)                      |
| `app_version: '8.13.1'`      | uygulamanın sürümü, `X-Version` başlığında gönderilir (varsayılan: gem sürümü)      |
| `currency: 'TRY'`            | arama ve katalog fiyatlarının para birimi                                           |
| `retries: 2`                 | yeniden deneme sayısı                                                               |
| `max_retry_wait: 30`         | istemcinin bekleyeceği en uzun `Retry-After` süresi                                 |
| `pacing: false`              | istemci tarafı hız ayarını kapatır                                                  |
| `read_only: true`            | okuma olmayan her isteği engeller                                                   |
| `logger: Logger.new($stdout)`| alışverişleri loglar: istekleri debug, yeniden denemeleri warn, hataları error düzeyinde |
| `on_trace: ->(event) {}`     | her isteği, yanıtı ve yeniden denemeyi gözlemler                                    |
| `transport: my_transport`    | kendi HTTP katmanınız (proxy, bağlantı havuzu, ...): `call(request)` metodu olan herhangi bir nesne |

`DomainNameApi::NetHTTPTransport.new(proxy: 'http://proxy:8080', ca_file: 'corp-ca.pem')`, bir proxy veya kendi CA paketinizle
kullanılan varsayılan transport'tur. Yönlendirmeler asla izlenmez: API, bilinmeyen veya askıya alınmış bir reseller ID için 302 yanıtı
verir ve bu bir kimlik doğrulama hatasına dönüşür.

### Entegrasyonunuzu tanıtma

Her istek, API'ye onu hangi uygulamanın gönderdiğini bildiren iki başlık taşır: `X-App` (varsayılan `ruby`)
ve `X-Version` (varsayılan: gem sürümü). Bunları kendi panelinize veya modülünüze ve onun sürümüne ayarlayın:

```ruby
client = DomainNameApi::Client.new(reseller_id: reseller_id, api_key: api_key,
                                   app_name: 'WiseCP', app_version: 'V2.0.20-beta')
# X-App: wisecp, X-Version: 2.0.20
```

Ad küçük harfe çevrilir ve yalnızca `a-z`, `0-9`, `.`, `_` ve `-` karakterleri korunur; sürümde yalnızca
rakamlar ve noktalar kalır. Boş bir ad `ruby` değerine, boş bir sürüm gem sürümüne döner. `Client.from_env`
bunları `DNA_APP` ve `DNA_APP_VERSION` değişkenlerinden okur. User-Agent değişmez.

## Kodunuzu test etme

API gibi yanıt veren bir transport verin; başka hiçbir şeyi mock'lamanız gerekmez:

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

`request` bir `DomainNameApi::PreparedRequest` nesnesidir (`http_method`, `url`, `headers`, `body`); bu yüzden sahte transport neyin
gönderildiğini de doğrulayabilir. Varsayılan transport `Net::HTTP` olduğu için WebMock ve VCR de çalışır.

## v1'den geçiş

v2 yeni bir tasarımdır: String anahtarlı Hash'ler yerine tipli sonuçlar, `{'result' => 'ERROR'}` zarfları yerine
exception'lar ve php-dna metot kümesi yerine API'nin tamamı. Gem adı `domainnameapi` olarak kalır; geçiş yapana kadar v1'de kalmak için
`tag: 'v1.0.1'` ile sabitleyin.

| v1                                                   | v2                                                                       |
|------------------------------------------------------|--------------------------------------------------------------------------|
| `Client.new(id, key, true)`                          | `Client.new(reseller_id: id, api_key: key, environment: :ote)`           |
| `res['result'] == 'OK'`                              | exception fırlatılmaması                                                 |
| `get_reseller_details`, `get_current_balance`        | `account.get` (+ `account.balance('USD')`)                               |
| `check_availability`                                 | `domains.search`, `domains.bulk_search`                                  |
| `get_list`                                           | `domains.list`, `domains.all`                                            |
| `get_tld_list`                                       | `products.tlds`, `products.all_tlds`, `products.tld`                     |
| `get_details`, `get_contacts`, `sync_from_registry`  | `domains.info`                                                           |
| `register_with_contact_info`                         | `domains.register_with_contacts` (veya `contacts.create` + `domains.register`) |
| `renew`, `transfer`, `check_transfer`                | `domains.renew`, `domains.transfer`, `domains.transfer_check`            |
| `modify_name_server`                                 | `domains.set_name_servers`                                               |
| `enable_theft_protection_lock` / `disable_...`       | `domains.lock` / `domains.unlock`                                        |
| `modify_privacy_protection_status`                   | `domains.set_privacy`                                                    |
| `save_contacts`                                      | `domains.update_contacts`, `domains.set_contact_handles`                 |
| `add_child_name_server`, `modify_child_name_server`, `delete_child_name_server` | `domains.add_host`, `domains.update_host`, `domains.delete_host` |
| `get_resource_records`                               | `dns.list`                                                               |
| `add_resource_record`, `add_resource_record_value`   | `dns.add`                                                                |
| `edit_resource_record`, `set_resource_record_set`, `replace_resource_record_value` | `dns.update`                               |
| `delete_resource_record`, `remove_resource_record_value`, `delete_resource_record_set` | `dns.delete` (her değer için bir kez)  |
| `apply_resource_records`                             | `dns.apply`                                                              |
| `get_forwarding`, `set_forwarding`, `delete_forwarding` | `domains.forwarding`, `domains.set_forwarding`, `domains.delete_forwarding` |
| `cancel_transfer`, `approve_transfer`, `reject_transfer` | yayımlanan API'de yok; hesabınızda varsa [kendi isteğinizi](#api-istekleri-ve-baserequest) gönderin |
| `is_tr_tld`, `validate_contact`                      | `name.end_with?('.tr')`; doğrulama her istekte çalışır                   |
| `get_request_data`, `get_response_data`, ...         | `on_trace:`, `logger:`, `client.execute(request)`                        |
| telemetry (`set_error_reporting_enabled`, Sentry)    | kaldırıldı: sürecinizin dışına hiçbir şey çıkmaz; `on_trace` olaylarını kendi raporlama sisteminize iletin |
| `set_ssl_verification(false)`                        | kendi CA paketinizle `transport: NetHTTPTransport.new(ca_file: ...)`     |

## Geliştirme

```bash
bundle install
bundle exec rake test   # birim testleri; hiçbiri ağa erişmez
```

`test/fixtures/openapi.json`, API'nin OpenAPI belgesidir. Testler her istek sınıfını bu belgeye göre (metot, yol, sorgu adları,
gövde alanları, zorunlu alanlar), her yanıt modelinin JSON adlarını yanıt şemalarına göre ve her enum değerini kontrol eder;
API, istek sınıfı olmayan bir işlem kazandığında başarısız olur. Güncellemek için:

```bash
curl -fsSL -A "ruby-dna-spec-update" -o test/fixtures/openapi.json https://api.domainresellerapi.com/swagger/v1/swagger.json
bundle exec rake test
```

Bu deponun kuralları için [AGENTS.md](AGENTS.md) dosyasına bakın.

## Destek

- API dokümantasyonu: <https://www.domainnameapi.com/docs/>
- CLI ve MCP sunucusu: <https://github.com/domainreseller/cli>
- Web sitesi: <https://www.domainnameapi.com>

## Lisans

Apache License 2.0. [LICENSE](LICENSE) dosyasına bakın.
