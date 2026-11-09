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

# ruby-dna — عميل DomainNameAPI للغة Ruby

سجّل النطاقات وجدّدها وانقلها، وأدِر جهات الاتصال وخوادم الأسماء وخوادم الأسماء الفرعية ومناطق DNS وإعادة توجيه URL عبر DomainNameAPI REST API. تُعد `ruby-dna` نقلًا أمينًا لمكتبة [php-dna](https://github.com/domainreseller/php-dna): الدوال نفسها، والطلبات نفسها على مستوى الشبكة، وقيم الإرجاع نفسها، وقد جرى التحقق من ذلك باستخدام بيانات المطابقة (conformance fixtures) الخاصة بـ php-dna.

## 📦 التنزيل — استخدم دائمًا صفحة الإصدارات (Releases)!

⬇️ **احصل على أحدث نسخة مختبَرة من هنا: https://github.com/domainreseller/ruby-dna/releases/latest**

> ⚠️ **لا** تستخدم الزر الأخضر **Code → Download ZIP** — فهو ينزّل فرع التطوير الخام. حزم الإصدارات مرقّمة الإصدار ومختبَرة وجاهزة لبيئة الإنتاج.

## دليل التثبيت والتكامل

### الحد الأدنى من المتطلبات

- Ruby 2.7 أو أعلى (يوصى بـ 3.3 فما فوق)
- لا توجد اعتماديات وقت التشغيل: المكتبة القياسية فقط (`net/http` و `json` و `openssl`).

### أ) Bundler

```ruby
# Gemfile
gem 'domainnameapi', git: 'https://github.com/domainreseller/ruby-dna.git', tag: 'v1.0.0'
```

```bash
bundle install
```

### ب) ملف gem من الإصدار

نزّل الملف `domainnameapi-1.0.0.gem` من [أحدث إصدار](https://github.com/domainreseller/ruby-dna/releases/latest)، ثم:

```bash
gem install ./domainnameapi-1.0.0.gem
```

### ج) الاستخدام اليدوي

نزّل أرشيف الإصدار، وانسخ مجلد `lib` إلى مشروعك، وراجع الأمثلة في مجلد [examples](examples):

```ruby
$LOAD_PATH.unshift File.expand_path('lib', __dir__)
require 'domainnameapi'
```

## 🔑 بيانات اعتماد API — Reseller ID و API Key

تتواصل المكتبة مع DomainNameAPI REST API وتحتاج فقط إلى بيانات اعتماد اثنتين تُمرَّران إلى الدالة الإنشائية (constructor):

| المُعامِل | القيمة |
|---|---|
| الأول | Reseller ID — بصيغة UUID مثل `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx` |
| الثاني | API Key |

> 💡 ستجد **Reseller ID** و **API Key** في لوحة DomainNameAPI الخاصة بك ضمن **إعدادات API**.
> ⚠️ هذه **بيانات اعتماد API** — بيانات تسجيل الدخول إلى اللوحة **لن تعمل** هنا.

## البدء السريع

```ruby
require 'domainnameapi'

reseller_id = 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx'
api_key     = 'your-api-key'

# البيئة الحية
dna = DomainNameApi::Client.new(reseller_id, api_key)

# بيئة الاختبار (OTE)
dna = DomainNameApi::Client.new(reseller_id, api_key, true)

result = dna.get_details('example.com')
if result['result'] == 'OK'
  puts result['data']['Dates']['Expiration']
else
  puts "#{result['error']['Code']}: #{result['error']['Message']}"
end
```

أسماء الدوال هي صيغة snake_case لأسماء دوال php-dna ‏(`getDetails` → `get_details`، و `registerWithContactInfo` → `register_with_contact_info`)، مع ترتيب المعاملات نفسه والقيم الافتراضية نفسها. النتائج عبارة عن Hashes و Arrays عادية في Ruby ذات **مفاتيح نصية (String keys)**، وهي بالبنية نفسها تمامًا التي تُرجعها php-dna (بما في ذلك الأعلام النصية مثل `'LockStatus' => 'true'` والأسعار المنسّقة مثل `'11.9900'`). تُزال المسافات الزائدة من بيانات الاعتماد، كما يقبل علم وضع الاختبار قيمًا نصية أيضًا: `"true"` و `"1"` و `"on"` و `"yes"` تعني وضع الاختبار، وأي قيمة أخرى تعني البيئة الحية.

## معالجة الأخطاء

لا تُطلق الدوال استثناءات أبدًا بسبب مشكلات API أو الشبكة. يُرجع الاستدعاء الفاشل غلاف خطأ (error envelope):

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

- تكون قيمة `Code` بالصيغة `API_<HTTP status>` لأخطاء البوابة (`API_400` و `API_401` و `API_429` و `API_500` و...). تعني الاستجابة `301`/`302` أن بيانات الاعتماد خاطئة (`Invalid API credentials`).
- عندما ترسل البوابة رمز خطأ خاصًا بها، يحمله الغلاف أيضًا في الحقل `GatewayCode` (على سبيل المثال `'GatewayCode' => 'Dna.DomainService:Domain:10007'`)، بحيث يمكنك التمييز بين خطأ `API_404` وآخر.
- يتحول جسم الخطأ الفارغ إلى رسالة مقروءة مثل `HTTP 429 - Too Many Requests`. لا يُستخدم جسم الاستجابة الخام كرسالة أبدًا عندما تكون رسالة البوابة نصًا عامًا نمطيًا؛ بل يُستخدم بدلًا منه نص ثابت يذكر رمز البوابة.
- تُدمج أخطاء التحقق من الحقول في `Details`، على سبيل المثال `Admin PostalCode - 'PostalCode' is required`.
- إخفاقات الشبكة أخطاء، ولا تكون أبدًا نجاحًا فارغًا. تكون رسالة انتهاء المهلة `Could not reach the DomainNameAPI service: the connection timed out. (...)`؛ أما إخفاقات النقل الأخرى فتكون رسالتها `Curl error during request: ...`. تكون رموزها بالصيغة `CURL_<n>` مع أرقام curl ‏(`CURL_28` لانتهاء المهلة، و `CURL_6` لـ DNS، و `CURL_7` لرفض الاتصال، و `CURL_35`/`CURL_60` لـ TLS، و `CURL_56` لإعادة تعيين الاتصال)؛ أما الصيغة `API_<n>` فمحجوزة لحالات HTTP.
- عملية التسجيل أو النقل أو التجديد التي تجيب عنها البوابة بـ HTTP 200 ولكن مع `"success": false` تُعد رفضًا وليست نجاحًا: إذ تُرجع غلاف الخطأ بالرمز `REGISTER_DOMAIN` أو `TRANSFER_DOMAIN` أو `RENEW_DOMAIN` مع رسالة البوابة.
- تحتفظ `get_current_balance` بغلافها الخاص: `'OperationResult' => 'FAILED'` مع `ErrorCode` و `OperationMessage`.
- تُرجع `check_availability` قائمة عادية عند النجاح وغلاف الخطأ عند الفشل.

لا تُطلق الاستثناءات إلا لأخطاء المبرمج (على سبيل المثال، تُطلق `set_resource_record_set` الاستثناء `TypeError` إذا كانت `contents` ليست قائمة).

مهلة كل استدعاء 30 ثانية، ومهلة الاتصال 10 ثوانٍ. يُحافَظ على فاصل لا يقل عن ثانية واحدة بين استدعاءات نقاط نهاية منطقة DNS، لأن البوابة تستجيب بـ `HTTP 429` للطلبات المتلاحقة.

### التشخيص

```ruby
dna.get_request_data         # { 'url' => ..., 'method' => 'GET', 'payload' => {...} } لآخر استدعاء
dna.get_response_data        # آخر جسم استجابة مفكوك (أو { 'raw_response' => body })
dna.get_response_headers     # { 'url', 'http_code', 'headers', 'total_time' }
dna.get_parsed_response_data # آخر جسم محلَّل، أو آخر خطأ { 'Code', 'Message', 'Details' }
dna.get_last_function        # على سبيل المثال 'request:GET domains/info'
dna.get_service_url          # https://api.domainresellerapi.com/api/v1
dna.set_service_url('https://ote.domainresellerapi.com/api/v1')
```

## وضع الاختبار

مرّر `true` كوسيط ثالث للدالة الإنشائية لاستخدام بوابة الاختبار OTE ‏(`https://ote.domainresellerapi.com/api/v1`). تذهب الاستدعاءات الحية إلى `https://api.domainresellerapi.com/api/v1`. يستخدم وضع الاختبار بيانات اعتماد اختبار منفصلة.

## تقارير الأخطاء (القياس عن بُعد)

عندما يفشل طلب API، يمكن للمكتبة إرسال تقرير خطأ إلى نظام تتبع الأخطاء الخاص بـ DomainNameAPI ‏(Sentry). كما يمكن إرسال جزء صغير عشوائي من الطلبات الناجحة (4%، بالإضافة إلى كل طلب تتجاوز مدته ثانية واحدة) كسجل أداء. يساعد ذلك DomainNameAPI على اكتشاف المشكلات وإصلاحها. تقارير الأخطاء **مفعّلة افتراضيًا**.

> ℹ️ في الإصدار 1.0.0 لا يوجد بعدُ مشروع Sentry خاص بـ ruby-dna، لذا فإن DSN المدمج فارغ و**لا يُرسَل أي شيء**. تبدأ التقارير بالإرسال عندما يتضمن أحد الإصدارات قيمة DSN. يمكن تعيين قيمة صراحةً باستخدام `DomainNameApi::Client.new(id, key, false, sentry_dsn: '...')`.

**ما يتم إرساله:**

- رمز الخطأ ورسالته
- مسار نقطة النهاية المستدعاة وطريقة HTTP
- مدة الطلب
- اسم المكتبة (`DomainNameAPI-Ruby`) وإصدار المكتبة وإصدار Ruby
- معرّف الموزع (Reseller ID) واسم النطاق
- عنوان IP العام للخادم (يتم الحصول عليه عبر `api.ipify.org`، في الخلفية)
- اسم مستخدم نظام التشغيل الذي تعمل العملية باسمه
- طلب API والاستجابة، بما في ذلك بيانات الاتصال الخاصة بالنطاق؛ يتم إخفاء بيانات الاعتماد فقط — تُستبدل رموز EPP/auth ومفاتيح API وكلمات المرور والرموز المميزة (tokens) بـ `***`

**ما لا يتم إرساله أبدًا:** رموز EPP/auth أو مفاتيح API أو كلمات المرور أو الرموز المميزة (tokens) بصيغة مقروءة؛ وسائط استدعاءات الدوال في تتبع المكدس (stack traces).

لا يتم الإبلاغ عن الأخطاء المتوقعة وكثيرة التكرار (النطاق غير موجود، الرصيد غير كافٍ، بيانات اعتماد غير صالحة، ...). تُرسَل التقارير من خيط (thread) في الخلفية بمهلات قصيرة: فهي لا تُبطئ استدعاءك ولا تُعطّله أبدًا.

**لماذا وإلى متى:** تُستخدم البيانات فقط لقياس الاستخدام والتشخيص المبكر للمشكلات، وتُحفظ لمدة 30 يومًا على خادم Sentry الخاص بـ DomainNameAPI، ثم تُحذف تلقائيًا.

**كيفية الإيقاف:**

```ruby
dna = DomainNameApi::Client.new(reseller_id, api_key)
dna.set_error_reporting_enabled(false)
```

**الوضع المصغّر (Minimal)** يرسل فقط رمز الخطأ ورسالته، ونقطة النهاية، والتوقيت، والإصدارات، ومعرّف الموزع (Reseller ID) — دون بيانات الطلب/الاستجابة أو النطاق أو عنوان IP للخادم أو اسم المستخدم:

```ruby
dna.set_telemetry_minimal(true)
```

> 🔒 **الأمان:** التحقق من شهادة TLS مفعّل. على خادم تكون حزمة شهادات CA فيه قديمة، يمكن إيقافه باستخدام `dna.set_ssl_verification(false)` — غير مستحسن؛ تحديث حزمة CA هو الحل الأفضل.

## الاستخدام

تفترض جميع الأمثلة وجود `dna = DomainNameApi::Client.new(reseller_id, api_key)`. توجد سكربتات قابلة للتشغيل لكل دالة في مجلد [examples](examples).

### الحساب

#### معلومات الموزع

```ruby
dna.get_reseller_details
```

<details>
<summary>مثال على المخرجات</summary>

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

#### الرصيد الحالي

`get_current_balance(currency = 'USD')` — يُبلغ الحساب عن رصيدَي `'USD'` و `'TRY'`. أما لأي عملة أخرى (`'EUR'` و `'GBP'` و...) فيفشل الاستدعاء مع `'ErrorCode' => 'BALANCE'` بدلًا من الإجابة بـ `0.00`.

```ruby
dna.get_current_balance('USD')
```

<details>
<summary>مثال على المخرجات</summary>

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

### البحث والقوائم

#### التحقق من توفر النطاق

`check_availability(domains, extensions, period, command = 'create')` — يكون `DomainName` في النتيجة هو الاسم دون اللاحقة `.tld` في نهايته.

```ruby
dna.check_availability(['hello', 'world123x0'], ['com', 'net'], 1, 'create')
```

<details>
<summary>مثال على المخرجات</summary>

```ruby
[
  { 'TLD' => 'com', 'DomainName' => 'hello', 'Status' => 'notavailable', 'Command' => 'create',
    'Period' => 1, 'IsFee' => false, 'Price' => '10.8100', 'Currency' => 'USD', 'Reason' => 'Domain exists' },
  { 'TLD' => 'com', 'DomainName' => 'world123x0', 'Status' => 'available', 'Command' => 'create',
    'Period' => 1, 'IsFee' => false, 'Price' => '10.8100', 'Currency' => 'USD', 'Reason' => nil }
]
```

</details>

#### قائمة النطاقات

`get_list(extra_parameters = {})` — `PageNumber` (يبدأ من 0)، و `PageSize`، و `OrderColumn`، و `OrderDirection`، بالإضافة إلى عوامل التصفية الخاصة بالبوابة (مثل `DomainName`).

```ruby
dna.get_list('OrderColumn' => 'Id', 'OrderDirection' => 'ASC', 'PageNumber' => 0, 'PageSize' => 1000)
```

<details>
<summary>مثال على المخرجات</summary>

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

#### قائمة امتدادات النطاقات (TLD)

`get_tld_list(count = 20)`

```ruby
dna.get_tld_list(100)
```

<details>
<summary>مثال على المخرجات</summary>

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

### النطاق

#### تسجيل النطاق

`register_with_contact_info(domain, period, contacts, name_servers = [], epp_lock = true, privacy_lock = false, additional_attributes = {})`

تستخدم جهات الاتصال مفاتيح php-dna. تُقبل كلٌّ من البنية المسطّحة أدناه والبنية المتداخلة التي تُرجعها `get_contacts` ‏(`Address => { Line1, City, ... }`، و `Phone => { Phone => { Number, CountryCode } }`)؛ تُستكمل الحقول المفقودة وتُوحَّد صيغ الأسماء والهواتف والدول (انظر `validate_contact`). في حال عدم تحديد خوادم أسماء، يُستخدم `ns1.domainnameapi.com` و `ns2.domainnameapi.com`.

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

بالنسبة لنطاقات `.tr`، مرّر سمات TRABIS كوسيط سابع:

```ruby
# مالك فردي
{ 'TRABISDOMAINCATEGORY' => 1, 'TRABISCITIZIENID' => '12345678901' }
# مالك شركة
{ 'TRABISDOMAINCATEGORY' => 0, 'TRABISTAXOFFICE' => 'Istanbul VD', 'TRABISTAXNUMBER' => '1234567890' }
```

تُرسَل الفئة بالقيمة `Owner`/`Corporate`، ويُرسَل `TRABISCITIZIENID` باسم `TRABISCITIZENID`، وتُحذف المفاتيح القديمة (`TRABISNAMESURNAME` و `TRABISCOUNTRYID` و `TRABISCITYID` و...)، لأن البوابة باتت تقرؤها من بيانات جهة الاتصال.

<details>
<summary>مثال على المخرجات</summary>

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

#### تجديد النطاق

```ruby
dna.renew('example.com', 1)
```

<details>
<summary>مثال على المخرجات</summary>

```ruby
{ 'result' => 'OK', 'data' => { 'ExpirationDate' => '2025-03-15T10:00:00' } }
```

</details>

#### تفاصيل النطاق

```ruby
dna.get_details('example.com')
```

<details>
<summary>مثال على المخرجات</summary>

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

#### المزامنة من السجل (Registry)

الاستدعاء نفسه والمخرجات نفسها كما في `get_details`.

```ruby
dna.sync_from_registry('example.com')
```

#### تعديل خوادم الأسماء

مرّر قائمة أو Hash (تُستخدم القيم). تُزال المسافات الزائدة من الأسماء، وتُحوَّل إلى أحرف صغيرة، وتُحذف النقطة في نهايتها، وتُزال القيم المكررة؛ وتُبلغ النتيجة عن هذه القائمة بعد توحيد صيغتها.

```ruby
dna.modify_name_server('example.com', ['ns1.example.com', 'ns2.example.com'])
```

<details>
<summary>مثال على المخرجات</summary>

```ruby
{ 'result' => 'OK', 'data' => { 'NameServers' => ['ns1.example.com', 'ns2.example.com'] } }
```

</details>

#### تفعيل قفل النطاق

```ruby
dna.enable_theft_protection_lock('example.com')
```

<details>
<summary>مثال على المخرجات</summary>

```ruby
{ 'result' => 'OK', 'data' => { 'LockStatus' => true } }
```

</details>

#### إلغاء قفل النطاق

```ruby
dna.disable_theft_protection_lock('example.com')
```

<details>
<summary>مثال على المخرجات</summary>

```ruby
{ 'result' => 'OK', 'data' => { 'LockStatus' => false } }
```

</details>

#### تعديل خصوصية النطاق

`modify_privacy_protection_status(domain, status, reason = 'Owner request')` — يمكن أن تكون قيمة `status` هي `true`/`false` أو قيمة بأسلوب لوحات التحكم: القيم `1` و `'1'` و `'true'` و `'on'` و `'yes'` تُفعّل الخصوصية، وأي قيمة أخرى تُعطّلها. تُبلغ النتيجة عن القيمة المنطقية (boolean) بعد تحليلها. يُقبل المعامل `reason` للتوافق فقط ولكنه لا يُرسَل: إذ لا يوجد لدى البوابة حقل كهذا.

```ruby
dna.modify_privacy_protection_status('example.com', true, 'Owner request')
```

<details>
<summary>مثال على المخرجات</summary>

```ruby
{ 'data' => { 'PrivacyProtectionStatus' => true }, 'result' => 'OK' }
```

</details>

#### الحصول على جهات اتصال النطاق

تُطابَق أنواع جهات الاتصال دون التمييز بين الأحرف الكبيرة والصغيرة (`admin`/`administrative`، و `tech`/`technical`، و `registrant`/`owner`، و `billing`)؛ أما الأنواع الأخرى التي يُرجعها السجل (Registry) فيُحتفظ بها بعد الأنواع القياسية الأربعة.

```ruby
dna.get_contacts('example.com')
```

<details>
<summary>مثال على المخرجات</summary>

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
      # أي نوع آخر من جهات الاتصال يُرجعه السجل يأتي بعد هذه الأنواع الأربعة
    }
  },
  'result' => 'OK'
}
```

</details>

#### حفظ جهات اتصال النطاق

```ruby
dna.save_contacts('example.com', {
  'Administrative' => contact,
  'Billing'        => contact,
  'Technical'      => contact,
  'Registrant'     => contact
})
```

<details>
<summary>مثال على المخرجات</summary>

```ruby
{ 'result' => 'OK', 'data' => { 'contacts' => {} } }
```

</details>

<hr style="border: 4px solid #000; border-style: dashed;">

### خوادم الأسماء الفرعية

#### إضافة خادم أسماء فرعي

```ruby
dna.add_child_name_server('example.com', 'ns1.example.com', '1.2.3.4')
```

<details>
<summary>مثال على المخرجات</summary>

```ruby
{ 'result' => 'OK', 'data' => { 'NameServer' => 'ns1.example.com', 'IPAdresses' => ['1.2.3.4'] } }
```

</details>

#### حذف خادم أسماء فرعي

```ruby
dna.delete_child_name_server('example.com', 'ns1.example.com')
```

<details>
<summary>مثال على المخرجات</summary>

```ruby
{ 'result' => 'OK', 'data' => { 'NameServer' => 'ns1.example.com' } }
```

</details>

#### تحديث خادم أسماء فرعي

```ruby
dna.modify_child_name_server('example.com', 'ns1.example.com', '1.2.3.5')
```

<details>
<summary>مثال على المخرجات</summary>

```ruby
{ 'result' => 'OK', 'data' => { 'NameServer' => 'ns1.example.com', 'IPAdresses' => ['1.2.3.5'] } }
```

</details>

<hr style="border: 4px solid #000; border-style: dashed;">

### عمليات النقل

#### نقل النطاق

`transfer(domain, epp_code, period)` — لا يُرسل طلب النقل جهات الاتصال أبدًا: إذ يتولى المسجّل (registrar) أمرها، لذا يحمل الطلب دائمًا قائمة جهات اتصال فارغة ولا تأخذ الدالة أي وسيط لجهات الاتصال. حدّث جهات الاتصال باستخدام `save_contacts` بعد اكتمال النقل.

```ruby
dna.transfer('example.com', 'Xy9#mK2$', 3)
```

<details>
<summary>مثال على المخرجات</summary>

```ruby
{
  'data' => { 'ID' => 0, 'Status' => 'WaitingForIncomingTransfer', 'DomainName' => 'example.com', ... },
  'result' => 'OK'
}
```

</details>

#### التحقق من إمكانية النقل

تكون قيمة `result` هي `'OK'` فقط عندما يُفيد السجل (Registry) بأن النطاق قابل للنقل.

```ruby
dna.check_transfer('example.com', 'Xy9#mK2$')
```

<details>
<summary>مثال على المخرجات</summary>

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

#### إلغاء النقل أو الموافقة عليه أو رفضه

تُلغي `cancel_transfer` عملية نقل واردة معلّقة؛ بينما تُجيب `approve_transfer` و `reject_transfer` على عملية نقل صادرة معلّقة.

```ruby
dna.cancel_transfer('example.com')
dna.approve_transfer('example.com')
dna.reject_transfer('example.com')
```

<details>
<summary>مثال على المخرجات</summary>

```ruby
{ 'result' => 'OK', 'data' => { 'DomainName' => 'example.com', 'Status' => 'Cancelled' } } # 'Approved' / 'Rejected'
```

</details>

<hr style="border: 4px solid #000; border-style: dashed;">

### منطقة DNS

أنواع السجلات المدعومة: `A` و `AAAA` و `ALIAS` و `CAA` و `CNAME` و `DS` و `MX` و `NAPTR` و `PTR` و `SRV` و `TLSA` و `TXT` (تُرفض الأنواع الأخرى قبل إجراء أي استدعاء). الأسماء نسبية (`'www'`)؛ وتمثّل `''` أو `'@'` جذر المنطقة (apex)، ويُختزل الاسم الكامل مثل `'www.example.com'` إلى التسمية (label) الخاصة به. تُطبَّق التغييرات فورًا؛ مرّر `apply = false` لتجهيز عدة تغييرات ثم استدعِ `apply_resource_records` مرة واحدة. تتراوح قيمة TTL بين 1 و 86400 ثانية.

إذا فشل التطبيق التلقائي، تُرجع الدالة خطأ التطبيق (ويبقى التغيير مُجهَّزًا وغير مفعّل) بدلًا من `OK`. تُبلغ النتيجة عن النوع بأحرف كبيرة وعن قيمة TTL اللذين أُرسلا فعليًا.

تخزّن البوابة كل اسم + نوع على شكل **مجموعة (set)** واحدة: كتابة مجموعة تستبدل جميع قيمها، وحذف قيمة واحدة يحذف المجموعة بأكملها. تتولى دوال `*_resource_record_value` تنفيذ عملية القراءة ثم الدمج ثم الكتابة نيابةً عنك.

#### عرض السجلات

```ruby
dna.get_resource_records('example.com')
```

<details>
<summary>مثال على المخرجات</summary>

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

#### استبدال مجموعة سجلات

`set_resource_record_set(domain, name, type, contents, ttl = 3600, apply = true)` — تؤدي القائمة الفارغة إلى إزالة المجموعة.

```ruby
dna.set_resource_record_set('example.com', 'www', 'A', ['192.0.2.10', '192.0.2.11'], 3600)
```

<details>
<summary>مثال على المخرجات</summary>

```ruby
{ 'result' => 'OK', 'data' => { 'Name' => 'www', 'Type' => 'A', 'TTL' => 3600, 'Contents' => ['192.0.2.10', '192.0.2.11'] } }
```

</details>

#### إضافة قيمة واحدة أو استبدالها أو إزالتها

`add_resource_record_value(domain, name, type, value, ttl = nil, apply = true)`، و `replace_resource_record_value(domain, name, type, old_value, new_value, ttl = nil, apply = true)`، و `remove_resource_record_value(domain, name, type, value, apply = true)`. تُبقي قيمة TTL المساوية لـ `nil` على قيمة TTL الحالية للمجموعة؛ وإضافة قيمة موجودة مسبقًا أو إزالة قيمة غير موجودة لا تُحدث أي تغيير (`'Changed' => false`).

```ruby
dna.add_resource_record_value('example.com', '', 'MX', '10 mail.example.com.')
dna.replace_resource_record_value('example.com', '', 'MX', '10 mail.example.com.', '20 mail.example.com.')
dna.remove_resource_record_value('example.com', '', 'MX', '20 mail.example.com.')
```

<details>
<summary>مثال على المخرجات</summary>

```ruby
{ 'result' => 'OK', 'data' => { 'Name' => '', 'Type' => 'MX', 'TTL' => 3600, 'Contents' => ['10 mail.example.com.'] } }
# القيمة موجودة مسبقًا:
{ 'result' => 'OK', 'data' => { 'Name' => '', 'Type' => 'MX', 'Contents' => ['10 mail.example.com.'], 'Changed' => false } }
```

</details>

#### حذف مجموعة سجلات

`delete_resource_record_set(domain, name, type, apply = true, known_value = '')` — تزيل جميع قيم المجموعة؛ وإذا لم يكن هناك ما يُزال فالنتيجة نجاح مع `'Removed' => false`.

```ruby
dna.delete_resource_record_set('example.com', 'www', 'A')
```

<details>
<summary>مثال على المخرجات</summary>

```ruby
{ 'result' => 'OK', 'data' => { 'Name' => 'www.example.com.', 'Type' => 'A', 'Content' => '192.0.2.10' } }
```

</details>

#### استدعاءات السجلات منخفضة المستوى

```ruby
dna.add_resource_record('example.com', 'www', 'A', '192.0.2.10', 3600, true)
dna.edit_resource_record('example.com', 'www', 'www', 'A', '192.0.2.20', 3600, true)
dna.delete_resource_record('example.com', 'www.example.com.', '192.0.2.20', 'A', true)
dna.apply_resource_records('example.com')
```

<details>
<summary>مثال على المخرجات</summary>

```ruby
{ 'result' => 'OK', 'data' => { 'Name' => 'www', 'Type' => 'A', 'TTL' => 3600, 'Content' => '192.0.2.10' } }   # إضافة / تعديل
{ 'result' => 'OK', 'data' => { 'Name' => 'www.example.com.', 'Type' => 'A', 'Content' => '192.0.2.20' } }    # حذف
{ 'result' => 'OK', 'data' => { 'DomainName' => 'example.com' } }                                              # تطبيق
```

</details>

<hr style="border: 4px solid #000; border-style: dashed;">

### إعادة توجيه URL

أنواع إعادة التوجيه: `'Standard'` (إعادة توجيه عادية) و `'Frame'` (مُقنّعة). تجيب البوابة بـ `Redirect information not found` عندما لا يكون هناك أي إعداد: عندها تُبلغ `get_forwarding` عن `'Enabled' => false`، وتنجح `delete_forwarding` مع `'Removed' => false`. أما أي خطأ آخر، مثل نطاق غير معروف، فيُرجَع كخطأ.

```ruby
dna.set_forwarding('example.com', 'https://www.example.org', 'Standard')
dna.get_forwarding('example.com')
dna.delete_forwarding('example.com')
```

<details>
<summary>مثال على المخرجات</summary>

```ruby
# set_forwarding
{ 'result' => 'OK', 'data' => { 'RedirectAddress' => 'https://www.example.org', 'ForwardType' => 'Standard' } }
# get_forwarding (عند عدم وجود أي إعداد تكون النتيجة Enabled => false، وليست خطأً)
{ 'result' => 'OK', 'data' => { 'Enabled' => true, 'RedirectAddress' => 'https://www.example.org', 'ForwardType' => 'Standard' } }
# delete_forwarding (القيمة Removed => false عند عدم وجود أي إعداد)
{ 'result' => 'OK', 'data' => { 'DomainName' => 'example.com', 'Removed' => true } }
```

</details>

<hr style="border: 4px solid #000; border-style: dashed;">

### أدوات مساعدة (دون اتصال بالشبكة)

#### هل هو نطاق .tr؟

```ruby
dna.is_tr_tld('example.com.tr') # => true
dna.is_tr_tld('example.com')    # => false
```

#### التحقق من جهة اتصال

تستكمل جهة الاتصال وتوحّد صيغتها بالطريقة نفسها التي يتبعها التسجيل: تُزال الأرقام وعلامات الترقيم من الأسماء، وتُستخدم المدينة مكان الولاية المفقودة، وتتحول أسماء الدول إلى رموز ISO، وتُقسَّم أرقام الهواتف إلى الرقم ورمز الدولة. الرقم المكتوب مع رمز الاتصال الدولي الخاص به بالبادئة `+` أو `00` يحتفظ بذلك الرمز حتى لو أُعطيت قيمة أخرى لـ `PhoneCountryCode` ‏(`'+1 202 555 0100'` → `'2025550100'` / `'1'`).

```ruby
dna.validate_contact('FirstName' => 'J0hn', 'Phone' => '+90 532 374 33 88', 'Country' => 'Turkey')
```

<details>
<summary>مثال على المخرجات</summary>

```ruby
{
  'FirstName' => 'Jhn', 'Phone' => '5323743388', 'Country' => 'TR', 'LastName' => 'Isimyok',
  'AddressLine1' => 'Addres yok', 'City' => 'ISTANBUL', 'State' => 'ISTANBUL', 'ZipCode' => '34000',
  'PhoneCountryCode' => '90', 'Fax' => '', 'FaxCountryCode' => ''
}
```

</details>

<hr style="border: 4px solid #000; border-style: dashed;">

### الإعدادات

| الدالة | التأثير |
|---|---|
| `set_error_reporting_enabled(false)` | إيقاف القياس عن بُعد |
| `set_telemetry_minimal(true)` | إرسال الحد الأدنى من بيانات القياس عن بُعد |
| `set_ssl_verification(false)` | تخطّي التحقق من شهادة TLS (غير مستحسن) |
| `set_service_url(url)` | استخدام عنوان URL مختلف للبوابة |
| `set_transport(callable)` | استبدال طبقة نقل HTTP (انظر أدناه) |

طبقة نقل HTTP هي أي كائن يستجيب لـ `call(request)`، حيث تكون `request` عبارة عن Hash يحتوي على `:method` و `:url` و `:headers` و `:body` و `:timeout` و `:connect_timeout` و `:verify_ssl`، ويُرجع كائن `DomainNameApi::Response` (أو Hash يحتوي على `:status` و `:body` و `:headers`). الطبقة الافتراضية هي `DomainNameApi::NetHttpTransport` ‏(Net::HTTP). وبهذه الطريقة تعمل الاختبارات دون شبكة:

```ruby
fake = ->(request) { DomainNameApi::Response.new(status: 200, body: '{"resellerId":"abc"}', headers: {}) }
dna = DomainNameApi::Client.new(reseller_id, api_key, false, transport: fake)
```

<hr style="border: 4px solid #000; border-style: dashed;">

## الاختبارات

تستخدم مجموعة الاختبارات Minitest فقط، ولا تتصل بالشبكة أبدًا:

```bash
bundle install
bundle exec rake test
```

يشغّل `test/conformance_test.rb` بيانات المطابقة الـ 126 الخاصة بـ php-dna ‏(`test/fixtures/conformance/`): ففي كل سيناريو يتحقق من الطلبات المُرسَلة (الطريقة، والمسار، والاستعلام، وجسم JSON، وترويسات المصادقة) ومن القيمة المُرجَعة، مقارنةً بما أنتجته php-dna. أما الاختبارات الأخرى فتغطي طبقة HTTP، وتحويل الأخطاء، وإخفاء البيانات في القياس عن بُعد، وطبقة النقل Net::HTTP، والأدوات المساعدة.

<hr style="border: 4px solid #000; border-style: dashed;">

## رموز العودة والأخطاء مع تفسيراتها

| الرمز | الوصف | التفاصيل |
|-------|--------|-----------|
| 1000 | تم تنفيذ الأمر بنجاح | العملية ناجحة |
| 1001 | تم تنفيذ الأمر بنجاح؛ الإجراء معلق | العملية ناجحة ولكنها في قائمة الانتظار للإكمال |
| 2003 | معلمة مطلوبة مفقودة | خطأ في المعلمات، مثل عدم إدخال رقم الهاتف في معلومات الاتصال |
| 2105 | الكائن غير مؤهل للتجديد | حالة النطاق غير مناسبة للتجديد، مقفلة للتحديثات |
| 2200 | خطأ في المصادقة | خطأ في التفويض، رمز الأمان خاطئ أو النطاق مسجل لدى شركة تسجيل أخرى |
| 2302 | الكائن موجود | اسم النطاق أو معلومات خادم الأسماء موجودة في قاعدة البيانات، لا يمكن التسجيل |
| 2303 | الكائن غير موجود | اسم النطاق أو معلومات خادم الأسماء غير موجودة في قاعدة البيانات، يجب إنشاء تسجيل جديد |
| 2304 | حالة الكائن تمنع العملية | حالة النطاق غير مناسبة للتحديث، مقفلة للتحديثات |

| الرمز | التفاصيل                                                                                                                               |
|------|---------------------------------------------------------------------------------------------------------------------------------------|
| 101  | خطأ النظام مفصل لـ ({0})!                                                                                                              |
| 102  | أخطاء متعددة مفصلة لـ ({0})!                                                                                                           |
| 103  | أخطاء غير معروفة مفصلة لـ ({0})!                                                                                                        |
| 200  | أمر API غير موجود ({0})!                                                                                                              |
| 210  | خدمة API غير موجودة ({0})!                                                                                                            |
| 211  | مزود خدمة API غير مُعيَّن!                                                                                                             |
| 300  | الموزع غير موجود!                                                                                                                     |
| 301  | عنوان IP الحالي الخاص بك غير مخول للوصول. تأكد من أنك تتصل من عنوان IP مخول وحاول مرة أخرى                                              |
| 310  | TLD غير مدعوم!                                                                                                                        |
| 320  | API غير موجود!                                                                                                                        |
| 321  | العملة غير مدعومة!                                                                                                                    |
| 330  | المعاملات المطلوبة غير مُعيَّنة ({0}).                                                                                                  |
| –    | تأكد من إرسال جميع كائنات الاتصال بالكامل                                                                                                |
| 340  | تعريف السعر غير موجود ({0}[{1}]-{2}{3}).                                                                                              |
| 350  | رصيد الموزع غير كافٍ. (معرف الموزع : {0} - الرصيد الحالي : {1} {2}).                                                                   |
| 350  | عملة المحاسبة غير متطابقة أو الرصيد غير كافٍ.                                                                                          |
| 360  | طلب API غير صالح للحقل ({0}).                                                                                                          |
| 360  | تم تجاوز حصة API!                                                                                                                     |
| 361  | خطأ في التحكم في المعدل!                                                                                                               |
| 362  | النطاق المميز غير متاح للتسجيل الآن.                                                                                                    |
| 363  | تم إلغاء العملية لأن النطاق في فترة التجديد الآلي                                                                                       |
| 364  | هذا النطاق غير متاح حاليًا للمعاملة بسبب مشكلة في السجل                                                                               |

| الرمز | التفاصيل                                                                                       |
|------|----------------------------------------------------------------------------------------------|
| 400  | اتصال غير صالح ({0}).                                                                          |
| 401  | لا يمكن مزامنة معلومات الاتصال.                                                                |
| 402  | لا يوجد وصول لمعلومات الاتصال من السجل.                                                        |
| 403  | النظام يحتوي على معلومات مفقودة. أدخل معلوماتك الافتراضية أو اتصل بفريق الدعم.                     |
| 404  | لا يمكن تحديث اتصال النطاق. إذن من السجل.                                                       |
| 410  | الاتصال غير موجود.                                                                            |
| 410  | الاتصال غير موجود ({0}).                                                                       |
| 420  | أمر Api غير صالح للاتصال {0}.                                                                 |
| 430  | API الاتصال غير موجود.                                                                        |
| 440  | الاتصال غير متزامن.                                                                           |
| 450  | اتصالات النطاق كثيرة جداً.. !                                                                  |
| 451  | فشل في المتابعة مع تحديث الاتصال.                                                              |

| الرمز | التفاصيل                                                                                                                               |
|------|---------------------------------------------------------------------------------------------------------------------------------------|
| 500  | معرف النطاق غير صالح.                                                                                                                 |
| 500  | معرف النطاق غير صالح ({0}).                                                                                                           |
| 501  | لا يمكن مزامنة النطاق ({0})                                                                                                          |
| 502  | فشل النقل الداخلي                                                                                                                    |
| 503  | تسجيل النطاق غير متاح.                                                                                                               |
| 504  | معلومات النطاق غير متطابقة .. قبل :{0}                                                                                               |
| 505  | أدخل عنوان IP.                                                                                                                       |
| 506  | تم بدء نقل النطاق لكن لا يمكن قراءة معلومات الاتصال ..                                                                              |
| 507  | خطأ في التفويض.                                                                                                                      |
| 510  | النطاق غير موجود.                                                                                                                    |
| 511  | لا يمكن العثور على النطاقات المنتهية الصلاحية.                                                                                        |
| 512  | النطاق غير قابل للتجديد.                                                                                                             |
| 513  | النطاق ليس في حالة قابلة للتحديث. يجب أن يكون نشطاً ليتم تحديثه                                                                      |
| 514  | فترة الاسترداد متوقعة.                                                                                                               |
| 520  | أمر Api غير صالح للنطاق "{0}".                                                                                                       |
| 530  | فترة النطاق غير صالحة. يجب أن تكون الفترة من {0} إلى {1} سنة. الفترة المطلوبة هي {2} سنة.                                         |
| 540  | لا يمكن تمديد النطاق إلى ما بعد {0} سنة من التاريخ الحالي.                                                                          |
| 550  | اسم النطاق غير صالح. يجب أن يكون النطاق من {0} إلى {1} حرف. اسم النطاق المطلوب هو {2} حرف.                                     |
| 560  | عدد خوادم الأسماء غير صالح. يجب أن يحتوي النطاق على {0} إلى {1} خادم أسماء. عدد خوادم الأسماء المطلوب هو {2}.                    |
| 561  | لم يتم العثور على معلومات خادم الأسماء في الطلب الوارد                                                                             |
| 570  | Idn غير مدعوم لـ TLD "{0}".                                                                                                          |
| 571  | الفترة غير صالحة.                                                                                                                   |
| 572  | الأمر غير صالح.                                                                                                                     |
| 573  | أسماء النطاقات غير موجودة.                                                                                                           |
| 574  | أسماء TLD غير موجودة.                                                                                                               |
| 575  | النطاق ليس في حالة قابلة للتحديث. يجب أن يكون نشطاً لتحديث خوادم الأسماء                                                            |
| 576  | يمكن تجديد النطاق في الشهر الأخير قبل تاريخ انتهاء الصلاحية                                                                        |
| 580  | النقل غير مدعوم لـ TLD "{0}".                                                                                                        |
| 581  | خادم الأسماء الفرعي غير موجود                                                                                                        |
| 582  | تم بدء النقل بواسطة موزع آخر.                                                                                                        |
| 583  | النقل غير مُعيَّن. يرجى الاتصال بفريق الدعم.                                                                                         |
| 584  | حالة الكائن تمنع العملية                                                                                                             |
| 590  | رمز التفويض مطلوب لهذا النقل.                                                                                                        |
| 591  | رمز التفويض غير صالح.                                                                                                               |
| 592  | قفل النقل موجود على النطاق.                                                                                                          |
| 593  | لا يمكن نقل النطاق، معلومات الحالة وقفل النقل يجب أن تتوافق مع المعايير المطلوبة. (معلومات الحالة: #ok)                           |
| 594  | لا يمكن حل عنوان خادم أسماء النطاق ({0})                                                                                            |
| 595  | لا يمكن قراءة معلومات الاتصال (whois.registrar.tld) تأكد من أن حالة حماية الخصوصية مفتوحة                                          |
| 596  | لا يمكن التحقق من معلومات الاتصال                                                                                                   |
| 597  | TLD غير موجود                                                                                                                       |
| 598  | حدث خطأ غير معروف                                                                                                                   |
| 599  | إعادة توجيه النطاق غير موجود                                                                                                          |

## الترخيص

Apache License 2.0 — انظر [LICENSE](LICENSE).
