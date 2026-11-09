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

# ruby-dna — Ruby üçün DomainNameAPI klienti

DomainNameAPI REST API vasitəsilə domenləri qeydiyyatdan keçirin, yeniləyin və transfer edin, əlaqə məlumatlarını, nameserverləri, child nameserverləri, DNS zonalarını və URL yönləndirməsini idarə edin. `ruby-dna` [php-dna](https://github.com/domainreseller/php-dna) kitabxanasının sadiq portudur: eyni metodlar, şəbəkəyə göndərilən eyni sorğular və eyni geri qaytarılan dəyərlər — hamısı php-dna-nın uyğunluq (conformance) fixture-ları ilə yoxlanılıb.

## 📦 Yükləmə — həmişə Releases istifadə edin!

⬇️ **Ən son test edilmiş versiyanı buradan əldə edin: https://github.com/domainreseller/ruby-dna/releases/latest**

> ⚠️ Yaşıl **Code → Download ZIP** düyməsindən **istifadə etməyin** — bu, xam inkişaf branch-ını yükləyir. Release paketləri versiyalanmış, test edilmiş və istehsalata hazırdır.

## Quraşdırma və İnteqrasiya Təlimatı

### Minimum Tələblər

- Ruby 2.7 və ya daha yuxarı (Təklif olunan 3.3+)
- İş vaxtı asılılıqları yoxdur: yalnız standart kitabxana (`net/http`, `json`, `openssl`).

### A) Bundler

```ruby
# Gemfile
gem 'domainnameapi', git: 'https://github.com/domainreseller/ruby-dna.git', tag: 'v1.0.0'
```

```bash
bundle install
```

### B) Release-dən gem faylı

`domainnameapi-1.0.0.gem` faylını [ən son release](https://github.com/domainreseller/ruby-dna/releases/latest) səhifəsindən endirin, sonra:

```bash
gem install ./domainnameapi-1.0.0.gem
```

### C) Manual istifadə

Release arxivini endirin, `lib` qovluğunu layihənizə kopyalayın və [examples](examples) qovluğundakı nümunələrə baxın:

```ruby
$LOAD_PATH.unshift File.expand_path('lib', __dir__)
require 'domainnameapi'
```

## 🔑 API Məlumatları — Reseller ID və API Key

Kitabxana DomainNameAPI REST API ilə əlaqə qurur və constructor-a ötürülən yalnız iki məlumat tələb edir:

| Parametr | Dəyər |
|---|---|
| Birinci | Reseller ID — `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx` kimi UUID |
| İkinci | API Key |

> 💡 **Reseller ID** və **API Key** məlumatlarınızı DomainNameAPI panelinizdə **API Parametrləri** bölməsində tapa bilərsiniz.
> ⚠️ Bunlar **API məlumatlarıdır** — panelə giriş məlumatlarınız burada **işləməyəcək**.

## Sürətli başlanğıc

```ruby
require 'domainnameapi'

reseller_id = 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx'
api_key     = 'your-api-key'

# Canlı mühit
dna = DomainNameApi::Client.new(reseller_id, api_key)

# Test (OTE) mühiti
dna = DomainNameApi::Client.new(reseller_id, api_key, true)

result = dna.get_details('example.com')
if result['result'] == 'OK'
  puts result['data']['Dates']['Expiration']
else
  puts "#{result['error']['Code']}: #{result['error']['Message']}"
end
```

Metod adları php-dna metodlarının snake_case formasıdır (`getDetails` → `get_details`, `registerWithContactInfo` → `register_with_contact_info`); parametrlərin sırası və standart dəyərləri eynidir. Nəticələr **String açarlı** adi Ruby Hash və Array-lərdir və php-dna-nın qaytardığı strukturla tam eynidir (`'LockStatus' => 'true'` kimi string bayraqlar və `'11.9900'` kimi formatlanmış qiymətlər daxil olmaqla). Giriş məlumatlarının əvvəlindəki və sonundakı boşluqlar silinir, test rejimi bayrağı isə string də qəbul edir: `"true"`, `"1"`, `"on"` və `"yes"` test rejimi deməkdir, qalan hər şey canlı mühit deməkdir.

## Xətaların idarə olunması

Metodlar API və ya şəbəkə problemlərinə görə heç vaxt istisna (exception) atmır. Uğursuz çağırış xəta zərfi qaytarır:

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

- Gateway xətaları üçün `Code` dəyəri `API_<HTTP status>` formasındadır (`API_400`, `API_401`, `API_429`, `API_500`, ...). `301`/`302` cavabı yanlış giriş məlumatları deməkdir (`Invalid API credentials`).
- Boş xəta gövdəsi `HTTP 429 - Too Many Requests` kimi oxunaqlı mesaja çevrilir.
- Sahə yoxlama xətaları `Details` içində düz mətnə çevrilir, məsələn `Admin PostalCode - 'PostalCode' is required`.
- Şəbəkə nasazlıqları xətadır, heç vaxt boş uğur deyil. Vaxt aşımı (timeout) `Could not reach the DomainNameAPI service: the connection timed out. (...)` kimi oxunur; digər transport nasazlıqları `Curl error during request: ...` kimi oxunur. Onların kodları curl nömrələrinə uyğundur (`API_28` vaxt aşımı, `API_6` DNS, `API_7` bağlantı rədd edildi, `API_35`/`API_60` TLS); `get_parsed_response_data['Code']` isə `CURL_<n>` dəyərini saxlayır.
- `get_current_balance` öz zərfini saxlayır: `ErrorCode` və `OperationMessage` ilə birlikdə `'OperationResult' => 'FAILED'`.
- `check_availability` uğur halında adi siyahı, uğursuzluq halında isə xəta zərfi qaytarır.

Yalnız proqramçı xətaları istisna atır (məsələn, `contents` siyahı olmadıqda `set_resource_record_set` `TypeError` atır).

Vaxt aşımları hər çağırış üçün 30 saniyə, qoşulma üçün isə 10 saniyədir. DNS zona endpoint-lərinə çağırışlar arasında ən azı bir saniyə fasilə saxlanılır, çünki gateway ardıcıl sıx sorğulara `HTTP 429` ilə cavab verir.

### Diaqnostika

```ruby
dna.get_request_data         # son çağırışın { 'url' => ..., 'method' => 'GET', 'payload' => {...} } məlumatı
dna.get_response_data        # son dekod edilmiş cavab gövdəsi (və ya { 'raw_response' => body })
dna.get_response_headers     # { 'url', 'http_code', 'headers', 'total_time' }
dna.get_parsed_response_data # son emal edilmiş gövdə və ya son xəta { 'Code', 'Message', 'Details' }
dna.get_last_function        # məs. 'request:GET domains/info'
dna.get_service_url          # https://api.domainresellerapi.com/api/v1
dna.set_service_url('https://ote.domainresellerapi.com/api/v1')
```

## Test rejimi

OTE test gateway-indən (`https://ote.domainresellerapi.com/api/v1`) istifadə etmək üçün constructor-un üçüncü arqumenti olaraq `true` ötürün. Canlı çağırışlar `https://api.domainresellerapi.com/api/v1` ünvanına gedir. Test rejimi ayrıca test giriş məlumatlarından istifadə edir.

## Xəta hesabatları (telemetriya)

API çağırışı uğursuz olduqda kitabxana DomainNameAPI-nin öz xəta izləmə sisteminə (Sentry) xəta hesabatı göndərə bilər. Uğurlu çağırışların təsadüfi seçilmiş kiçik bir hissəsi (4%, üstəlik 1 saniyədən uzun çəkən hər çağırış) performans qeydi kimi göndərilə bilər. Bu, DomainNameAPI-yə problemləri tapıb düzəltməyə kömək edir. Xəta hesabatları **standart olaraq aktivdir**.

> ℹ️ 1.0.0 versiyasında ruby-dna üçün Sentry layihəsi hələ mövcud deyil, buna görə daxili DSN boşdur və **heç nə göndərilmir**. Hesabatlar DSN-i daxil edən release çıxdıqdan sonra başlayır. `DomainNameApi::Client.new(id, key, false, sentry_dsn: '...')` DSN-i açıq şəkildə təyin edir.

**Göndərilənlər:**

- xəta kodu və mesajı
- çağırılan endpoint yolu və HTTP metodu
- çağırışın müddəti
- kitabxananın adı (`DomainNameAPI-Ruby`), kitabxananın versiyası və Ruby versiyası
- reseller ID və domen adı
- serverin ictimai (public) IP ünvanı (`api.ipify.org` vasitəsilə, arxa planda müəyyən edilir)
- prosesin işlədiyi əməliyyat sistemi istifadəçisinin adı
- API sorğusu və cavabı, domenin əlaqə məlumatları daxil olmaqla; yalnız giriş məlumatları maskalanır — EPP/auth kodları, API açarları, parollar və tokenlər `***` ilə əvəz olunur

**Heç vaxt göndərilməyənlər:** oxunaqlı formada EPP/auth kodları, API açarları, parollar və ya tokenlər; stack trace-lərdəki metod arqumentləri.

Gözlənilən, yüksək həcmli xətalar (domen tapılmadı, balans kifayət deyil, yanlış giriş məlumatları, ...) hesabat kimi göndərilmir. Hesabatlar qısa vaxt aşımları ilə arxa plan thread-indən göndərilir: onlar heç vaxt çağırışınızı yavaşlatmır və ya pozmur.

**Niyə və nə qədər müddətə:** məlumatlar yalnız istifadənin ölçülməsi və problemlərin erkən diaqnostikası üçün istifadə olunur, DomainNameAPI-nin öz Sentry serverində 30 gün saxlanılır, sonra avtomatik olaraq silinir.

**Necə söndürmək olar:**

```ruby
dna = DomainNameApi::Client.new(reseller_id, api_key)
dna.set_error_reporting_enabled(false)
```

**Minimal rejim** yalnız xəta kodu və mesajını, endpoint-i, müddəti, versiyaları və reseller ID-ni göndərir — sorğu/cavab məlumatları, domen, server IP-si və ya istifadəçi adı göndərilmir:

```ruby
dna.set_telemetry_minimal(true)
```

> 🔒 **Təhlükəsizlik:** TLS sertifikat yoxlaması aktivdir. CA paketi köhnə olan serverdə `dna.set_ssl_verification(false)` ilə söndürülə bilər — tövsiyə edilmir; CA paketini yeniləmək daha düzgün həlldir.

## İstifadə

Bütün nümunələr `dna = DomainNameApi::Client.new(reseller_id, api_key)` olduğunu fərz edir. Hər metod üçün işlək skriptlər [examples](examples) qovluğundadır.

### Hesab

#### Satıcı təfərrüatları

```ruby
dna.get_reseller_details
```

<details>
<summary>Nümunə çıxış</summary>

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

#### Cari balans

`get_current_balance(currency = 'USD')` — `'USD'`, `'TRY'`, `'EUR'` və ya `'GBP'`.

```ruby
dna.get_current_balance('USD')
```

<details>
<summary>Nümunə çıxış</summary>

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

### Axtarış və siyahılar

#### Domen mövcudluğunun yoxlanılması

`check_availability(domains, extensions, period, command = 'create')`

```ruby
dna.check_availability(['hello', 'world123x0'], ['com', 'net'], 1, 'create')
```

<details>
<summary>Nümunə çıxış</summary>

```ruby
[
  { 'TLD' => 'com', 'DomainName' => 'hello', 'Status' => 'notavailable', 'Command' => 'create',
    'Period' => 1, 'IsFee' => false, 'Price' => '10.8100', 'Currency' => 'USD', 'Reason' => 'Domain exists' },
  { 'TLD' => 'com', 'DomainName' => 'world123x0', 'Status' => 'available', 'Command' => 'create',
    'Period' => 1, 'IsFee' => false, 'Price' => '10.8100', 'Currency' => 'USD', 'Reason' => nil }
]
```

</details>

#### Domen siyahısı

`get_list(extra_parameters = {})` — `PageNumber` (0-dan başlayır), `PageSize`, `OrderColumn`, `OrderDirection` və gateway-in öz filtrləri (məs. `DomainName`).

```ruby
dna.get_list('OrderColumn' => 'Id', 'OrderDirection' => 'ASC', 'PageNumber' => 0, 'PageSize' => 1000)
```

<details>
<summary>Nümunə çıxış</summary>

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

#### TLD siyahısı

`get_tld_list(count = 20)`

```ruby
dna.get_tld_list(100)
```

<details>
<summary>Nümunə çıxış</summary>

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

### Domen

#### Domen qeydiyyatı

`register_with_contact_info(domain, period, contacts, name_servers = [], epp_lock = true, privacy_lock = false, additional_attributes = {})`

Əlaqə məlumatları php-dna-nın açarlarından istifadə edir. Həm aşağıdakı düz forma, həm də `get_contacts` tərəfindən qaytarılan iç-içə forma (`Address => { Line1, City, ... }`, `Phone => { Phone => { Number, CountryCode } }`) qəbul edilir; çatışmayan sahələr tamamlanır, adlar, telefonlar və ölkələr normallaşdırılır (bax: `validate_contact`). Nameserver verilmədikdə `ns1.domainnameapi.com` və `ns2.domainnameapi.com` istifadə olunur.

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

`.tr` domenləri üçün TRABIS atributlarını 7-ci arqument kimi ötürün:

```ruby
# Fərdi sahib
{ 'TRABISDOMAINCATEGORY' => 1, 'TRABISCITIZIENID' => '12345678901' }
# Şirkət sahibi
{ 'TRABISDOMAINCATEGORY' => 0, 'TRABISTAXOFFICE' => 'Istanbul VD', 'TRABISTAXNUMBER' => '1234567890' }
```

Kateqoriya `Owner`/`Corporate` kimi, `TRABISCITIZIENID` isə `TRABISCITIZENID` kimi göndərilir; köhnə açarlar (`TRABISNAMESURNAME`, `TRABISCOUNTRYID`, `TRABISCITYID`, ...) isə atılır, çünki gateway artıq bu məlumatları əlaqə məlumatlarından oxuyur.

<details>
<summary>Nümunə çıxış</summary>

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

#### Domen yenilənməsi

```ruby
dna.renew('example.com', 1)
```

<details>
<summary>Nümunə çıxış</summary>

```ruby
{ 'result' => 'OK', 'data' => { 'ExpirationDate' => '2025-03-15T10:00:00' } }
```

</details>

#### Domen məlumatları

```ruby
dna.get_details('example.com')
```

<details>
<summary>Nümunə çıxış</summary>

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

#### Registry ilə sinxronlaşdırma

Çağırış və çıxış `get_details` ilə eynidir.

```ruby
dna.sync_from_registry('example.com')
```

#### Nameserver dəyişdirmə

Siyahı və ya Hash ötürün (Hash-in dəyərləri istifadə olunur).

```ruby
dna.modify_name_server('example.com', ['ns1.example.com', 'ns2.example.com'])
```

<details>
<summary>Nümunə çıxış</summary>

```ruby
{ 'result' => 'OK', 'data' => { 'NameServers' => ['ns1.example.com', 'ns2.example.com'] } }
```

</details>

#### Domen kilidini aktivləşdirmək

```ruby
dna.enable_theft_protection_lock('example.com')
```

<details>
<summary>Nümunə çıxış</summary>

```ruby
{ 'result' => 'OK', 'data' => { 'LockStatus' => true } }
```

</details>

#### Domen kilidini açmaq

```ruby
dna.disable_theft_protection_lock('example.com')
```

<details>
<summary>Nümunə çıxış</summary>

```ruby
{ 'result' => 'OK', 'data' => { 'LockStatus' => false } }
```

</details>

#### Domen məxfiliyini dəyişdirmə

`modify_privacy_protection_status(domain, status, reason = 'Owner request')` — məxfilik yalnız `status` dəqiq `true` olduqda aktivləşdirilir.

```ruby
dna.modify_privacy_protection_status('example.com', true, 'Owner request')
```

<details>
<summary>Nümunə çıxış</summary>

```ruby
{ 'data' => { 'PrivacyProtectionStatus' => true }, 'result' => 'OK' }
```

</details>

#### Domen əlaqə məlumatlarını əldə etmək

```ruby
dna.get_contacts('example.com')
```

<details>
<summary>Nümunə çıxış</summary>

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

#### Domen əlaqə məlumatlarını saxlamaq

```ruby
dna.save_contacts('example.com', {
  'Administrative' => contact,
  'Billing'        => contact,
  'Technical'      => contact,
  'Registrant'     => contact
})
```

<details>
<summary>Nümunə çıxış</summary>

```ruby
{ 'result' => 'OK', 'data' => { 'contacts' => {} } }
```

</details>

<hr style="border: 4px solid #000; border-style: dashed;">

### Child nameserverlər

#### Child nameserver əlavə etmək

```ruby
dna.add_child_name_server('example.com', 'ns1.example.com', '1.2.3.4')
```

<details>
<summary>Nümunə çıxış</summary>

```ruby
{ 'result' => 'OK', 'data' => { 'NameServer' => 'ns1.example.com', 'IPAdresses' => ['1.2.3.4'] } }
```

</details>

#### Child nameserver silmə

```ruby
dna.delete_child_name_server('example.com', 'ns1.example.com')
```

<details>
<summary>Nümunə çıxış</summary>

```ruby
{ 'result' => 'OK', 'data' => { 'NameServer' => 'ns1.example.com' } }
```

</details>

#### Child nameserver yeniləmə

```ruby
dna.modify_child_name_server('example.com', 'ns1.example.com', '1.2.3.5')
```

<details>
<summary>Nümunə çıxış</summary>

```ruby
{ 'result' => 'OK', 'data' => { 'NameServer' => 'ns1.example.com', 'IPAdresses' => ['1.2.3.5'] } }
```

</details>

<hr style="border: 4px solid #000; border-style: dashed;">

### Transferlər

#### Domen transferi

`transfer(domain, epp_code, period, contacts = {})` — php-dna-nın fasadında olduğu kimi, transfer əlaqə məlumatları olmadan göndərilir (gateway mövcud əlaqə məlumatlarını saxlayır).

```ruby
dna.transfer('example.com', 'Xy9#mK2$', 3)
```

<details>
<summary>Nümunə çıxış</summary>

```ruby
{
  'data' => { 'ID' => 0, 'Status' => 'WaitingForIncomingTransfer', 'DomainName' => 'example.com', ... },
  'result' => 'OK'
}
```

</details>

#### Transferin yoxlanılması

`result` yalnız registry domeni transfer edilə bilən kimi bildirdikdə `'OK'` olur.

```ruby
dna.check_transfer('example.com', 'Xy9#mK2$')
```

<details>
<summary>Nümunə çıxış</summary>

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

#### Transferi ləğv etmək, təsdiqləmək və ya rədd etmək

`cancel_transfer` gözləmədə olan daxil olan transferi ləğv edir; `approve_transfer` və `reject_transfer` isə gözləmədə olan çıxan transferə cavab verir.

```ruby
dna.cancel_transfer('example.com')
dna.approve_transfer('example.com')
dna.reject_transfer('example.com')
```

<details>
<summary>Nümunə çıxış</summary>

```ruby
{ 'result' => 'OK', 'data' => { 'DomainName' => 'example.com', 'Status' => 'Cancelled' } } # 'Approved' / 'Rejected'
```

</details>

<hr style="border: 4px solid #000; border-style: dashed;">

### DNS zonası

Dəstəklənən qeyd tipləri: `A`, `AAAA`, `ALIAS`, `CAA`, `CNAME`, `DS`, `MX`, `NAPTR`, `PTR`, `SRV`, `TLSA`, `TXT` (digər tiplər heç bir çağırış edilmədən rədd olunur). Adlar nisbidir (`'www'`); `''` və ya `'@'` zonanın kökü (apex) deməkdir, `'www.example.com'` kimi tam ad isə öz label-inə qədər qısaldılır. Dəyişikliklər dərhal tətbiq olunur; bir neçə dəyişikliyi toplamaq üçün `apply = false` ötürün və sonda bir dəfə `apply_resource_records` çağırın. TTL 1–86400 saniyədir.

Gateway ad + tip cütünü bir **set** kimi saxlayır: set-in yazılması onun bütün dəyərlərini əvəz edir, bir dəyərin silinməsi isə bütün set-i silir. `*_resource_record_value` metodları oxu-birləşdir-yaz əməliyyatını sizin əvəzinizə edir.

#### Qeydlərin siyahısı

```ruby
dna.get_resource_records('example.com')
```

<details>
<summary>Nümunə çıxış</summary>

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

#### Qeyd set-ini əvəz etmək

`set_resource_record_set(domain, name, type, contents, ttl = 3600, apply = true)` — boş siyahı set-i silir.

```ruby
dna.set_resource_record_set('example.com', 'www', 'A', ['192.0.2.10', '192.0.2.11'], 3600)
```

<details>
<summary>Nümunə çıxış</summary>

```ruby
{ 'result' => 'OK', 'data' => { 'Name' => 'www', 'Type' => 'A', 'TTL' => 3600, 'Contents' => ['192.0.2.10', '192.0.2.11'] } }
```

</details>

#### Bir dəyəri əlavə etmək, əvəz etmək və ya silmək

`add_resource_record_value(domain, name, type, value, ttl = nil, apply = true)`, `replace_resource_record_value(domain, name, type, old_value, new_value, ttl = nil, apply = true)`, `remove_resource_record_value(domain, name, type, value, apply = true)`. `nil` TTL set-in cari TTL-ini saxlayır; artıq mövcud olan dəyəri əlavə etmək və ya mövcud olmayan dəyəri silmək heç nə etmir (`'Changed' => false`).

```ruby
dna.add_resource_record_value('example.com', '', 'MX', '10 mail.example.com.')
dna.replace_resource_record_value('example.com', '', 'MX', '10 mail.example.com.', '20 mail.example.com.')
dna.remove_resource_record_value('example.com', '', 'MX', '20 mail.example.com.')
```

<details>
<summary>Nümunə çıxış</summary>

```ruby
{ 'result' => 'OK', 'data' => { 'Name' => '', 'Type' => 'MX', 'TTL' => 3600, 'Contents' => ['10 mail.example.com.'] } }
# dəyər artıq mövcuddur:
{ 'result' => 'OK', 'data' => { 'Name' => '', 'Type' => 'MX', 'Contents' => ['10 mail.example.com.'], 'Changed' => false } }
```

</details>

#### Qeyd set-ini silmək

`delete_resource_record_set(domain, name, type, apply = true, known_value = '')` — set-in bütün dəyərlərini silir; silinəcək heç nə yoxdursa, nəticə `'Removed' => false` ilə uğurlu olur.

```ruby
dna.delete_resource_record_set('example.com', 'www', 'A')
```

<details>
<summary>Nümunə çıxış</summary>

```ruby
{ 'result' => 'OK', 'data' => { 'Name' => 'www.example.com.', 'Type' => 'A', 'Content' => '192.0.2.10' } }
```

</details>

#### Aşağı səviyyəli qeyd çağırışları

```ruby
dna.add_resource_record('example.com', 'www', 'A', '192.0.2.10', 3600, true)
dna.edit_resource_record('example.com', 'www', 'www', 'A', '192.0.2.20', 3600, true)
dna.delete_resource_record('example.com', 'www.example.com.', '192.0.2.20', 'A', true)
dna.apply_resource_records('example.com')
```

<details>
<summary>Nümunə çıxış</summary>

```ruby
{ 'result' => 'OK', 'data' => { 'Name' => 'www', 'Type' => 'A', 'TTL' => 3600, 'Content' => '192.0.2.10' } }   # əlavə / redaktə
{ 'result' => 'OK', 'data' => { 'Name' => 'www.example.com.', 'Type' => 'A', 'Content' => '192.0.2.20' } }    # silmə
{ 'result' => 'OK', 'data' => { 'DomainName' => 'example.com' } }                                              # tətbiq
```

</details>

<hr style="border: 4px solid #000; border-style: dashed;">

### URL yönləndirməsi

Yönləndirmə tipləri: `'Standard'` (adi yönləndirmə) və `'Frame'` (maskalanmış).

```ruby
dna.set_forwarding('example.com', 'https://www.example.org', 'Standard')
dna.get_forwarding('example.com')
dna.delete_forwarding('example.com')
```

<details>
<summary>Nümunə çıxış</summary>

```ruby
# set_forwarding
{ 'result' => 'OK', 'data' => { 'RedirectAddress' => 'https://www.example.org', 'ForwardType' => 'Standard' } }
# get_forwarding (heç nə qurulmayıbsa, xəta deyil, Enabled => false qaytarılır)
{ 'result' => 'OK', 'data' => { 'Enabled' => true, 'RedirectAddress' => 'https://www.example.org', 'ForwardType' => 'Standard' } }
# delete_forwarding
{ 'result' => 'OK', 'data' => { 'DomainName' => 'example.com' } }
```

</details>

<hr style="border: 4px solid #000; border-style: dashed;">

### Köməkçi metodlar (şəbəkəsiz)

#### Bu .tr domenidir?

```ruby
dna.is_tr_tld('example.com.tr') # => true
dna.is_tr_tld('example.com')    # => false
```

#### Əlaqə məlumatının yoxlanılması

Əlaqə məlumatını qeydiyyat zamanı olduğu kimi tamamlayır və normallaşdırır: adlardan rəqəmlər və durğu işarələri silinir, çatışmayan ştat (state) şəhərlə əvəz olunur, ölkə adları ISO kodlarına çevrilir, telefon nömrələri isə nömrə və ölkə koduna ayrılır.

```ruby
dna.validate_contact('FirstName' => 'J0hn', 'Phone' => '+90 532 374 33 88', 'Country' => 'Turkey')
```

<details>
<summary>Nümunə çıxış</summary>

```ruby
{
  'FirstName' => 'Jhn', 'Phone' => '5323743388', 'Country' => 'TR', 'LastName' => 'Isimyok',
  'AddressLine1' => 'Addres yok', 'City' => 'ISTANBUL', 'State' => 'ISTANBUL', 'ZipCode' => '34000',
  'PhoneCountryCode' => '90', 'Fax' => '', 'FaxCountryCode' => ''
}
```

</details>

<hr style="border: 4px solid #000; border-style: dashed;">

### Parametrlər

| Metod | Təsiri |
|---|---|
| `set_error_reporting_enabled(false)` | Telemetriyanı söndürür |
| `set_telemetry_minimal(true)` | Minimal telemetriya məlumatını göndərir |
| `set_ssl_verification(false)` | TLS sertifikat yoxlamasını ötürür (tövsiyə edilmir) |
| `set_service_url(url)` | Başqa gateway URL-indən istifadə edir |
| `set_transport(callable)` | HTTP transportu əvəz edir (aşağıya baxın) |

HTTP transport `call(request)` metoduna cavab verən istənilən obyektdir; burada `request` `:method`, `:url`, `:headers`, `:body`, `:timeout`, `:connect_timeout` və `:verify_ssl` açarlarına malik Hash-dir, obyekt isə `DomainNameApi::Response` (və ya `:status`, `:body`, `:headers` açarlı Hash) qaytarır. Standart transport `DomainNameApi::NetHttpTransport`-dur (Net::HTTP). Testlər şəbəkəsiz məhz belə işləyir:

```ruby
fake = ->(request) { DomainNameApi::Response.new(status: 200, body: '{"resellerId":"abc"}', headers: {}) }
dna = DomainNameApi::Client.new(reseller_id, api_key, false, transport: fake)
```

<hr style="border: 4px solid #000; border-style: dashed;">

## Testlər

Test dəsti yalnız Minitest-dən istifadə edir və heç vaxt şəbəkəyə müraciət etmir:

```bash
bundle install
bundle exec rake test
```

`test/conformance_test.rb` php-dna-nın 126 uyğunluq (conformance) fixture-unu (`test/fixtures/conformance/`) işə salır: hər ssenari üçün göndərilən sorğuları (metod, yol, query, JSON gövdəsi, auth başlıqları) və qaytarılan dəyəri php-dna-nın istehsal etdiyi nəticə ilə müqayisə edir. Digər testlər HTTP qatını, xətaların uyğunlaşdırılmasını, telemetriya maskalanmasını, Net::HTTP transportunu və köməkçi metodları əhatə edir.

<hr style="border: 4px solid #000; border-style: dashed;">

## Geri Dönüş və Xəta Kodları ilə Açıqlamaları

| Kod | Açıqlama | Təfərrüat |
|-----|----------|-----------|
| 1000 | Əmr uğurla tamamlandı | Əməliyyat uğurlu. |
| 1001 | Əmr uğurla tamamlandı; hərəkət gözləmədə | Əməliyyat uğurlu. Bununla belə, əməliyyat hazırda tamamlanması üçün növbəyə alınıb. |
| 2003 | Tələb olunan parametr çatışmır | Parametr çatışmır xətası. Məsələn: əlaqə məlumatlarında telefon girişi yox. |
| 2105 | Obyekt yenilənmə üçün uyğun deyil | Domen statusu yenilənmə üçün uyğun deyil, yeniləmə əməliyyatları üçün kilidlənib. Status "clientupdateprohibited" olmamalıdır. Digər status şərtlərindən qaynaqlanana bilər. |
| 2200 | Kimlik doğrulama xətası | İcazə xətası, təhlükəsizlik kodu səhvdir və ya domen başqa qeydiyyat şirkətində mövcuddur. |
| 2302 | Obyekt mövcuddur | Domen adı və ya nameserver məlumatları verilənlər bazasında mövcuddur. Qeydiyyat edilə bilməz. |
| 2303 | Obyekt mövcud deyil | Domen adı və ya nameserver məlumatları verilənlər bazasında mövcud deyil. Yeni qeydiyyat tələb olunur. |
| 2304 | Obyekt statusu əməliyyatı qadağan edir | Domen statusu yeniləmələr üçün uyğun deyil, yeniləmə əməliyyatları üçün kilidlənib. Status "clientupdateprohibited" olmamalıdır. Digər status şərtlərindən qaynaqlanana bilər. |

| KOD | TƏFƏRRÜAT |
|-----|-----------|
| 101 | Sistem Xətası Təfərrüatlı ({0}) Üçün! |
| 102 | Çoxlu Xətalar Təfərrüatlı ({0}) Üçün! |
| 103 | Naməlum Xətalar Təfərrüatlı ({0}) Üçün! |
| 200 | API əmri tapılmadı ({0})! |
| 210 | API xidməti tapılmadı ({0})! |
| 211 | API xidmət provayderi təyin edilməyib! |
| 300 | Satıcı tapılmadı! |
| 301 | Hazırkı IP ünvanınız girişə icazəli deyil. İcazəli IP ünvanından qoşulduğunuzdan əmin olun və yenidən cəhd edin |
| 310 | TLD dəstəklənmir! |
| 320 | API tapılmadı! |
| 321 | Valyuta dəstəklənmir! |
| 330 | Tələb olunan parametr(lər) təyin edilməyib ({0}). |
| – | Bütün əlaqə obyektlərini tam göndərdiyinizə əmin olun |
| 340 | Qiymət tərifə tapılmadı ({0}[{1}]-{2}{3}). |
| 350 | Kifayət qədər satıcı balansı yoxdur. (Satıcı Id : {0} - Hazırkı Balans : {1} {2}). |
| 350 | Mühasibat valyutası uyğunlaşmır və ya balans kifayət deyil. |
| 360 | Sahə ({0}) üçün etibarsız API sorğusu. |
| 360 | API kvotası aşılıb! |
| 361 | Throttled xətası! |
| 362 | Premium domen hazırda qeydiyyat üçün əlçatan deyil. |
| 363 | Domen avtomatik yenilənmə dövründə olduğu üçün əməliyyat ləğv edildi |
| 364 | Bu domen hazırda qeydiyyat ilə bağlı problem səbəbindən əməliyyat üçün əlçatan deyil |

| KOD | TƏFƏRRÜAT |
|-----|-----------|
| 400 | Etibarsız əlaqə ({0}). |
| 401 | Əlaqə məlumatı sinxronlaşdırıla bilmir. |
| 402 | Qeydiyyat dəftərindən əlaqə məlumatlarına giriş yoxdur. |
| 403 | SİSTEMDƏ ÇATIŞMAYAN MƏLUMAT VAR. STANDART MƏLUMATLARINIZI DAXİL EDİN VƏ YA DƏSTƏK KOMANDASI İLƏ ƏLAQƏ SAXLAYIN. |
| 404 | DOMEN ƏLAQƏSI YENİLƏNƏ BİLMİR. QEYDİYYAT DƏFTƏRİNDƏN İCAZƏ. |
| 410 | Əlaqə tapılmadı. |
| 410 | Əlaqə tapılmadı ({0}). |
| 420 | Əlaqə {0} üçün etibarsız Api əmri. |
| 430 | Əlaqə api-si tapılmadı. |
| 440 | Əlaqə sinxronlaşdırılmayıb. |
| 450 | Çox çoxlu domen əlaqələri.. ! |
| 451 | Əlaqə yeniləməsi ilə davam edilə bilmədi. |

| KOD | TƏFƏRRÜAT |
|-----|-----------|
| 500 | Etibarsız domen id. |
| 500 | Etibarsız domen id ({0}). |
| 501 | Domen sinxronlaşdırıla bilmədi({0}) |
| 502 | Daxili transfer uğursuz oldu |
| 503 | Domen qeydiyyatı əlçatan deyil. |
| 504 | Domen məlumatları uyğunlaşmır .. Əvvəl :{0} |
| 505 | IP Ünvanını daxil edin. |
| 506 | Domen Transferi Başladıldı Lakin Əlaqə Məlumatı Oxuna Bilmədi .. |
| 507 | İcazə xətası. |
| 510 | Domen tapılmadı. |
| 511 | Vaxtı keçmiş domenlər tapıla bilmir. |
| 512 | Domen yenilənə bilmir. |
| 513 | Domen yenilənə bilən statusda deyil. Yenilənə bilməsi üçün aktiv olmalıdır |
| 514 | Bərpa Dövrü Gözlənilir. |
| 520 | Domen "{0}" üçün etibarsız Api əmri. |
| 530 | Etibarsız domen müddəti. Müddət {0} ilə {1} il arasında olmalıdır. Tələb olunan müddət {2} ildir. |
| 540 | Domen hazırkı tarixdən {0} ildən artıq uzadıla bilməz. |
| 550 | Etibarsız domen adı. Domen {0} ilə {1} simvol uzunluğunda olmalıdır. Tələb olunan domen adı {2} simvoldur. |
| 560 | Etibarsız nameserver sayı. Domen {0} ilə {1} nameserverə sahib olmalıdır. Tələb olunan nameserver sayı {2}. |
| 561 | Daxil olan sorğuda nameserver məlumatı tapılmadı |
| 570 | Idn tld "{0}" üçün dəstəklənmir. |
| 571 | Müddət etibarsızdır. |
| 572 | Əmr etibarsızdır. |
| 573 | Domen adları tapılmadı. |
| 574 | TLD adları tapılmadı. |
| 575 | Domen yenilənə bilən statusda deyil. Nameserverlər yenilənə bilməsi üçün aktiv olmalıdır |
| 576 | Domen son istifadə tarixindən əvvəlki son 1 ay ərzində yenilənə bilər |
| 580 | Transfer tld "{0}" üçün dəstəklənmir. |
| 581 | Uşaq nameserveri tapılmadı |
| 582 | Transfer başqa satıcı tərəfindən başladıldı. |
| 583 | Transfer başladılmadı. Dəstək komandası ilə əlaqə saxlayın. |
| 584 | Obyekt statusu əməliyyatı qadağan edir |
| 590 | Bu transfer üçün auth kodu tələb olunur. |
| 591 | Auth kodu etibarsızdır. |
| 592 | Domen üzərində transfer kilidi mövcuddur. |
| 593 | Domen transfer edilə bilməz, Status Məlumatı və Transfer Kilidi tələb olunan kriterlərə uyğun gəlməlidir. (Status Məlumatı: #ok) |
| 594 | Domen nameserver ünvanı həll edilə bilmədi ({0}) |
| 595 | Əlaqə məlumatı oxuna bilmir (whois.registrar.tld) Məxfilik qoruma statusunun açıq olduğundan əmin olun |
| 596 | Əlaqə məlumatı təsdiqlənə bilmədi |
| 597 | Tld Tapılmadı |
| 598 | Naməlum xəta baş verdi |
| 599 | Domen Yönləndirməsi Tapılmadı |

## Lisenziya

Apache License 2.0 — bax: [LICENSE](LICENSE).
