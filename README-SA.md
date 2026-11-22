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

# ruby-dna: حزمة SDK للغة Ruby لواجهة Domain Name API

[![CI](https://github.com/domainreseller/ruby-dna/actions/workflows/ci.yml/badge.svg)](https://github.com/domainreseller/ruby-dna/actions/workflows/ci.yml)
[![License](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](LICENSE)

عميل Ruby لواجهة REST API الخاصة بالموزّعين في [Domain Name API](https://www.domainnameapi.com): البحث عن
النطاقات وتسجيلها وتجديدها ونقلها، وDNS، وDNSSEC، وجهات الاتصال، وشهادات SSL، والاستضافة، والطلبات، وكتالوج
المنتجات، ورصيدك.

- **جميع عمليات API السبع والستين**، مجمّعة بالطريقة نفسها المتّبعة في [`dna` CLI](https://github.com/domainreseller/cli):
  الأمر `dna domain info` يقابله `client.domains.info`، والأمر `dna dns add` يقابله `client.dns.add`.
- **كائنات حقيقية لا Hash**: `domain.status.pending_delete?`، و`domain.expiration_date` من النوع `Time`،
  و`availability.available?`، و`tld.register_price(1)`.
- **كل عملية هي صنف طلب** يرث من `DomainNameApi::BaseRequest` ويتحقق من صحة نفسه قبل إرسال أي شيء.
  يمكنك كتابة طلباتك الخاصة بالطريقة نفسها.
- **آمنة افتراضيًا**: لا تُعاد محاولة الطلبات المُحاسَب عليها بشكل أعمى، و`read_only: true` يمنع التغييرات، ويضبط
  العميل وتيرة طلباته بنفسه تحت حدود المعدّل، ويمكن مشاركته بين الخيوط (threads) بأمان.
- **بلا اعتماديات.** يتطلب Ruby 3.1 أو أحدث، والمكتبة القياسية فقط.

```ruby
client = DomainNameApi::Client.new(reseller_id: reseller_id, api_key: api_key, environment: :ote)

a = client.domains.search('example.com')
puts "#{a.domain_name} is available for #{a.price} #{a.currency}" if a.available?
```

## المحتويات

- [التثبيت](#التثبيت)
- [بيانات الاعتماد والبيئات](#بيانات-الاعتماد-والبيئات)
- [الخدمات](#الخدمات)
- [الاستخدام](#الاستخدام)
- [النتائج والنماذج وقيم التعداد](#النتائج-والنماذج-وقيم-التعداد)
- [الطلبات و BaseRequest](#الطلبات-و-baserequest)
- [الأخطاء](#الأخطاء)
- [الأمان والموثوقية](#الأمان-والموثوقية)
- [خيارات العميل](#خيارات-العميل)
- [اختبار شيفرتك](#اختبار-شيفرتك)
- [الانتقال من v1](#الانتقال-من-v1)
- [التطوير](#التطوير)

## التثبيت

> ⬇️ استخدم إصدارًا موسومًا (tag) من [Releases](https://github.com/domainreseller/ruby-dna/releases/latest). أما الزر
> الأخضر **Code → Download ZIP** فيعطيك فرع التطوير.

باستخدام Bundler:

```ruby
# Gemfile
gem 'domainnameapi', git: 'https://github.com/domainreseller/ruby-dna.git', tag: 'v2.1.0'
```

أو ثبّت ملف `.gem` المرفق بالإصدار:

```bash
gem install ./domainnameapi-2.1.0.gem
```

```ruby
require 'domainnameapi'
```

تجد برامج قابلة للتشغيل في [examples](examples): `quickstart` و `register` و `expiring` و `dns` و `ssl` و
`custom_request`.

```bash
DNA_RESELLER_ID=... DNA_API_KEY=... DNA_ENV=ote ruby examples/quickstart.rb example.com
```

## بيانات الاعتماد والبيئات

تحتاج إلى بيانَي اعتماد لـ API من لوحة الموزّع (**API settings**). لا تعمل بيانات الدخول إلى اللوحة.

| بيان الاعتماد | شكله                                   |
|---------------|----------------------------------------|
| Reseller ID   | `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx` |
| API key       | سلسلة سرية طويلة                       |

هناك بيئتان. **ابدأ بـ OTE**، وهي بيئة الاختبار: لها بياناتها الخاصة ومفتاح API خاص بها،
ولا يكلّف أي شيء تفعله فيها مالًا ولا يمسّ النطاقات الحية.

```ruby
# بيئة الاختبار (OTE)
client = DomainNameApi::Client.new(reseller_id: reseller_id, api_key: ote_api_key, environment: :ote)

# الإنتاج (الافتراضي): تسجيلات حقيقية ورسوم حقيقية
client = DomainNameApi::Client.new(reseller_id: reseller_id, api_key: api_key)
```

يقبل `environment:` أيضًا السلاسل النصية التي تخزّنها لوحات التحكم: `'production'` و `'ote'` و `'test'`، وأعلام وضع
الاختبار (`'true'` و `'1'` و `true`). تقرأ `Client.from_env` المتغيرات نفسها التي يقرأها `dna` CLI:

| المتغير           | المعنى                                                        |
|-------------------|---------------------------------------------------------------|
| `DNA_RESELLER_ID` | معرّف الموزّع                                                 |
| `DNA_API_KEY`     | مفتاح API للبيئة المحددة                                      |
| `DNA_ENV`         | `production` (الافتراضي) أو `ote`                             |
| `DNA_TEST_MODE`   | القيمة `true` تختار OTE (كما في حزم DomainNameAPI SDK الأخرى) |
| `DNA_BASE_URL`    | عنوان URL أساسي مخصص، مثل وسيط (proxy)                        |

```ruby
client = DomainNameApi::Client.from_env(user_agent: 'my-panel/1.4')
```

يفشل المفتاح الخاطئ أو البيئة الخاطئة عند أول طلب بخطأ `APIError` تكون فيه قيمة `auth?` صحيحة ويوضّح `hint` فيه
ما يجب التحقق منه؛ و`client.account.get` هي أرخص طريقة للتجربة.

## الخدمات

| الخدمة             | مجموعة CLI    | العمليات                                                                                                                                                          |
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

تُمرَّر المدخلات المطلوبة كوسائط موضعية (`info('example.com')`)، وكل ما عداها وسائط مسمّاة (keyword)
(`renew('example.com', years: 1)`). وتقبل العمليات ذات المدخلات الاختيارية الكثيرة وسائط مسمّاة أو كائن طلب:
فـ `register(domain_name: ..., years: 1, ...)` و `register(DomainNameApi::DomainRegisterRequest.new(...))`
متكافئان. والدالة `ssl.purchase` هي الأمر `dna ssl initialize` في CLI (فالاسم `initialize` محجوز في Ruby).

## الاستخدام

تفترض جميع المقتطفات وجود `client`.

### البحث

```ruby
a = client.domains.search('example.com')
a.available?            # a.price, a.currency, a.premium?, a.document_required?, a.reason

client.domains.bulk_search('example.com', 'example.net', 'example.org').each do |r|
  puts "#{r.domain_name} #{r.status} #{r.price}"
end
```

تقسّم `bulk_search` القوائم التي تزيد على 30 نطاقًا إلى عدة طلبات. تُعرض الأسعار بعملة الحساب، أو بالعملة المحددة
في خيار العميل `currency: 'TRY'`، أو عبر `search('example.com', currency: 'USD')`.

### التسجيل

باستخدام معرّفات جهات الاتصال (أنشئ واحدًا بـ `contacts.create`):

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
  handles: handle # معرّف واحد للأدوار الأربعة كلها، أو { registrant: 'DNA-1', admin: 'DNA-2', tech: ..., billing: ... }
)
result.status           # result.domain_id, result.expiration_date
```

باستخدام جهات اتصال مضمَّنة:

```ruby
client.domains.register_with_contacts(
  domain_name: 'example.com',
  name_servers: %w[ns1.example.net ns2.example.net],
  contacts: owner # جهة اتصال (Contact) واحدة للأدوار الأربعة كلها، أو { registrant: owner, admin: admin, tech: admin, billing: admin }
)
```

يمكن أن تكون جهات الاتصال كائنات `DomainNameApi::Contact` أو Hash بالحقول نفسها. وتُنظَّف قبل الإرسال:
تُقصّ المسافات الزائدة من الحقول، ويُحوَّل رمز الدولة إلى أحرف كبيرة، وتُبقي حقول الهاتف أرقامها فقط
(يصلح `'+90 (555) 123-45-67'`). تحتاج بعض النطاقات العليا (TLD) إلى سمات خاصة بالسجل: اعثر عليها عبر
`client.products.tld('com.tr').required_attributes` ومرّرها في `tld_attributes:`.

إذا ردّت API لكنها رفضت الطلب (`"success": false`)، فإن الدالة تثير الاستثناء `DomainNameApi::OperationError` ومعه
رسالة API.

### التجديد والنقل والاستعادة

```ruby
check = client.domains.renew_check('example.com', years: 1)   # check.renewable?, check.premium_price
client.domains.renew('example.com', years: 1)

tc = client.domains.transfer_check('example.com', 'auth-code') # tc.transferable?, tc.auth_code_valid?
client.domains.transfer('example.com', auth_code: 'auth-code')
client.domains.transfer_status('example.com').status

client.domains.restore('example.com') # خلال فترة الاسترداد (redemption)
```

### تفاصيل النطاق وقائمة النطاقات

```ruby
d = client.domains.info('example.com')
d.status                # => #<DomainNameApi::DomainStatus Active (0)>
d.expiration_date       # => 2027-03-15 10:20:30 UTC
d.remaining_days, d.locked?, d.privacy_protection?, d.name_servers, d.auth_code, d.hosts
d.contact(:registrant)&.email

# صفحة واحدة
page = client.domains.list(limit: 50, sort: 'expirationDate')
page.total_count
page.each { |domain| puts domain.domain_name }

# كل النطاقات؛ تُجلب الصفحات تباعًا أثناء التكرار
client.domains.all(statuses: [:active]) do |domain|
  puts "#{domain.domain_name} #{domain.expiration_date}"
end
client.domains.all.first(10) # من دون كتلة (block) تعيد Enumerator: تُجلب صفحة واحدة فقط
```

### القفل والخصوصية وخوادم الأسماء وخوادم الأسماء الفرعية

```ruby
client.domains.lock('example.com')
client.domains.unlock('example.com')
client.domains.set_privacy('example.com', true)
code = client.domains.update_auth_code('example.com')

client.domains.set_name_servers('example.com', %w[ns1.example.net ns2.example.net])
client.domains.set_name_servers('example.com', %w[ns1.other.net ns2.other.net], dnssec_mode: :disable) # للنطاقات الموقّعة بـ DNSSEC

client.domains.add_host('example.com', 'ns1.example.com', '192.0.2.10', '2001:db8::10') # يُكتشف إصدار IP تلقائيًا
client.domains.update_host('example.com', 'ns1.example.com', ip_addresses: ['192.0.2.20'])
client.domains.delete_host('example.com', 'ns1.example.com')
```

### جهات اتصال النطاق

```ruby
client.domains.set_contact_handles('example.com', admin: 'DNA-2', tech: 'DNA-2') # تبقى الأدوار الأخرى كما هي
client.domains.update_contacts('example.com', billing: billing_contact)

details = client.contacts.get('DNA-1')               # جهة الاتصال وحالة التحقق منها
result = client.contacts.update('DNA-1', contact)    # يحدّث كل نطاق يستخدم المعرّف
result.affected_domains.each { |a| puts "#{a.domain_name} #{a.new_handle}" }
client.contacts.resend_verification('DNA-1')          # تعيد false عندما لا يوجد ما يُتحقق منه
```

### منطقة DNS

```ruby
client.dns.add('example.com', name: 'www', type: :a, values: '192.0.2.10', ttl: 600)
client.dns.update('example.com', record_name: 'www', type: :a, values: %w[192.0.2.20 192.0.2.21]) # يستبدل كل قيم المجموعة
client.dns.delete('example.com', name: 'www', type: :a, value: '192.0.2.20')

client.dns.list('example.com').each do |set|
  puts "#{set.name} #{set.type} #{set.ttl} #{set.values.join(', ')}"
end

client.dns.apply('example.com') # تحويل النطاق إلى خوادم أسماء المنصة
```

يمكن أن تكون الأسماء نسبية (`'www'`) أو الجذر (`''` أو `'@'`) أو مؤهَّلة بالكامل. أنواع السجلات رموز (symbols) أو سلاسل
نصية بأي حالة أحرف (يُرسَل `:txt` و `'txt'` على أنهما `TXT`). يلتقط التحقق ما سترفضه API: سجل CNAME عند
الجذر، وقيمة CAA من دون ثلاثة أجزاء، وقيمة MX من دون أولوية، وسجل A بعنوان IPv6. تردّ بيئة الاختبار
على كل استدعاء للمنطقة بحالة HTTP 500، لذا لا يمكن تجربة شيفرة المناطق إلا في الإنتاج.

### DNSSEC

```ruby
results = client.dnssec.add('example.com', '2371 13 2 1F987CC6583E92DF0890718C42...') # كما يعرضه مزوّد DNS لديك
info = client.dnssec.get('example.com') # info.status.signed?, info.ds_records
client.dnssec.disable('example.com')
```

تقرأ `DomainNameApi::DS.parse` صيغة العرض (presentation format) وأسطر ملف المنطقة الكاملة؛ ويصلح أيضًا `DS.new(key_tag: ...,
algorithm: :ecdsa_p256_sha256, digest_type: :sha256, digest: '...')`.

### إعادة توجيه URL

```ruby
client.domains.set_forwarding('example.com', 'https://www.example.org')              # إعادة توجيه 301
client.domains.set_forwarding('example.com', 'https://www.example.org', type: :frame) # إعادة توجيه مقنّعة (masked)
f = client.domains.forwarding('example.com') # nil عندما لا يكون للنطاق إعادة توجيه
client.domains.delete_forwarding('example.com')
```

### مستندات السجل (.tr)

```ruby
doc = DomainNameApi::DocumentUpload.from_file(:identity_card, 'id.pdf')
client.domains.upload_documents('example.com.tr', doc)
client.domains.documents('example.com.tr').each { |d| puts "#{d.name} #{d.status}" }
```

تُرمَّز الملفات بـ base64 نيابةً عنك؛ ويُتحقق من الصيغة (PDF وJPG وPNG وDOC وDOCX وODT) والحجم (10 MB لكل ملف، و50 MB
لكل طلب) قبل الرفع.

### شهادات SSL

```ruby
csr = client.ssl.generate_csr(domain_name: 'example.com', country: 'TR', state: 'Istanbul', locality: 'Istanbul',
                              organization: 'Example Ltd', organization_unit: 'IT')
# يخصم من الرصيد (CLI: dna ssl initialize)
order = client.ssl.purchase('example.com', package_code: 'PositiveSSL')
id = order.certificate_id # احتفظ به: كل استدعاء لاحق يتطلبه
client.ssl.configure(certificate_id: id, csr: csr.csr, approver_mail: 'admin@example.com',
                     authentication_type: :email, web_server_type: :apache, contact: ssl_contact)
client.ssl.status(id).issued? # استعلم دوريًا حتى تصبح القيمة true
File.write('example.com.crt', client.ssl.content(id).chain)
```

يمكن أن يكون للنطاق الواحد أكثر من شهادة، ولذلك تُحدَّد الشهادة الموجودة بمعرّفها `certificate_id` (وهو GUID) لا باسم
النطاق: تعيده الدالتان `purchase` و `renew`، وتعثر عليه الدالة `list`. وإذا مُرِّر اسم نطاق في موضع المعرّف أُثير
الاستثناء `InputError` قبل إرسال أي شيء. اضبط إعدادات الشهادة خلال 15 يومًا من شرائها أو تجديدها.

```ruby
client.ssl.list(domain_name: 'example.com').each { |c| puts "#{c.certificate_id} #{c.status}" } # الأحدث أولًا
client.ssl.all { |c| puts "#{c.domain_name} #{c.subscription_expires_at}" } # كل الشهادات، صفحة تلو الأخرى

client.ssl.approvers(certificate_id: id)                                      # لشهادة موجودة
client.ssl.approvers(domain_name: 'example.com', package_code: 'PositiveSSL') # قبل الشراء

renewal = client.ssl.renew(id) # يخصم من الرصيد؛ متاح ابتداءً من 30 يومًا قبل انتهاء الاشتراك
client.ssl.configure(certificate_id: renewal.certificate_id, csr: new_csr.csr, approver_mail: 'admin@example.com',
                     authentication_type: :email, web_server_type: :apache, contact: ssl_contact)
```

للتجديد استدعِ `renew` ثم `configure` للشهادة الجديدة التي تعيدها. لا تستدعِ `purchase` مرة أخرى: فذلك طلب جديد مستقل
بسعر الشراء، ولن تنتقل الشهادة القديمة إلى الحالة `Renewed` أبدًا.

### الاستضافة

```ruby
client.hosting.packages.each { |p| puts p.service_plans.map(&:service_plan) }
created = client.hosting.create('example.com', service_plan: 'Linux-Starter') # يخصم من الرصيد

st = client.hosting.wait(created.service_id, timeout: 30 * 60) # يستعلم دوريًا حتى يصبح نشطًا
puts st.panel_address, st.username, st.password
```

لا تستدعِ `create` مرة أخرى لاستضافة ما زالت قيد التجهيز: فهذا يخصم الرسوم مرتين.

### الرصيد والأسعار والطلبات

```ruby
account = client.account.get
account.balance('USD')
profile = client.account.profile # profile.company_name, profile.account_currency, profile.status.active?

client.account.all_transactions(from: Date.new(2026, 11, 1)) do |tx|
  puts "#{tx.creation_time} #{tx.type} #{tx.change}"
end

tld = client.products.tld('com.tr')
tld&.register_price(1)&.to_s   # => "12.50 USD"

client.products.info('com', order_type: :renew, years: 2) # سعر تجديد .com لمدة سنتين
client.orders.get('ORDER-CODE')
```

## النتائج والنماذج وقيم التعداد

كل نتيجة هي `DomainNameApi::Model`: دوال قراءة بصيغة snake_case، ودوال استفهام تنتهي بـ `?` للأعلام، وكائنات `Time`
للتواريخ، ونماذج وقوائم متداخلة.

```ruby
d = client.domains.info('example.com')
d.locked?                 # وأيضًا d.locked
d.hosts.first.ip_addresses.first.address
d.to_h                    # Hash عادي بمفاتيح snake_case
d.raw                     # كائن JSON كما أرسلته API، للحقول التي لا تنمذجها هذه الـ gem
```

القيم الرقمية والقيم النصية الثابتة هي قيم تعداد (`DomainStatus` و `RecordType` و `ContactType` و `DocumentType` وغيرها):

```ruby
d.status.pending_delete?                       # دالة استفهام لكل عضو
d.status == DomainNameApi::DomainStatus::ACTIVE
d.status == :active                            # تصحّ المقارنة بالرموز والأسماء والأرقام أيضًا
d.status.to_s                                  # => "Active"
d.status.to_i                                  # => 0
DomainNameApi::DomainStatus.members            # جميع الأعضاء
```

تقبل الطلبات قيم التعداد أو الرموز أو الأسماء بأي حالة أحرف أو الأرقام: `statuses: [:active, 'PendingDelete', 7]`.

فكّ الترميز متسامح: التواريخ بلا منطقة زمنية، و`null`، و`[]` بدل `{}`، والأرقام المرسلة كسلاسل نصية، والأدوار بأي
حالة أحرف (`"registrant"` و `"ADMINISTRATIVE"`)، والقيم التي لا تعرفها هذه الـ gem بعد، كلها تُفكّ بنجاح بدلًا من
إفشال الاستدعاء (وتكون قيمة `status.known?` هي false في الحالة الأخيرة).

## الطلبات و BaseRequest

كل عملية في API هي صنف طلب: `DomainInfoRequest` و `DNSAddRequest` و `SSLConfigureRequest` وغيرها، وتُسمّى
على اسم أمر CLI (الأمر `dna domain renew` يقابله `DomainRenewRequest`). وجميعها ترث من
`DomainNameApi::BaseRequest` الذي يوفّر البنية الأساسية: لغة DSL على مستوى الصنف لـ `endpoint` و `attribute`، والتهيئة
بالوسائط المسمّاة، ودوال مساعدة للتحقق، وقوالب المسارات، وبُناة الاستعلام والجسم. أما طلبات القوائم فترث من
`PagedRequest` الذي يضيف `skip` و `limit` و `sort`. يبدو طلب من هذه الـ gem هكذا:

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

تبني دوال الخدمات هذه الطلبات نيابةً عنك. ترسل `client.call` أي طلب، بما في ذلك أصنافك الخاصة، مثلًا
لقراءة الحقول التي تحتاجها فقط أو لاستدعاء نقطة نهاية لم تغلّفها هذه الـ gem بعد:

```ruby
class Expiry < DomainNameApi::Model
  field :expiration_date, :time
  field :remaining_days, :integer, from: 'remainingDay'
end

class ExpiryRequest < DomainNameApi::BaseRequest
  endpoint :get, '/api/v1/domains/info', safety: :read
  returns Expiry            # احذفه لتحصل على JSON المحلَّل
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

| التجاوز        | الافتراضي         | الغرض                                                                       |
|----------------|-------------------|-----------------------------------------------------------------------------|
| `query`        | `nil`             | كائن `Query` (`params.string(...)`)، أو Hash، أو Array من الأزواج           |
| `body`         | `nil`             | Hash أو Array بأسماء API؛ وتُحوَّل قيم التعداد والنماذج والأوقات تلقائيًا   |
| `validate`     | لا شيء للتحقق منه | أبلغ عن المشكلات بـ `required` و `check` و `between` و `max_length` و `enum` |
| `decode(data)` | يستخدم `returns`  | تحويل JSON المحلَّل إلى نتيجتك                                              |

تُملأ العناصر النائبة في المسار من السمات (attributes) وتُهرَّب: `endpoint :get, '/api/v1/contacts/{handle}'`.

يحصل طلبك على كل ما تحصل عليه الطلبات المضمَّنة: بيانات الاعتماد، وإعادة المحاولة، وضبط الوتيرة، وتوحيد الأخطاء،
ومعرّفات الارتباط، والتتبع، وفرض وضع القراءة فقط. تعيد `client.execute(request)` كائن `Response` كاملًا
(الحالة، والترويسات، والجسم الخام، ومعرّف الارتباط، والحصة، والمحاولات) مع النتيجة المفكوكة في `value`.
وتتحقق `client.prepare(request)` من الطلب وتبني طلب HTTP الفعلي من دون إرساله، لتسجّل طلبًا مُحاسَبًا عليه أو تراجعه
قبل خروجه (يُخفى مفتاح API في `inspect`).

## الأخطاء

| الخطأ                            | متى                                                        | دوال مفيدة                                                                     |
|----------------------------------|------------------------------------------------------------|--------------------------------------------------------------------------------|
| `DomainNameApi::InputError`      | رفض التحقق الطلب؛ **لم يُرسَل شيء**                        | `request`, `fields`                                                            |
| `DomainNameApi::APIError`        | ردّت API بحالة غير 2xx                                     | `status`, `code`, `api_message`, `details`, `fields`, `data`, `correlation_id`, `hint` |
| `DomainNameApi::OperationError`  | ردّت API بحالة 2xx مع `"success": false`                   | `code`, `api_message`, `correlation_id`                                        |
| `DomainNameApi::NetworkError`    | لم يكتمل الطلب (DNS أو TLS أو انتهاء المهلة أو إعادة ضبط الاتصال) | `original`, `timeout?`                                                  |
| `DomainNameApi::ReadOnlyError`   | منع عميل للقراءة فقط تغييرًا؛ لم يُرسَل شيء                | `safety`                                                                       |

ترث جميعها من `DomainNameApi::Error` الذي يجيب عن الأسئلة الشائعة: `kind` (`:auth` و
`:not_found` و `:validation` و `:rejected` و `:conflict` و `:rate_limited` و `:server` و `:network` و `:invalid_input` و
`:read_only`) و `not_found?` و `auth?` و `rate_limited?` و `insufficient_balance?` و `outcome_unknown?` و
`retryable?` و `code?(code)`.

```ruby
begin
  client.domains.renew('example.com', years: 1)
rescue DomainNameApi::Error => e
  if e.outcome_unknown?
    # ربما تمّ التجديد. تحقّق من النطاق قبل المحاولة مرة أخرى.
  elsif e.insufficient_balance?
  elsif e.not_found?
  elsif e.code?(DomainNameApi::ErrorCode::PRIVACY_NOT_SUPPORTED)
  elsif e.is_a?(DomainNameApi::APIError)
    logger.error("#{e.code} #{e.api_message} #{e.hint} #{e.correlation_id}")
  end
end
```

فرّع على `code` لا على الرسالة: فالرسائل مترجَمة محليًا. تبدو رموز API هكذا
`Dna.DomainService:Domain:10007`؛ والشائعة منها ثوابت في `DomainNameApi::ErrorCode`، والبقية في
[مرجع الأخطاء](https://www.domainnameapi.com/docs/reference/errors.md). اذكر `correlation_id` عند
التواصل مع الدعم.

## الأمان والموثوقية

- **فئات الأمان.** كل طلب هو `:read` أو `:write` أو `:destructive` أو `:billable` (`request.safety` و
  `request.billable?`). بعض طلبات POST و PUT هي عمليات قراءة (`DomainSearchRequest` و `SSLStatusRequest`).
- **وضع القراءة فقط.** يمنع `read_only: true` كل ما ليس قراءة، لمهام إعداد التقارير ولاستكشاف
  بيئة الإنتاج بأمان.
- **إعادة المحاولة.** تُعاد محاولة استجابات 429 دائمًا مع احترام `Retry-After`: إذ ترفضها API قبل أن تنفّذ
  أي شيء. أما أخطاء الشبكة والاستجابات 502/503/504 فلا تُعاد محاولتها إلا للقراءات والكتابات المتماثلة القوى (idempotent)، فلا
  يُرسَل تسجيل أو تجديد مرتين أبدًا. بعد فشل طلب مُحاسَب عليه، افحص `e.outcome_unknown?`.
- **ضبط الوتيرة.** يباعد العميل بين الطلبات ليبقى تحت الحدود المفروضة لكل مفتاح (5 طلبات/ثانية، وبحثان/ثانية،
  واستدعاء واحد للمنطقة كل ثانية). عطّله بـ `pacing: false` إذا كنت تضبط الوتيرة بنفسك.
- **الحصة.** يكشف `client.execute(request).quota` ترويسات الحصة المرنة. عند تجاوز الحد تبطئ API الاستجابات (حتى
  5 ثوانٍ) بدلًا من رفضها؛ وتترك المهلة الافتراضية البالغة 60 ثانية متسعًا لذلك.
- **معرّفات الارتباط.** يحمل كل طلب ترويسة `X-Correlation-ID`. عيّن معرّفك بنفسك لربط استدعاءات API بسجلاتك:
  `DomainNameApi.with_correlation_id(job.id) { ... }` أو `client.call(request, correlation_id: job.id)`.
- **قابلية المراقبة.** يسجّل `logger: Logger.new($stdout)` كل تبادل؛ ويسلّمك `on_trace: ->(event) { ... }`
  كل طلب واستجابة ومحاولة إعادة على شكل `TraceEvent`، لأغراض المقاييس أو الإبلاغ عن الأخطاء. ولا يظهر مفتاح API
  فيها أبدًا؛ أما الأجسام فقد تحتوي على بيانات جهات الاتصال، لذا أخفِها قبل تخزينها.
- **الخيوط (Threads).** يمكن مشاركة العميل بين الخيوط بأمان. أنشئ واحدًا وأعد استخدامه.
- **لا شيء آخر يغادر عمليتك.** لا قياس عن بُعد، ولا خدمات من أطراف ثالثة.

## خيارات العميل

| الخيار                       | التأثير                                                                             |
|------------------------------|-------------------------------------------------------------------------------------|
| `environment: :ote`          | استخدام بيئة الاختبار (الافتراضي `:production`)                                     |
| `base_url: 'https://...'`    | إرسال الطلبات إلى وسيط (proxy) أو خادم اختبار                                       |
| `timeout: 60`                | عدد الثواني لكل محاولة HTTP                                                         |
| `open_timeout: 10`           | عدد الثواني المسموح بها لإنشاء الاتصال                                              |
| `user_agent: 'app/1.0'`      | وضع اسم منتجك قبل User-Agent                                                        |
| `currency: 'TRY'`            | عملة أسعار البحث والكتالوج                                                          |
| `retries: 2`                 | عدد إعادات المحاولة                                                                 |
| `max_retry_wait: 30`         | أطول مدة `Retry-After` ينتظرها العميل                                               |
| `pacing: false`              | تعطيل ضبط الوتيرة من جهة العميل                                                     |
| `read_only: true`            | منع كل طلب ليس قراءة                                                                |
| `logger: Logger.new($stdout)`| تسجيل التبادلات: الطلبات بمستوى debug، وإعادات المحاولة بمستوى warn، والإخفاقات بمستوى error |
| `on_trace: ->(event) {}`     | مراقبة كل طلب واستجابة ومحاولة إعادة                                                |
| `transport: my_transport`    | طبقة HTTP الخاصة بك (وسيط، مجمّع اتصالات، ...): أي كائن يملك `call(request)`        |

يمثّل `DomainNameApi::NetHTTPTransport.new(proxy: 'http://proxy:8080', ca_file: 'corp-ca.pem')` طبقة النقل الافتراضية
مع وسيط (proxy) أو حزمة CA الخاصة بك. لا تُتبَّع إعادة التوجيه أبدًا: إذ تردّ API بالحالة 302 على معرّف موزّع غير معروف
أو موقوف، فيتحوّل ذلك إلى خطأ مصادقة.

## اختبار شيفرتك

مرّر طبقة نقل تردّ كما تردّ API؛ ولا حاجة إلى محاكاة أي شيء آخر:

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

الوسيط `request` هو `DomainNameApi::PreparedRequest` (`http_method` و `url` و `headers` و `body`)، لذا يمكن للبديل
المزيّف أن يتحقق أيضًا مما أُرسل. ويعمل WebMock و VCR أيضًا، لأن طبقة النقل الافتراضية هي `Net::HTTP`.

## الانتقال من v1

الإصدار v2 تصميم جديد: نتائج مُنمَّطة بدل Hash ذات مفاتيح نصية (String)، واستثناءات بدل أغلفة `{'result' => 'ERROR'}`،
وAPI كاملة بدل مجموعة دوال php-dna. يبقى اسم الـ gem هو `domainnameapi`؛ ثبّت
`tag: 'v1.0.1'` للإبقاء على v1 إلى أن تنتقل.

| v1                                                   | v2                                                                       |
|------------------------------------------------------|--------------------------------------------------------------------------|
| `Client.new(id, key, true)`                          | `Client.new(reseller_id: id, api_key: key, environment: :ote)`           |
| `res['result'] == 'OK'`                              | لا يُثار استثناء                                                          |
| `get_reseller_details`, `get_current_balance`        | `account.get` (+ `account.balance('USD')`)                               |
| `check_availability`                                 | `domains.search`, `domains.bulk_search`                                  |
| `get_list`                                           | `domains.list`, `domains.all`                                            |
| `get_tld_list`                                       | `products.tlds`, `products.all_tlds`, `products.tld`                     |
| `get_details`, `get_contacts`, `sync_from_registry`  | `domains.info`                                                           |
| `register_with_contact_info`                         | `domains.register_with_contacts` (أو `contacts.create` + `domains.register`) |
| `renew`, `transfer`, `check_transfer`                | `domains.renew`, `domains.transfer`, `domains.transfer_check`            |
| `modify_name_server`                                 | `domains.set_name_servers`                                               |
| `enable_theft_protection_lock` / `disable_...`       | `domains.lock` / `domains.unlock`                                        |
| `modify_privacy_protection_status`                   | `domains.set_privacy`                                                    |
| `save_contacts`                                      | `domains.update_contacts`, `domains.set_contact_handles`                 |
| `add_child_name_server`, `modify_child_name_server`, `delete_child_name_server` | `domains.add_host`, `domains.update_host`, `domains.delete_host` |
| `get_resource_records`                               | `dns.list`                                                               |
| `add_resource_record`, `add_resource_record_value`   | `dns.add`                                                                |
| `edit_resource_record`, `set_resource_record_set`, `replace_resource_record_value` | `dns.update`                               |
| `delete_resource_record`, `remove_resource_record_value`, `delete_resource_record_set` | `dns.delete` (مرة لكل قيمة)            |
| `apply_resource_records`                             | `dns.apply`                                                              |
| `get_forwarding`, `set_forwarding`, `delete_forwarding` | `domains.forwarding`, `domains.set_forwarding`, `domains.delete_forwarding` |
| `cancel_transfer`, `approve_transfer`, `reject_transfer` | غير موجودة في API المنشورة؛ أرسل [طلبًا من تصميمك](#الطلبات-و-baserequest) إن كان حسابك يتيحها |
| `is_tr_tld`, `validate_contact`                      | `name.end_with?('.tr')`؛ ويجري التحقق مع كل طلب                          |
| `get_request_data`, `get_response_data`, ...         | `on_trace:`, `logger:`, `client.execute(request)`                        |
| القياس عن بُعد (`set_error_reporting_enabled`, Sentry) | أُزيل: لا شيء يغادر عمليتك؛ مرّر أحداث `on_trace` إلى نظام الإبلاغ الخاص بك |
| `set_ssl_verification(false)`                        | `transport: NetHTTPTransport.new(ca_file: ...)` مع حزمة CA الخاصة بك     |

## التطوير

```bash
bundle install
bundle exec rake test   # اختبارات الوحدة؛ لا يلمس أيٌّ منها الشبكة
```

الملف `test/fixtures/openapi.json` هو مستند OpenAPI الخاص بـ API. تفحص الاختبارات كل صنف طلب مقابله (الطريقة،
والمسار، وأسماء الاستعلام، وحقول الجسم، والحقول المطلوبة)، وأسماء JSON لكل نموذج استجابة مقابل مخططات الاستجابة،
وكل قيمة تعداد، وتفشل عندما تكتسب API عملية جديدة بلا صنف طلب لها. لتحديثه:

```bash
curl -fsSL -A "ruby-dna-spec-update" -o test/fixtures/openapi.json https://api.domainresellerapi.com/swagger/v1/swagger.json
bundle exec rake test
```

راجع [AGENTS.md](AGENTS.md) لمعرفة أعراف هذا المستودع.

## الدعم

- توثيق API: <https://www.domainnameapi.com/docs/>
- CLI وخادم MCP: <https://github.com/domainreseller/cli>
- الموقع: <https://www.domainnameapi.com>

## الترخيص

Apache License 2.0. راجع [LICENSE](LICENSE).
