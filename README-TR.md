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

# ruby-dna — Ruby için DomainNameAPI istemcisi

DomainNameAPI REST API üzerinden alan adlarını kaydedin, yenileyin ve transfer edin; kişi bilgilerini, nameserver'ları, child nameserver'ları, DNS bölgelerini ve URL yönlendirmelerini yönetin. `ruby-dna`, [php-dna](https://github.com/domainreseller/php-dna) kütüphanesinin birebir sadık bir portudur: aynı metotlar, ağa giden aynı istekler ve aynı dönüş değerleri — hepsi php-dna'nın uyumluluk (conformance) fixture'larına karşı doğrulanmıştır.

## 📦 İndirme — her zaman Releases kullanın!

⬇️ **En güncel test edilmiş sürümü buradan indirin: https://github.com/domainreseller/ruby-dna/releases/latest**

> ⚠️ Yeşil **Code → Download ZIP** butonunu **kullanmayın** — bu buton ham geliştirme dalını (development branch) indirir. Release paketleri sürümlenmiş, test edilmiş ve canlı kullanıma hazırdır.

## Kurulum ve Entegrasyon Rehberi

### Minimum Gereksinimler

- Ruby 2.7 veya daha üstü (Önerilen 3.3+)
- Çalışma zamanı bağımlılığı yoktur: yalnızca standart kütüphane (`net/http`, `json`, `openssl`) kullanılır.

### A) Bundler

```ruby
# Gemfile
gem 'domainnameapi', git: 'https://github.com/domainreseller/ruby-dna.git', tag: 'v1.0.0'
```

```bash
bundle install
```

### B) Release içindeki gem dosyası

[En son release](https://github.com/domainreseller/ruby-dna/releases/latest) sayfasından `domainnameapi-1.0.0.gem` dosyasını indirin, ardından:

```bash
gem install ./domainnameapi-1.0.0.gem
```

### C) Manuel kullanım

Release arşivini indirin, `lib` klasörünü projenize kopyalayın ve [examples](examples) klasöründeki örnekleri inceleyin:

```ruby
$LOAD_PATH.unshift File.expand_path('lib', __dir__)
require 'domainnameapi'
```

## 🔑 API Bilgileri — Reseller ID ve API Key

Kütüphane DomainNameAPI REST API ile konuşur ve constructor'a verilen yalnızca iki bilgiye ihtiyaç duyar:

| Parametre | Değer |
|---|---|
| Birinci | Reseller ID — `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx` biçiminde UUID |
| İkinci | API Key |

> 💡 **Reseller ID** ve **API Key** bilgilerinizi DomainNameAPI panelinizdeki **API Ayarları** bölümünde bulabilirsiniz.
> ⚠️ Bunlar **API bilgileridir** — panel giriş bilgileriniz burada **çalışmaz**.

## Hızlı başlangıç

```ruby
require 'domainnameapi'

reseller_id = 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx'
api_key     = 'your-api-key'

# Canlı ortam
dna = DomainNameApi::Client.new(reseller_id, api_key)

# Test (OTE) ortamı
dna = DomainNameApi::Client.new(reseller_id, api_key, true)

result = dna.get_details('example.com')
if result['result'] == 'OK'
  puts result['data']['Dates']['Expiration']
else
  puts "#{result['error']['Code']}: #{result['error']['Message']}"
end
```

Metot adları php-dna'daki adların snake_case biçimidir (`getDetails` → `get_details`, `registerWithContactInfo` → `register_with_contact_info`); parametre sırası ve varsayılan değerler aynıdır. Sonuçlar **String anahtarlı** düz Ruby Hash ve Array'leridir ve php-dna'nın döndürdüğü yapıyla birebir aynıdır (`'LockStatus' => 'true'` gibi string bayraklar ve `'11.9900'` gibi biçimlendirilmiş fiyatlar dahil). Kimlik bilgilerinin baştaki ve sondaki boşlukları temizlenir; test modu bayrağı string değerleri de kabul eder: `"true"`, `"1"`, `"on"` ve `"yes"` test modu anlamına gelir, diğer her değer canlı ortam anlamına gelir.

## Hata yönetimi

Metotlar API veya ağ sorunlarında asla exception fırlatmaz. Başarısız bir çağrı bir hata zarfı (error envelope) döndürür:

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

- Gateway hatalarında `Code` değeri `API_<HTTP durum kodu>` biçimindedir (`API_400`, `API_401`, `API_429`, `API_500`, ...). `301`/`302` yanıtı hatalı kimlik bilgisi anlamına gelir (`Invalid API credentials`).
- Gateway kendi hata kodunu gönderdiğinde, zarf bu kodu `GatewayCode` olarak da taşır (örn. `'GatewayCode' => 'Dna.DomainService:Domain:10007'`); böylece bir `API_404` hatasını diğerinden ayırt edebilirsiniz.
- Boş bir hata gövdesi, `HTTP 429 - Too Many Requests` gibi okunabilir bir mesaja dönüştürülür. Gateway'in mesajı kalıp (boilerplate) bir metin olduğunda ham yanıt gövdesi asla mesaj olarak kullanılmaz; bunun yerine gateway kodunu belirten sabit bir metin kullanılır.
- Alan doğrulama hataları `Details` içinde düz metne indirgenir, örn. `Admin PostalCode - 'PostalCode' is required`.
- Ağ hataları her zaman hata olarak döner, asla boş bir başarı olarak dönmez. Zaman aşımı `Could not reach the DomainNameAPI service: the connection timed out. (...)` şeklinde, diğer taşıma (transport) hataları ise `Curl error during request: ...` şeklinde görünür. Kodları curl'ün numaralarıyla `CURL_<n>` biçimindedir (`CURL_28` zaman aşımı, `CURL_6` DNS, `CURL_7` bağlantı reddedildi, `CURL_35`/`CURL_60` TLS, `CURL_56` bağlantı sıfırlandı); `API_<n>` ise HTTP durum kodlarına ayrılmıştır.
- Gateway'in HTTP 200 ile ama `"success": false` olarak yanıtladığı bir kayıt, transfer veya yenileme işlemi başarı değil, reddedilmedir: `REGISTER_DOMAIN`, `TRANSFER_DOMAIN` veya `RENEW_DOMAIN` koduyla ve gateway'in mesajıyla birlikte hata zarfı döndürülür.
- `get_current_balance` kendi zarf yapısını korur: `ErrorCode` ve `OperationMessage` ile birlikte `'OperationResult' => 'FAILED'`.
- `check_availability` başarılı olduğunda düz bir liste, başarısız olduğunda hata zarfı döndürür.

Yalnızca programcı hataları exception fırlatır (örneğin `contents` parametresi liste olmayan bir `set_resource_record_set` çağrısı `TypeError` fırlatır).

Zaman aşımları çağrı başına 30 saniye, bağlantı kurmak için 10 saniyedir. DNS zone uç noktalarına yapılan çağrılar arasında en az bir saniye bırakılır, çünkü gateway art arda gelen yoğun isteklere `HTTP 429` ile yanıt verir.

### Tanılama

```ruby
dna.get_request_data         # son çağrının { 'url' => ..., 'method' => 'GET', 'payload' => {...} } bilgisi
dna.get_response_data        # son çözümlenmiş yanıt gövdesi (veya { 'raw_response' => body })
dna.get_response_headers     # { 'url', 'http_code', 'headers', 'total_time' }
dna.get_parsed_response_data # son ayrıştırılmış gövde veya son hata { 'Code', 'Message', 'Details' }
dna.get_last_function        # örn. 'request:GET domains/info'
dna.get_service_url          # https://api.domainresellerapi.com/api/v1
dna.set_service_url('https://ote.domainresellerapi.com/api/v1')
```

## Test modu

OTE test gateway'ini (`https://ote.domainresellerapi.com/api/v1`) kullanmak için constructor'ın üçüncü argümanı olarak `true` verin. Canlı çağrılar `https://api.domainresellerapi.com/api/v1` adresine gider. Test modu ayrı test kimlik bilgileri kullanır.

## Hata raporlama (telemetri)

Bir API çağrısı başarısız olduğunda kütüphane, DomainNameAPI'nin kendi hata takip sistemine (Sentry) bir hata raporu gönderebilir. Başarılı çağrıların rastgele seçilen küçük bir kısmı (%4, ayrıca 1 saniyeden uzun süren her çağrı) performans kaydı olarak gönderilebilir. Bu, DomainNameAPI'nin sorunları bulup düzeltmesine yardımcı olur. Hata raporlama **varsayılan olarak açıktır**.

> ℹ️ 1.0.0 sürümünde ruby-dna için Sentry projesi henüz mevcut değildir; bu nedenle yerleşik DSN boştur ve **hiçbir şey gönderilmez**. Raporlar, DSN'i içeren bir release yayımlandığında başlar. `DomainNameApi::Client.new(id, key, false, sentry_dsn: '...')` ile açıkça bir DSN tanımlanabilir.

**Gönderilenler:**

- hata kodu ve mesajı
- çağrılan uç nokta yolu ve HTTP yöntemi
- çağrı süresi
- kütüphane adı (`DomainNameAPI-Ruby`), kütüphane sürümü ve Ruby sürümü
- bayi kimliği (Reseller ID) ve alan adı
- sunucunun genel (public) IP adresi (arka planda `api.ipify.org` üzerinden öğrenilir)
- sürecin çalıştığı işletim sistemi kullanıcı adı
- API isteği ve yanıtı, alan adının kişi bilgileri dahil; yalnızca kimlik bilgileri maskelenir — EPP/transfer kodları, API anahtarları, parolalar ve token'lar `***` ile değiştirilir

**Asla gönderilmeyenler:** okunabilir biçimde EPP/transfer kodları, API anahtarları, parolalar veya token'lar; hata izlerindeki (stack trace) metot argümanları.

Beklenen ve yüksek hacimli hatalar (alan adı bulunamadı, yetersiz bakiye, geçersiz kimlik bilgileri, ...) raporlanmaz. Raporlar kısa zaman aşımlarıyla bir arka plan thread'inden gönderilir: çağrınızı asla yavaşlatmaz veya bozmaz.

**Neden ve ne kadar süre:** veriler yalnızca kullanım ölçümü ve sorunların erken teşhisi için kullanılır; DomainNameAPI'nin kendi Sentry sunucusunda 30 gün saklanır, ardından otomatik olarak silinir.

**Nasıl kapatılır:**

```ruby
dna = DomainNameApi::Client.new(reseller_id, api_key)
dna.set_error_reporting_enabled(false)
```

**Minimal mod** yalnızca hata kodu ve mesajını, uç noktayı, süreyi, sürüm bilgilerini ve Reseller ID'yi gönderir — istek/yanıt verisi, alan adı, sunucu IP'si veya kullanıcı adı gönderilmez:

```ruby
dna.set_telemetry_minimal(true)
```

> 🔒 **Güvenlik:** TLS sertifika doğrulaması açıktır. CA paketi güncel olmayan bir sunucuda `dna.set_ssl_verification(false)` ile kapatılabilir — önerilmez; CA paketini güncellemek daha doğru çözümdür.

## Kullanım

Tüm örnekler `dna = DomainNameApi::Client.new(reseller_id, api_key)` tanımlı olduğunu varsayar. Her metot için çalıştırılabilir betikler [examples](examples) klasöründedir.

### Hesap

#### Reseller bilgileri

```ruby
dna.get_reseller_details
```

<details>
<summary>Örnek çıktı</summary>

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

#### Güncel bakiye

`get_current_balance(currency = 'USD')` — hesap `'USD'` ve `'TRY'` bakiyelerini bildirir. Diğer herhangi bir para biriminde (`'EUR'`, `'GBP'`, ...) çağrı `0.00` döndürmek yerine `'ErrorCode' => 'BALANCE'` ile başarısız olur.

```ruby
dna.get_current_balance('USD')
```

<details>
<summary>Örnek çıktı</summary>

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

### Arama ve listeler

#### Alan adı uygunluğu kontrolü

`check_availability(domains, extensions, period, command = 'create')` — sonuçtaki `DomainName`, sondaki `.tld` uzantısı olmadan alan adıdır.

```ruby
dna.check_availability(['hello', 'world123x0'], ['com', 'net'], 1, 'create')
```

<details>
<summary>Örnek çıktı</summary>

```ruby
[
  { 'TLD' => 'com', 'DomainName' => 'hello', 'Status' => 'notavailable', 'Command' => 'create',
    'Period' => 1, 'IsFee' => false, 'Price' => '10.8100', 'Currency' => 'USD', 'Reason' => 'Domain exists' },
  { 'TLD' => 'com', 'DomainName' => 'world123x0', 'Status' => 'available', 'Command' => 'create',
    'Period' => 1, 'IsFee' => false, 'Price' => '10.8100', 'Currency' => 'USD', 'Reason' => nil }
]
```

</details>

#### Alan adları listesi

`get_list(extra_parameters = {})` — `PageNumber` (0 tabanlı), `PageSize`, `OrderColumn`, `OrderDirection` ve gateway'in kendi filtreleri (örn. `DomainName`).

```ruby
dna.get_list('OrderColumn' => 'Id', 'OrderDirection' => 'ASC', 'PageNumber' => 0, 'PageSize' => 1000)
```

<details>
<summary>Örnek çıktı</summary>

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

#### TLD listesi

`get_tld_list(count = 20)`

```ruby
dna.get_tld_list(100)
```

<details>
<summary>Örnek çıktı</summary>

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

### Alan adı

#### Alan adı kaydı

`register_with_contact_info(domain, period, contacts, name_servers = [], epp_lock = true, privacy_lock = false, additional_attributes = {})`

Kişi bilgileri php-dna'nın anahtarlarını kullanır. Hem aşağıdaki düz yapı hem de `get_contacts` tarafından döndürülen iç içe yapı (`Address => { Line1, City, ... }`, `Phone => { Phone => { Number, CountryCode } }`) kabul edilir; eksik alanlar tamamlanır, isimler, telefonlar ve ülkeler normalize edilir (bkz. `validate_contact`). Nameserver verilmezse `ns1.domainnameapi.com` ve `ns2.domainnameapi.com` kullanılır.

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

`.tr` alan adları için TRABIS özniteliklerini 7. argüman olarak verin:

```ruby
# Bireysel sahip
{ 'TRABISDOMAINCATEGORY' => 1, 'TRABISCITIZIENID' => '12345678901' }
# Kurumsal sahip
{ 'TRABISDOMAINCATEGORY' => 0, 'TRABISTAXOFFICE' => 'Istanbul VD', 'TRABISTAXNUMBER' => '1234567890' }
```

Kategori `Owner`/`Corporate` olarak, `TRABISCITIZIENID` ise `TRABISCITIZENID` olarak gönderilir; eski anahtarlar (`TRABISNAMESURNAME`, `TRABISCOUNTRYID`, `TRABISCITYID`, ...) ise çıkarılır, çünkü gateway artık bu bilgileri kişi kaydından okur.

<details>
<summary>Örnek çıktı</summary>

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

#### Alan adı yenileme

```ruby
dna.renew('example.com', 1)
```

<details>
<summary>Örnek çıktı</summary>

```ruby
{ 'result' => 'OK', 'data' => { 'ExpirationDate' => '2025-03-15T10:00:00' } }
```

</details>

#### Alan adı detayları

```ruby
dna.get_details('example.com')
```

<details>
<summary>Örnek çıktı</summary>

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

#### Kayıt kuruluşundan (registry) senkronizasyon

`get_details` ile aynı çağrı ve aynı çıktı.

```ruby
dna.sync_from_registry('example.com')
```

#### Nameserver düzenlemesi

Bir liste veya bir Hash verin (Hash'in değerleri kullanılır). İsimlerin baştaki ve sondaki boşlukları temizlenir, küçük harfe çevrilir, sondaki nokta kaldırılır ve tekrar edenler ayıklanır; sonuç bu normalize edilmiş listeyi bildirir.

```ruby
dna.modify_name_server('example.com', ['ns1.example.com', 'ns2.example.com'])
```

<details>
<summary>Örnek çıktı</summary>

```ruby
{ 'result' => 'OK', 'data' => { 'NameServers' => ['ns1.example.com', 'ns2.example.com'] } }
```

</details>

#### Alan adı kilidini aktifleştirme

```ruby
dna.enable_theft_protection_lock('example.com')
```

<details>
<summary>Örnek çıktı</summary>

```ruby
{ 'result' => 'OK', 'data' => { 'LockStatus' => true } }
```

</details>

#### Alan adı kilidini kaldırma

```ruby
dna.disable_theft_protection_lock('example.com')
```

<details>
<summary>Örnek çıktı</summary>

```ruby
{ 'result' => 'OK', 'data' => { 'LockStatus' => false } }
```

</details>

#### Alan adı gizliliğini değiştirme

`modify_privacy_protection_status(domain, status, reason = 'Owner request')` — `status` değeri `true`/`false` veya panel tarzı bir değer olabilir: `1`, `'1'`, `'true'`, `'on'` ve `'yes'` gizliliği açar, diğer her değer kapatır. Sonuç, ayrıştırılmış boolean değeri bildirir. `reason` uyumluluk için kabul edilir ancak gönderilmez: gateway'de böyle bir alan yoktur.

```ruby
dna.modify_privacy_protection_status('example.com', true, 'Owner request')
```

<details>
<summary>Örnek çıktı</summary>

```ruby
{ 'data' => { 'PrivacyProtectionStatus' => true }, 'result' => 'OK' }
```

</details>

#### Alan adı kişi bilgilerini alma

Kişi türleri büyük/küçük harf duyarsız olarak eşleştirilir (`admin`/`administrative`, `tech`/`technical`, `registrant`/`owner`, `billing`); kayıt kuruluşunun (registry) döndürdüğü diğer türler dört standart türden sonra korunur.

```ruby
dna.get_contacts('example.com')
```

<details>
<summary>Örnek çıktı</summary>

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
      # kayıt kuruluşunun döndürdüğü diğer kişi türleri bu dördünün ardından gelir
    }
  },
  'result' => 'OK'
}
```

</details>

#### Alan adı kişi bilgilerini kaydetme

```ruby
dna.save_contacts('example.com', {
  'Administrative' => contact,
  'Billing'        => contact,
  'Technical'      => contact,
  'Registrant'     => contact
})
```

<details>
<summary>Örnek çıktı</summary>

```ruby
{ 'result' => 'OK', 'data' => { 'contacts' => {} } }
```

</details>

<hr style="border: 4px solid #000; border-style: dashed;">

### Child nameserver'lar

#### Child nameserver ekleme

```ruby
dna.add_child_name_server('example.com', 'ns1.example.com', '1.2.3.4')
```

<details>
<summary>Örnek çıktı</summary>

```ruby
{ 'result' => 'OK', 'data' => { 'NameServer' => 'ns1.example.com', 'IPAdresses' => ['1.2.3.4'] } }
```

</details>

#### Child nameserver silme

```ruby
dna.delete_child_name_server('example.com', 'ns1.example.com')
```

<details>
<summary>Örnek çıktı</summary>

```ruby
{ 'result' => 'OK', 'data' => { 'NameServer' => 'ns1.example.com' } }
```

</details>

#### Child nameserver güncelleme

```ruby
dna.modify_child_name_server('example.com', 'ns1.example.com', '1.2.3.5')
```

<details>
<summary>Örnek çıktı</summary>

```ruby
{ 'result' => 'OK', 'data' => { 'NameServer' => 'ns1.example.com', 'IPAdresses' => ['1.2.3.5'] } }
```

</details>

<hr style="border: 4px solid #000; border-style: dashed;">

### Transferler

#### Alan adı transferi

`transfer(domain, epp_code, period)` — transfer asla kişi bilgisi göndermez: kişi bilgilerini kayıt firması (registrar) yönetir; bu nedenle istek her zaman boş bir kişi listesi taşır ve metot kişi bilgisi argümanı almaz. Transfer tamamlandıktan sonra kişi bilgilerini `save_contacts` ile güncelleyin.

```ruby
dna.transfer('example.com', 'Xy9#mK2$', 3)
```

<details>
<summary>Örnek çıktı</summary>

```ruby
{
  'data' => { 'ID' => 0, 'Status' => 'WaitingForIncomingTransfer', 'DomainName' => 'example.com', ... },
  'result' => 'OK'
}
```

</details>

#### Transfer kontrolü

`result` değeri yalnızca kayıt kuruluşu (registry) alan adını transfer edilebilir olarak bildirdiğinde `'OK'` olur.

```ruby
dna.check_transfer('example.com', 'Xy9#mK2$')
```

<details>
<summary>Örnek çıktı</summary>

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

#### Transferi iptal etme, onaylama veya reddetme

`cancel_transfer` bekleyen bir gelen transferi iptal eder; `approve_transfer` ve `reject_transfer` ise bekleyen bir giden transfere yanıt verir.

```ruby
dna.cancel_transfer('example.com')
dna.approve_transfer('example.com')
dna.reject_transfer('example.com')
```

<details>
<summary>Örnek çıktı</summary>

```ruby
{ 'result' => 'OK', 'data' => { 'DomainName' => 'example.com', 'Status' => 'Cancelled' } } # 'Approved' / 'Rejected'
```

</details>

<hr style="border: 4px solid #000; border-style: dashed;">

### DNS zone

Desteklenen kayıt türleri: `A`, `AAAA`, `ALIAS`, `CAA`, `CNAME`, `DS`, `MX`, `NAPTR`, `PTR`, `SRV`, `TLSA`, `TXT` (diğer türler herhangi bir çağrı yapılmadan reddedilir). İsimler görelidir (`'www'`); `''` veya `'@'` zone kökünü (apex) ifade eder, `'www.example.com'` gibi tam bir isim ise kendi etiketine indirgenir. Değişiklikler hemen uygulanır; birden fazla değişikliği biriktirmek için `apply = false` verin ve ardından `apply_resource_records` metodunu bir kez çağırın. TTL 1–86400 saniye aralığındadır.

Otomatik uygulama (apply) başarısız olursa metot `OK` yerine uygulama hatasını döndürür (değişiklik canlıya alınmaz, beklemede kalır). Sonuç, gerçekte gönderilen büyük harfe çevrilmiş türü ve TTL değerini bildirir.

Gateway, bir isim + tür ikilisini tek bir **küme (set)** olarak saklar: bir kümeye yazmak kümenin tüm değerlerini değiştirir, bir değeri silmek ise kümenin tamamını siler. `*_resource_record_value` metotları okuma-birleştirme-yazma işlemini sizin yerinize yapar.

#### Kayıtları listeleme

```ruby
dna.get_resource_records('example.com')
```

<details>
<summary>Örnek çıktı</summary>

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

#### Bir kayıt kümesini değiştirme

`set_resource_record_set(domain, name, type, contents, ttl = 3600, apply = true)` — boş bir liste kümeyi kaldırır.

```ruby
dna.set_resource_record_set('example.com', 'www', 'A', ['192.0.2.10', '192.0.2.11'], 3600)
```

<details>
<summary>Örnek çıktı</summary>

```ruby
{ 'result' => 'OK', 'data' => { 'Name' => 'www', 'Type' => 'A', 'TTL' => 3600, 'Contents' => ['192.0.2.10', '192.0.2.11'] } }
```

</details>

#### Tek bir değer ekleme, değiştirme veya kaldırma

`add_resource_record_value(domain, name, type, value, ttl = nil, apply = true)`, `replace_resource_record_value(domain, name, type, old_value, new_value, ttl = nil, apply = true)`, `remove_resource_record_value(domain, name, type, value, apply = true)`. `nil` TTL, kümenin mevcut TTL değerini korur; zaten var olan bir değeri eklemek veya olmayan bir değeri kaldırmak hiçbir işlem yapmaz (`'Changed' => false`).

```ruby
dna.add_resource_record_value('example.com', '', 'MX', '10 mail.example.com.')
dna.replace_resource_record_value('example.com', '', 'MX', '10 mail.example.com.', '20 mail.example.com.')
dna.remove_resource_record_value('example.com', '', 'MX', '20 mail.example.com.')
```

<details>
<summary>Örnek çıktı</summary>

```ruby
{ 'result' => 'OK', 'data' => { 'Name' => '', 'Type' => 'MX', 'TTL' => 3600, 'Contents' => ['10 mail.example.com.'] } }
# değer zaten mevcut:
{ 'result' => 'OK', 'data' => { 'Name' => '', 'Type' => 'MX', 'Contents' => ['10 mail.example.com.'], 'Changed' => false } }
```

</details>

#### Bir kayıt kümesini silme

`delete_resource_record_set(domain, name, type, apply = true, known_value = '')` — kümenin tüm değerlerini kaldırır; kaldırılacak bir şey yoksa sonuç `'Removed' => false` ile başarılı döner.

```ruby
dna.delete_resource_record_set('example.com', 'www', 'A')
```

<details>
<summary>Örnek çıktı</summary>

```ruby
{ 'result' => 'OK', 'data' => { 'Name' => 'www.example.com.', 'Type' => 'A', 'Content' => '192.0.2.10' } }
```

</details>

#### Düşük seviyeli kayıt çağrıları

```ruby
dna.add_resource_record('example.com', 'www', 'A', '192.0.2.10', 3600, true)
dna.edit_resource_record('example.com', 'www', 'www', 'A', '192.0.2.20', 3600, true)
dna.delete_resource_record('example.com', 'www.example.com.', '192.0.2.20', 'A', true)
dna.apply_resource_records('example.com')
```

<details>
<summary>Örnek çıktı</summary>

```ruby
{ 'result' => 'OK', 'data' => { 'Name' => 'www', 'Type' => 'A', 'TTL' => 3600, 'Content' => '192.0.2.10' } }   # ekleme / düzenleme
{ 'result' => 'OK', 'data' => { 'Name' => 'www.example.com.', 'Type' => 'A', 'Content' => '192.0.2.20' } }    # silme
{ 'result' => 'OK', 'data' => { 'DomainName' => 'example.com' } }                                              # uygulama
```

</details>

<hr style="border: 4px solid #000; border-style: dashed;">

### URL yönlendirme

Yönlendirme türleri: `'Standard'` (düz yönlendirme) ve `'Frame'` (maskeli). Yapılandırılmış bir yönlendirme yoksa gateway `Redirect information not found` yanıtını verir: bu durumda `get_forwarding` `'Enabled' => false` bildirir, `delete_forwarding` ise `'Removed' => false` ile başarılı döner. Bilinmeyen bir alan adı gibi diğer tüm hatalar hata olarak döndürülür.

```ruby
dna.set_forwarding('example.com', 'https://www.example.org', 'Standard')
dna.get_forwarding('example.com')
dna.delete_forwarding('example.com')
```

<details>
<summary>Örnek çıktı</summary>

```ruby
# set_forwarding
{ 'result' => 'OK', 'data' => { 'RedirectAddress' => 'https://www.example.org', 'ForwardType' => 'Standard' } }
# get_forwarding (yapılandırılmış yönlendirme yoksa hata değil, Enabled => false döner)
{ 'result' => 'OK', 'data' => { 'Enabled' => true, 'RedirectAddress' => 'https://www.example.org', 'ForwardType' => 'Standard' } }
# delete_forwarding (hiçbir şey yapılandırılmamışsa Removed => false)
{ 'result' => 'OK', 'data' => { 'DomainName' => 'example.com', 'Removed' => true } }
```

</details>

<hr style="border: 4px solid #000; border-style: dashed;">

### Yardımcı araçlar (ağ bağlantısı gerektirmez)

#### .tr alan adı mı?

```ruby
dna.is_tr_tld('example.com.tr') # => true
dna.is_tr_tld('example.com')    # => false
```

#### Kişi bilgisini doğrulama

Bir kişi kaydını, kayıt işleminin yaptığı şekilde tamamlar ve normalize eder: isimlerden rakamlar ve noktalama işaretleri çıkarılır, eksik eyalet/il bilgisi şehir ile doldurulur, ülke adları ISO kodlarına dönüştürülür ve telefon numaraları numara ve ülke kodu olarak ayrılır. Kendi `+` veya `00` ülke koduyla yazılmış bir numara, farklı bir `PhoneCountryCode` verilmiş olsa bile kendi kodunu korur (`'+1 202 555 0100'` → `'2025550100'` / `'1'`).

```ruby
dna.validate_contact('FirstName' => 'J0hn', 'Phone' => '+90 532 374 33 88', 'Country' => 'Turkey')
```

<details>
<summary>Örnek çıktı</summary>

```ruby
{
  'FirstName' => 'Jhn', 'Phone' => '5323743388', 'Country' => 'TR', 'LastName' => 'Isimyok',
  'AddressLine1' => 'Addres yok', 'City' => 'ISTANBUL', 'State' => 'ISTANBUL', 'ZipCode' => '34000',
  'PhoneCountryCode' => '90', 'Fax' => '', 'FaxCountryCode' => ''
}
```

</details>

<hr style="border: 4px solid #000; border-style: dashed;">

### Ayarlar

| Metot | Etkisi |
|---|---|
| `set_error_reporting_enabled(false)` | Telemetriyi kapatır |
| `set_telemetry_minimal(true)` | Minimal telemetri verisini gönderir |
| `set_ssl_verification(false)` | TLS sertifika doğrulamasını atlar (önerilmez) |
| `set_service_url(url)` | Başka bir gateway URL'i kullanır |
| `set_transport(callable)` | HTTP taşıma katmanını (transport) değiştirir (aşağıya bakın) |

HTTP taşıma katmanı, `call(request)` metoduna yanıt veren herhangi bir nesnedir; burada `request`, `:method`, `:url`, `:headers`, `:body`, `:timeout`, `:connect_timeout` ve `:verify_ssl` anahtarlarını içeren bir Hash'tir ve nesne bir `DomainNameApi::Response` (veya `:status`, `:body`, `:headers` anahtarlarını içeren bir Hash) döndürür. Varsayılan taşıma katmanı `DomainNameApi::NetHttpTransport`'tur (Net::HTTP). Testler ağ bağlantısı olmadan bu şekilde çalışır:

```ruby
fake = ->(request) { DomainNameApi::Response.new(status: 200, body: '{"resellerId":"abc"}', headers: {}) }
dna = DomainNameApi::Client.new(reseller_id, api_key, false, transport: fake)
```

<hr style="border: 4px solid #000; border-style: dashed;">

## Testler

Test paketi yalnızca Minitest kullanır ve asla ağa erişmez:

```bash
bundle install
bundle exec rake test
```

`test/conformance_test.rb`, php-dna'nın 126 uyumluluk (conformance) fixture'ını (`test/fixtures/conformance/`) çalıştırır: her senaryo için gönderilen istekleri (yöntem, yol, sorgu, JSON gövdesi, kimlik doğrulama başlıkları) ve dönen değeri php-dna'nın ürettiği sonuçla karşılaştırır. Diğer testler HTTP katmanını, hata eşlemesini, telemetri maskelemesini, Net::HTTP taşıma katmanını ve yardımcı araçları kapsar.

<hr style="border: 4px solid #000; border-style: dashed;">

## Dönüş ve Hata Kodları ile Açıklamaları

| Kod   | Açıklama                                               | Detay                                                             |
|-------|--------------------------------------------------------|-------------------------------------------------------------------|
| 1000  | Command completed successfully                       | İşlem başarılı.                                                  |
| 1001  | Command completed successfully; action pending.     | İşlem başarılı. Fakat işlem şu an tamamlanmak için kuyruğa alındı. |
| 2003  | Required parameter missing                          | Parametre eksik hatası. Örneğin; Kontak bilgisinde telefon girişi yapılmaması. |
| 2105  | Object is not eligible for renewal                  | Domain durumu yenilemeye müsait değil, güncelleme işlemlerine kilitlenmiştir. Durum durumu "clientupdateprohibited" olmamalı. Diğer durum durumlarından kaynaklanabilir. |
| 2200  | Authentication error                               | Yetki hatası, güvenlik kodu hatalı veya domain başka bir kayıt firmasında bulunuyor. |
| 2302  | Object exists                                      | Domain adı veya name server bilgisi veritabanında mevcut. Kayıt edilemez. |
| 2303  | Object does not exist                              | Domain adı veya name server bilgisi veritabanında mevcut değil. Yeni kayıt oluşturulmalı. |
| 2304  | Object status prohibits operation                  | Domain durumu güncellemeye müsait değildir, güncelleme işlemlerine kilitlenmiştir. Durum durumu "clientupdateprohibited" olmamalı. Diğer durum durumlarından kaynaklanabilir. |

| KOD | DETAY                                                                                                                               |
|-----|-------------------------------------------------------------------------------------------------------------------------------------|
| 101 | Sistem Hatası Detayları ({0}) İçin!                                                                                                |
| 102 | Çoklu Hatalar Detayları ({0}) İçin!                                                                                                |
| 103 | Bilinmeyen Hatalar Detayları ({0}) İçin!                                                                                           |
| 200 | API komutu bulunamadı ({0})!                                                                                                       |
| 210 | API servisi bulunamadı ({0})!                                                                                                      |
| 211 | API servis sağlayıcısı ayarlanmamış!                                                                                               |
| 300 | Bayi bulunamadı!                                                                                                                   |
| 301 | Mevcut IP adresiniz erişim için yetkilendirilmemiş. Yetkili IP adresinden bağlandığınızdan emin olun ve tekrar deneyin            |
| 310 | TLD desteklenmiyor!                                                                                                                |
| 320 | API bulunamadı!                                                                                                                    |
| 321 | Para birimi desteklenmiyor!                                                                                                        |
| 330 | Gerekli parametre(ler) ayarlanmadı ({0}).                                                                                          |
| –   | Tüm iletişim nesnelerini tam olarak gönderdiğinizden emin olun                                                                     |
| 340 | Fiyat tanımı bulunamadı ({0}[{1}]-{2}{3}).                                                                                         |
| 350 | Yetersiz bayi bakiyesi. (Bayi Id : {0} - Mevcut Bakiye : {1} {2}).                                                                 |
| 350 | Muhasebe para birimi eşleşmiyor veya bakiye yetersiz.                                                                              |
| 360 | Alan ({0}) için geçersiz API isteği.                                                                                               |
| 360 | API kotası aşıldı!                                                                                                                 |
| 361 | Azaltma hatası!                                                                                                                    |
| 362 | Premium domain şu anda kayıt için kullanılamıyor.                                                                                  |
| 363 | Domain otomatik yenileme döneminde olduğu için işlem iptal edildi                                                                  |
| 364 | Bu domain şu anda kayıt defteri ile ilgili bir sorun nedeniyle işlem için kullanılamıyor                                          |

| KOD | DETAY                                                                                       |
|-----|---------------------------------------------------------------------------------------------|
| 400 | Geçersiz iletişim ({0}).                                                                   |
| 401 | İletişim bilgisi senkronize edilemiyor.                                                    |
| 402 | Kayıt defterinden iletişim bilgilerine erişim yok.                                         |
| 403 | SİSTEMDE EKSİK BİLGİ VAR. VARSAYILAN BİLGİLERİNİZİ GİRİN VEYA DESTEK EKIBI İLE İLETİŞİME GEÇİN. |
| 404 | DOMAIN İLETİŞİMİ GÜNCELLENEMİYOR. KAYIT DEFTERİNDEN İZİN.                                  |
| 410 | İletişim bulunamadı.                                                                       |
| 410 | İletişim bulunamadı ({0}).                                                                 |
| 420 | İletişim {0} için geçersiz Api komutu.                                                     |
| 430 | İletişim api'si bulunamadı.                                                                |
| 440 | İletişim senkronize edilmemiş.                                                             |
| 450 | Çok fazla domain iletişimi.. !                                                             |
| 451 | İletişim güncellemesi ile ilerlenemedi.                                                    |

| KOD | DETAY                                                                                                                               |
|-----|-------------------------------------------------------------------------------------------------------------------------------------|
| 500 | Geçersiz domain id.                                                                                                                 |
| 500 | Geçersiz domain id ({0}).                                                                                                           |
| 501 | Domain senkronize edilemedi({0})                                                                                                   |
| 502 | İç transfer başarısız                                                                                                              |
| 503 | Domain kaydı kullanılamıyor.                                                                                                       |
| 504 | Domain bilgisi eşleşmiyor .. Önce :{0}                                                                                             |
| 505 | IP Adresini girin.                                                                                                                 |
| 506 | Domain Transferi Başlatıldı Ancak İletişim Bilgisi Okunamadı ..                                                                    |
| 507 | Yetkilendirme hatası.                                                                                                              |
| 510 | Domain bulunamadı.                                                                                                                 |
| 511 | Süresi dolmuş domainler bulunamıyor.                                                                                               |
| 512 | Domain yenilenemez.                                                                                                                |
| 513 | Domain güncellenebilir durumda değil. Güncellenebilmesi için aktif olmalı                                                          |
| 514 | Geri Alım Süresi Bekleniyor.                                                                                                       |
| 520 | Domain "{0}" için geçersiz Api komutu.                                                                                             |
| 530 | Geçersiz domain süresi. Süre {0} ile {1} yıl arasında olmalı. İstenen süre {2} yıl.                                               |
| 540 | Domain mevcut tarihten itibaren {0} yılın ötesine uzatılamaz.                                                                      |
| 550 | Geçersiz domain adı. Domain {0} ile {1} karakter uzunluğunda olmalı. İstenen domain adı {2} karakter.                             |
| 560 | Geçersiz name server sayısı. Domain {0} ile {1} name server'a sahip olmalı. İstenen name server sayısı {2}.                       |
| 561 | Gelen istekte name server bilgisi bulunamadı                                                                                       |
| 570 | Idn tld "{0}" için desteklenmiyor.                                                                                                 |
| 571 | Süre geçersiz.                                                                                                                     |
| 572 | Komut geçersiz.                                                                                                                    |
| 573 | Domain adları bulunamadı.                                                                                                          |
| 574 | TLD adları bulunamadı.                                                                                                             |
| 575 | Domain güncellenebilir durumda değil. Name server'ların güncellenmesi için aktif olmalı                                            |
| 576 | Domain son kullanma tarihinden önceki son 1 ay içinde yenilenebilir                                                                |
| 580 | Transfer tld "{0}" için desteklenmiyor.                                                                                            |
| 581 | Alt name server bulunamadı                                                                                                         |
| 582 | Transfer başka bayi tarafından başlatıldı.                                                                                         |
| 583 | Transfer başlatılmadı. Lütfen destek ekibi ile iletişime geçin.                                                                    |
| 584 | Nesne durumu işlemi yasaklıyor                                                                                                     |
| 590 | Bu transfer için auth kodu gerekli.                                                                                                |
| 591 | Auth kodu geçerli değil.                                                                                                           |
| 592 | Domain üzerinde transfer kilidi mevcut.                                                                                            |
| 593 | Domain transfer edilemiyor, Durum Bilgisi ve Transfer Kilidi gerekli kriterlere uymalı. (Durum Bilgisi: #ok)                      |
| 594 | Domain name server adresi çözümlenemedi ({0})                                                                                      |
| 595 | İletişim bilgisi okunamıyor (whois.registrar.tld) Gizlilik koruma durumunun açık olduğundan emin olun                             |
| 596 | İletişim bilgisi doğrulanamadı                                                                                                     |
| 597 | Tld Bulunamadı                                                                                                                     |
| 598 | Bilinmeyen hata oluştu                                                                                                             |
| 599 | Domain Yönlendirmesi Bulunamadı                                                                                                    |

## Lisans

Apache License 2.0 — bkz. [LICENSE](LICENSE).
