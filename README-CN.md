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

# ruby-dna：Domain Name API 的 Ruby SDK

[![CI](https://github.com/domainreseller/ruby-dna/actions/workflows/ci.yml/badge.svg)](https://github.com/domainreseller/ruby-dna/actions/workflows/ci.yml)
[![License](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](LICENSE)

[Domain Name API](https://www.domainnameapi.com) 经销商 REST API 的 Ruby 客户端：域名搜索、
注册、续费与转入、DNS、DNSSEC、联系人、SSL 证书、主机托管、订单、产品
目录以及账户余额。

- **全部 67 个 API 操作**，分组方式与 [`dna` CLI](https://github.com/domainreseller/cli) 一致：
  `dna domain info` 对应 `client.domains.info`，`dna dns add` 对应 `client.dns.add`。
- **真正的对象，而不是 Hash**：`domain.status.pending_delete?`，`domain.expiration_date` 是 `Time` 对象，
  `availability.available?`，`tld.register_price(1)`。
- **每个操作都是一个请求类**，继承自 `DomainNameApi::BaseRequest`，并在发送任何内容之前先对自身进行校验。
  你也可以用同样的方式编写自己的请求。
- **默认安全**：计费请求绝不会被盲目重试，`read_only: true` 会阻止任何变更，客户端会自行
  控制请求节奏以遵守速率限制，并且可以在多个线程之间安全共享。
- **无依赖。** 需要 Ruby 3.1 或更高版本，仅使用标准库。

```ruby
client = DomainNameApi::Client.new(reseller_id: reseller_id, api_key: api_key, environment: :ote)

a = client.domains.search('example.com')
puts "#{a.domain_name} is available for #{a.price} #{a.currency}" if a.available?
```

## 目录

- [安装](#安装)
- [凭据与环境](#凭据与环境)
- [服务](#服务)
- [用法](#用法)
- [结果、模型与枚举](#结果模型与枚举)
- [请求与 BaseRequest](#请求与-baserequest)
- [错误](#错误)
- [安全与可靠性](#安全与可靠性)
- [客户端选项](#客户端选项)
- [测试你的代码](#测试你的代码)
- [从 v1 迁移](#从-v1-迁移)
- [开发](#开发)

## 安装

> ⬇️ 请使用 [Releases](https://github.com/domainreseller/ruby-dna/releases/latest) 中带标签的版本。绿色的
> **Code → Download ZIP** 按钮下载的是开发分支。

使用 Bundler：

```ruby
# Gemfile
gem 'domainnameapi', git: 'https://github.com/domainreseller/ruby-dna.git', tag: 'v2.1.0'
```

或者安装发布版本附带的 `.gem` 文件：

```bash
gem install ./domainnameapi-2.1.0.gem
```

```ruby
require 'domainnameapi'
```

可运行的程序位于 [examples](examples)：`quickstart`、`register`、`expiring`、`dns`、`ssl` 和
`custom_request`。

```bash
DNA_RESELLER_ID=... DNA_API_KEY=... DNA_ENV=ote ruby examples/quickstart.rb example.com
```

## 凭据与环境

你需要从经销商面板（**API settings**）获取两个 API 凭据。面板的登录信息无法使用。

| 凭据        | 形式                                   |
|-------------|----------------------------------------|
| Reseller ID | `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx` |
| API key     | 一长串密钥字符串                       |

共有两个环境。**请先从 OTE 开始**，即测试环境：它有独立的数据和独立的 API key，
在其中的任何操作都不会产生费用，也不会影响线上域名。

```ruby
# 测试环境 (OTE)
client = DomainNameApi::Client.new(reseller_id: reseller_id, api_key: ote_api_key, environment: :ote)

# 生产环境（默认）：真实注册，真实扣费
client = DomainNameApi::Client.new(reseller_id: reseller_id, api_key: api_key)
```

`environment:` 也接受各类面板中存储的字符串：`'production'`、`'ote'`、`'test'`，以及测试模式标志
（`'true'`、`'1'`、`true`）。`Client.from_env` 读取与 `dna` CLI 相同的变量：

| 变量              | 含义                                                          |
|-------------------|---------------------------------------------------------------|
| `DNA_RESELLER_ID` | 经销商 ID                                                     |
| `DNA_API_KEY`     | 所选环境的 API key                                            |
| `DNA_ENV`         | `production`（默认）或 `ote`                                  |
| `DNA_TEST_MODE`   | `true` 选择 OTE（与其他 DomainNameAPI SDK 一致）              |
| `DNA_BASE_URL`    | 自定义基础 URL，例如代理                                      |

```ruby
client = DomainNameApi::Client.from_env(user_agent: 'my-panel/1.4')
```

密钥或环境错误时，第一次请求就会失败，抛出 `auth?` 为 true 的 `APIError`，其 `hint` 会说明需要检查什么；
`client.account.get` 是最省事的尝试方式。

## 服务

| 服务               | CLI 分组      | 操作                                                                                                                                                              |
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

必需的输入以位置参数传入（`info('example.com')`），其余均为关键字参数
（`renew('example.com', years: 1)`）。带有许多可选输入的操作接受关键字参数或请求对象：
`register(domain_name: ..., years: 1, ...)` 与 `register(DomainNameApi::DomainRegisterRequest.new(...))`
等价。`ssl.purchase` 即 CLI 的 `dna ssl initialize`（`initialize` 在 Ruby 中是保留名）。

## 用法

以下所有代码片段均假定已有一个 `client`。

### 搜索

```ruby
a = client.domains.search('example.com')
a.available?            # a.price, a.currency, a.premium?, a.document_required?, a.reason

client.domains.bulk_search('example.com', 'example.net', 'example.org').each do |r|
  puts "#{r.domain_name} #{r.status} #{r.price}"
end
```

`bulk_search` 会把超过 30 个域名的列表拆分为多个请求。价格使用账户的币种、客户端的
`currency: 'TRY'` 选项，或 `search('example.com', currency: 'USD')` 指定的币种。

### 注册

使用联系人句柄（用 `contacts.create` 创建）：

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
  handles: handle # 一个句柄用于全部四个角色，或 { registrant: 'DNA-1', admin: 'DNA-2', tech: ..., billing: ... }
)
result.status           # result.domain_id, result.expiration_date
```

使用内联联系人：

```ruby
client.domains.register_with_contacts(
  domain_name: 'example.com',
  name_servers: %w[ns1.example.net ns2.example.net],
  contacts: owner # 一个 Contact 用于全部四个角色，或 { registrant: owner, admin: admin, tech: admin, billing: admin }
)
```

联系人可以是 `DomainNameApi::Contact` 对象，也可以是包含相同字段的 Hash。联系人信息在发送前会先整理：
字段会去除首尾空白，国家代码转为大写，电话字段只保留数字
（`'+90 (555) 123-45-67'` 可以直接使用）。部分 TLD 需要注册局属性：用
`client.products.tld('com.tr').required_attributes` 查找，并通过 `tld_attributes:` 传入。

如果 API 有响应但拒绝了请求（`"success": false`），该方法会抛出 `DomainNameApi::OperationError`，
其中带有 API 的消息。

### 续费、转入、恢复

```ruby
check = client.domains.renew_check('example.com', years: 1)   # check.renewable?, check.premium_price
client.domains.renew('example.com', years: 1)

tc = client.domains.transfer_check('example.com', 'auth-code') # tc.transferable?, tc.auth_code_valid?
client.domains.transfer('example.com', auth_code: 'auth-code')
client.domains.transfer_status('example.com').status

client.domains.restore('example.com') # 在赎回期内
```

### 域名详情与域名列表

```ruby
d = client.domains.info('example.com')
d.status                # => #<DomainNameApi::DomainStatus Active (0)>
d.expiration_date       # => 2027-03-15 10:20:30 UTC
d.remaining_days, d.locked?, d.privacy_protection?, d.name_servers, d.auth_code, d.hosts
d.contact(:registrant)&.email

# 单页
page = client.domains.list(limit: 50, sort: 'expirationDate')
page.total_count
page.each { |domain| puts domain.domain_name }

# 所有域名；在遍历过程中按需获取分页
client.domains.all(statuses: [:active]) do |domain|
  puts "#{domain.domain_name} #{domain.expiration_date}"
end
client.domains.all.first(10) # 不带块时返回 Enumerator：只获取一页
```

### 锁定、隐私保护、域名服务器、子域名服务器

```ruby
client.domains.lock('example.com')
client.domains.unlock('example.com')
client.domains.set_privacy('example.com', true)
code = client.domains.update_auth_code('example.com')

client.domains.set_name_servers('example.com', %w[ns1.example.net ns2.example.net])
client.domains.set_name_servers('example.com', %w[ns1.other.net ns2.other.net], dnssec_mode: :disable) # 适用于已启用 DNSSEC 签名的域名

client.domains.add_host('example.com', 'ns1.example.com', '192.0.2.10', '2001:db8::10') # 自动识别 IP 版本
client.domains.update_host('example.com', 'ns1.example.com', ip_addresses: ['192.0.2.20'])
client.domains.delete_host('example.com', 'ns1.example.com')
```

### 域名的联系人

```ruby
client.domains.set_contact_handles('example.com', admin: 'DNA-2', tech: 'DNA-2') # 其他角色保持不变
client.domains.update_contacts('example.com', billing: billing_contact)

details = client.contacts.get('DNA-1')               # 联系人及其验证状态
result = client.contacts.update('DNA-1', contact)    # 更新所有使用该句柄的域名
result.affected_domains.each { |a| puts "#{a.domain_name} #{a.new_handle}" }
client.contacts.resend_verification('DNA-1')          # 没有需要验证的内容时返回 false
```

### DNS 区域

```ruby
client.dns.add('example.com', name: 'www', type: :a, values: '192.0.2.10', ttl: 600)
client.dns.update('example.com', record_name: 'www', type: :a, values: %w[192.0.2.20 192.0.2.21]) # 替换该记录集的所有值
client.dns.delete('example.com', name: 'www', type: :a, value: '192.0.2.20')

client.dns.list('example.com').each do |set|
  puts "#{set.name} #{set.type} #{set.ttl} #{set.values.join(', ')}"
end

client.dns.apply('example.com') # 将域名切换到平台的域名服务器
```

名称可以是相对名称（`'www'`）、根域（`''` 或 `'@'`）或完全限定名称。记录类型可以是任意大小写的符号或字符串
（`:txt` 和 `'txt'` 都会作为 `TXT` 发送）。校验会拦截 API 会拒绝的内容：根域上的
CNAME、不足三个部分的 CAA 值、缺少优先级的 MX 值、带有 IPv6 地址的 A 记录。测试
环境对每个区域调用都返回 HTTP 500，因此区域相关代码只能在生产环境中试用。

### DNSSEC

```ruby
results = client.dnssec.add('example.com', '2371 13 2 1F987CC6583E92DF0890718C42...') # 与你的 DNS 提供商显示的格式一致
info = client.dnssec.get('example.com') # info.status.signed?, info.ds_records
client.dnssec.disable('example.com')
```

`DomainNameApi::DS.parse` 可读取展示格式（presentation format）以及完整的区域文件行；也可以使用 `DS.new(key_tag: ...,
algorithm: :ecdsa_p256_sha256, digest_type: :sha256, digest: '...')`。

### URL 转发

```ruby
client.domains.set_forwarding('example.com', 'https://www.example.org')              # 301 重定向
client.domains.set_forwarding('example.com', 'https://www.example.org', type: :frame) # 隐藏式转发（masked）
f = client.domains.forwarding('example.com') # 域名没有转发时为 nil
client.domains.delete_forwarding('example.com')
```

### 注册局文档 (.tr)

```ruby
doc = DomainNameApi::DocumentUpload.from_file(:identity_card, 'id.pdf')
client.domains.upload_documents('example.com.tr', doc)
client.domains.documents('example.com.tr').each { |d| puts "#{d.name} #{d.status}" }
```

文件会自动进行 base64 编码；上传前会检查格式（PDF、JPG、PNG、DOC、DOCX、ODT）和大小（每个文件 10 MB，每次
请求 50 MB）。

### SSL 证书

```ruby
csr = client.ssl.generate_csr(domain_name: 'example.com', country: 'TR', state: 'Istanbul', locality: 'Istanbul',
                              organization: 'Example Ltd', organization_unit: 'IT')
# 从余额中扣费（CLI：dna ssl initialize）
order = client.ssl.purchase('example.com', package_code: 'PositiveSSL')
id = order.certificate_id # 请保存：之后的每次调用都需要它
client.ssl.configure(certificate_id: id, csr: csr.csr, approver_mail: 'admin@example.com',
                     authentication_type: :email, web_server_type: :apache, contact: ssl_contact)
client.ssl.status(id).issued? # 轮询直到返回 true
File.write('example.com.crt', client.ssl.content(id).chain)
```

一个域名可以有多张证书，因此已有证书通过其 `certificate_id`（一个 GUID）来指定，而不是域名：
`purchase` 和 `renew` 会返回它，`list` 可以查到它。在需要 ID 的位置传入域名，会在发送任何内容之前抛出
`InputError`。请在购买或续费后的 15 天内完成证书配置。

```ruby
client.ssl.list(domain_name: 'example.com').each { |c| puts "#{c.certificate_id} #{c.status}" } # 最新的在前
client.ssl.all { |c| puts "#{c.domain_name} #{c.subscription_expires_at}" } # 所有证书，逐页获取

client.ssl.approvers(certificate_id: id)                                      # 针对已有证书
client.ssl.approvers(domain_name: 'example.com', package_code: 'PositiveSSL') # 购买之前

renewal = client.ssl.renew(id) # 从余额中扣费；订阅到期前 30 天起可续费
client.ssl.configure(certificate_id: renewal.certificate_id, csr: new_csr.csr, approver_mail: 'admin@example.com',
                     authentication_type: :email, web_server_type: :apache, contact: ssl_contact)
```

续费时请调用 `renew`，然后对它返回的新证书调用 `configure`。不要再次调用 `purchase`：
那是一笔按购买价格计费的、互不相关的新订单，旧证书也永远不会变为 `Renewed` 状态。

### 主机托管

```ruby
client.hosting.packages.each { |p| puts p.service_plans.map(&:service_plan) }
created = client.hosting.create('example.com', service_plan: 'Linux-Starter') # 从余额中扣费

st = client.hosting.wait(created.service_id, timeout: 30 * 60) # 轮询直到激活
puts st.panel_address, st.username, st.password
```

对于仍在开通中的主机托管，切勿再次调用 `create`：这会重复扣费。

### 余额、价格与订单

```ruby
account = client.account.get
account.balance('USD')
profile = client.account.profile # profile.company_name, profile.account_currency, profile.status.active?

client.account.all_transactions(from: Date.new(2026, 11, 1)) do |tx|
  puts "#{tx.creation_time} #{tx.type} #{tx.change}"
end

tld = client.products.tld('com.tr')
tld&.register_price(1)&.to_s   # => "12.50 USD"

client.products.info('com', order_type: :renew, years: 2) # .com 续费 2 年的价格
client.orders.get('ORDER-CODE')
```

## 结果、模型与枚举

每个结果都是一个 `DomainNameApi::Model`：snake_case 形式的读取方法、用于标志的 `?` 谓词方法、表示日期的 `Time` 对象，
以及嵌套的模型和列表。

```ruby
d = client.domains.info('example.com')
d.locked?                 # 也可用 d.locked
d.hosts.first.ip_addresses.first.address
d.to_h                    # 键为 snake_case 的普通 Hash
d.raw                     # API 发送的原始 JSON 对象，用于本 gem 未建模的字段
```

数值和固定字符串类型的值都是枚举（`DomainStatus`、`RecordType`、`ContactType`、`DocumentType` 等）：

```ruby
d.status.pending_delete?                       # 每个成员对应一个谓词方法
d.status == DomainNameApi::DomainStatus::ACTIVE
d.status == :active                            # 也可以与符号、名称和数字比较
d.status.to_s                                  # => "Active"
d.status.to_i                                  # => 0
DomainNameApi::DomainStatus.members            # 全部成员
```

请求可接受枚举、符号、任意大小写的名称或数字：`statuses: [:active, 'PendingDelete', 7]`。

解码是宽容的：不带时区的日期、`null`、用 `[]` 代替 `{}`、以字符串形式发送的数字、任意大小写的
角色（`"registrant"`、`"ADMINISTRATIVE"`）以及本 gem 尚不认识的值，都能正常解码，而不会导致
调用失败（对于最后一种情况，`status.known?` 为 false）。

## 请求与 BaseRequest

每个 API 操作都是一个请求类：`DomainInfoRequest`、`DNSAddRequest`、`SSLConfigureRequest` 等，按照
CLI 命令命名（`dna domain renew` 对应 `DomainRenewRequest`）。它们都继承自
`DomainNameApi::BaseRequest`，由它提供底层支撑：类级别的 `endpoint` 和 `attribute` DSL、关键字参数
初始化、校验辅助方法、路径模板以及查询参数/请求体构建器。列表请求继承自
`PagedRequest`，它增加了 `skip`、`limit` 和 `sort`。本 gem 中的一个请求如下所示：

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

服务方法会为你构建这些请求。`client.call` 可以发送任何请求，包括你自己的类，例如
只读取所需的字段，或调用本 gem 尚未封装的端点：

```ruby
class Expiry < DomainNameApi::Model
  field :expiration_date, :time
  field :remaining_days, :integer, from: 'remainingDay'
end

class ExpiryRequest < DomainNameApi::BaseRequest
  endpoint :get, '/api/v1/domains/info', safety: :read
  returns Expiry            # 省略则返回解析后的 JSON
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

| 可覆盖方法     | 默认值          | 用途                                                                        |
|----------------|-----------------|-----------------------------------------------------------------------------|
| `query`        | `nil`           | 一个 `Query`（`params.string(...)`）、一个 Hash 或由键值对组成的 Array      |
| `body`         | `nil`           | 使用 API 字段名的 Hash 或 Array；枚举、模型和时间会自动转换                 |
| `validate`     | 无需检查        | 用 `required`、`check`、`between`、`max_length`、`enum` 报告问题            |
| `decode(data)` | 使用 `returns`  | 将解析后的 JSON 转换为你的结果                                              |

路径占位符会从属性中填充并进行转义：`endpoint :get, '/api/v1/contacts/{handle}'`。

你的请求享有内置请求的全部能力：凭据、重试、节奏控制、错误规范化、
关联 ID、追踪以及只读强制。`client.execute(request)` 返回完整的 `Response`
（状态码、响应头、原始响应体、关联 ID、配额、尝试次数），解码后的结果位于 `value` 中。
`client.prepare(request)` 会校验并构建出确切的 HTTP 请求但不发送，便于在计费请求发出之前
记录或审查（API key 在 `inspect` 中会被遮蔽）。

## 错误

| 错误                             | 触发时机                                                   | 常用方法                                                                       |
|----------------------------------|------------------------------------------------------------|--------------------------------------------------------------------------------|
| `DomainNameApi::InputError`      | 校验拒绝了请求；**没有发送任何内容**                       | `request`, `fields`                                                            |
| `DomainNameApi::APIError`        | API 返回了非 2xx 状态码                                    | `status`, `code`, `api_message`, `details`, `fields`, `data`, `correlation_id`, `hint` |
| `DomainNameApi::OperationError`  | API 返回 2xx，但带有 `"success": false`                    | `code`, `api_message`, `correlation_id`                                        |
| `DomainNameApi::NetworkError`    | 请求未完成（DNS、TLS、超时、连接重置）                     | `original`, `timeout?`                                                         |
| `DomainNameApi::ReadOnlyError`   | 只读客户端阻止了变更；没有发送任何内容                     | `safety`                                                                       |

它们都继承自 `DomainNameApi::Error`，可回答常见问题：`kind`（`:auth`、
`:not_found`、`:validation`、`:rejected`、`:conflict`、`:rate_limited`、`:server`、`:network`、`:invalid_input`、
`:read_only`）、`not_found?`、`auth?`、`rate_limited?`、`insufficient_balance?`、`outcome_unknown?`、
`retryable?` 和 `code?(code)`。

```ruby
begin
  client.domains.renew('example.com', years: 1)
rescue DomainNameApi::Error => e
  if e.outcome_unknown?
    # 续费可能已经成功。再次尝试之前先检查该域名。
  elsif e.insufficient_balance?
  elsif e.not_found?
  elsif e.code?(DomainNameApi::ErrorCode::PRIVACY_NOT_SUPPORTED)
  elsif e.is_a?(DomainNameApi::APIError)
    logger.error("#{e.code} #{e.api_message} #{e.hint} #{e.correlation_id}")
  end
end
```

请根据 `code` 而不是消息来分支处理：消息是本地化的。API 错误码形如
`Dna.DomainService:Domain:10007`；常见的错误码是 `DomainNameApi::ErrorCode` 中的常量，其余的参见
[错误参考](https://www.domainnameapi.com/docs/reference/errors.md)。联系支持团队时请提供
`correlation_id`。

## 安全与可靠性

- **安全级别。** 每个请求都属于 `:read`、`:write`、`:destructive` 或 `:billable`（`request.safety`、
  `request.billable?`）。部分 POST 和 PUT 请求实际上是读取操作（`DomainSearchRequest`、`SSLStatusRequest`）。
- **只读模式。** `read_only: true` 会阻止所有非读取操作，适用于报表任务，也适合
  安全地探索生产环境。
- **重试。** 429 响应总是会被重试，并遵循 `Retry-After`：API 在处理任何内容之前就拒绝了这类请求。
  网络错误和 502/503/504 仅对读取操作和幂等的写入操作重试，因此注册
  或续费绝不会被发送两次。计费请求失败后，请检查 `e.outcome_unknown?`。
- **节奏控制。** 客户端会控制请求间隔，使其低于每个密钥的限制（每秒 5 个请求、每秒 2 次搜索、
  每秒一次区域调用）。如果你自行控制节奏，可用 `pacing: false` 将其关闭。
- **配额。** `client.execute(request).quota` 暴露软配额响应头。超出限制时，API 会放慢响应（最多
  5 秒）而不是拒绝请求；默认的 60 秒超时为此留有余地。
- **关联 ID。** 每个请求都带有 `X-Correlation-ID`。设置你自己的值，以便将 API 调用与你的日志关联起来：
  `DomainNameApi.with_correlation_id(job.id) { ... }` 或 `client.call(request, correlation_id: job.id)`。
- **可观测性。** `logger: Logger.new($stdout)` 会记录每次交互；`on_trace: ->(event) { ... }` 会把
  每个请求、响应和重试以 `TraceEvent` 的形式交给你，用于指标或错误上报。其中绝不包含 API key；
  但请求体和响应体可能含有联系人数据，因此存储前请先做脱敏处理。
- **线程。** 客户端可以在多个线程之间安全共享。创建一个并重复使用即可。
- **不会有其他任何数据离开你的进程。** 没有遥测，也没有第三方服务。

## 客户端选项

| 选项                         | 作用                                                                                |
|------------------------------|-------------------------------------------------------------------------------------|
| `environment: :ote`          | 使用测试环境（默认为 `:production`）                                                |
| `base_url: 'https://...'`    | 将请求发送到代理或测试服务器                                                        |
| `timeout: 60`                | 每次 HTTP 尝试的超时秒数                                                            |
| `open_timeout: 10`           | 建立连接的超时秒数                                                                  |
| `user_agent: 'app/1.0'`      | 将你的产品名放在 User-Agent 前面                                                    |
| `currency: 'TRY'`            | 搜索价格与目录价格的币种                                                            |
| `retries: 2`                 | 重试次数                                                                            |
| `max_retry_wait: 30`         | 客户端最多等待的 `Retry-After` 时长                                                 |
| `pacing: false`              | 关闭客户端节奏控制                                                                  |
| `read_only: true`            | 阻止所有非读取请求                                                                  |
| `logger: Logger.new($stdout)`| 记录交互：请求使用 debug 级别，重试使用 warn 级别，失败使用 error 级别              |
| `on_trace: ->(event) {}`     | 观察每个请求、响应和重试                                                            |
| `transport: my_transport`    | 你自己的 HTTP 层（代理、连接池等）：任何带有 `call(request)` 方法的对象             |

`DomainNameApi::NetHTTPTransport.new(proxy: 'http://proxy:8080', ca_file: 'corp-ca.pem')` 即带有代理或你自己的
CA 证书包的默认传输层。绝不会跟随重定向：对于未知或已暂停的经销商 ID，API 会返回 302，
这会被转换为认证错误。

## 测试你的代码

传入一个像 API 一样作出响应的传输层；其他部分都不需要 mock：

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

`request` 是一个 `DomainNameApi::PreparedRequest`（`http_method`、`url`、`headers`、`body`），因此这个假实现
还可以断言发送了什么内容。WebMock 和 VCR 也可以使用，因为默认传输层是 `Net::HTTP`。

## 从 v1 迁移

v2 是全新的设计：用类型化的结果取代以 String 为键的 Hash，用异常取代 `{'result' => 'ERROR'}`
信封，并提供完整的 API，而不再只是 php-dna 的方法集合。gem 名称仍为 `domainnameapi`；在你切换之前，可固定
`tag: 'v1.0.1'` 以继续使用 v1。

| v1                                                   | v2                                                                       |
|------------------------------------------------------|--------------------------------------------------------------------------|
| `Client.new(id, key, true)`                          | `Client.new(reseller_id: id, api_key: key, environment: :ote)`           |
| `res['result'] == 'OK'`                              | 不抛出异常                                                               |
| `get_reseller_details`, `get_current_balance`        | `account.get` (+ `account.balance('USD')`)                               |
| `check_availability`                                 | `domains.search`, `domains.bulk_search`                                  |
| `get_list`                                           | `domains.list`, `domains.all`                                            |
| `get_tld_list`                                       | `products.tlds`, `products.all_tlds`, `products.tld`                     |
| `get_details`, `get_contacts`, `sync_from_registry`  | `domains.info`                                                           |
| `register_with_contact_info`                         | `domains.register_with_contacts`（或 `contacts.create` + `domains.register`） |
| `renew`, `transfer`, `check_transfer`                | `domains.renew`, `domains.transfer`, `domains.transfer_check`            |
| `modify_name_server`                                 | `domains.set_name_servers`                                               |
| `enable_theft_protection_lock` / `disable_...`       | `domains.lock` / `domains.unlock`                                        |
| `modify_privacy_protection_status`                   | `domains.set_privacy`                                                    |
| `save_contacts`                                      | `domains.update_contacts`, `domains.set_contact_handles`                 |
| `add_child_name_server`, `modify_child_name_server`, `delete_child_name_server` | `domains.add_host`, `domains.update_host`, `domains.delete_host` |
| `get_resource_records`                               | `dns.list`                                                               |
| `add_resource_record`, `add_resource_record_value`   | `dns.add`                                                                |
| `edit_resource_record`, `set_resource_record_set`, `replace_resource_record_value` | `dns.update`                               |
| `delete_resource_record`, `remove_resource_record_value`, `delete_resource_record_set` | `dns.delete`（每个值调用一次）         |
| `apply_resource_records`                             | `dns.apply`                                                              |
| `get_forwarding`, `set_forwarding`, `delete_forwarding` | `domains.forwarding`, `domains.set_forwarding`, `domains.delete_forwarding` |
| `cancel_transfer`, `approve_transfer`, `reject_transfer` | 不在已发布的 API 中；如果你的账户支持这些操作，请发送[你自己的请求](#请求与-baserequest) |
| `is_tr_tld`, `validate_contact`                      | `name.end_with?('.tr')`；每个请求都会执行校验                            |
| `get_request_data`, `get_response_data`, ...         | `on_trace:`, `logger:`, `client.execute(request)`                        |
| 遥测 (`set_error_reporting_enabled`, Sentry)         | 已移除：不会有任何数据离开你的进程；请将 `on_trace` 事件转发到你自己的上报系统 |
| `set_ssl_verification(false)`                        | `transport: NetHTTPTransport.new(ca_file: ...)` 搭配你自己的 CA 证书包   |

## 开发

```bash
bundle install
bundle exec rake test   # 单元测试；均不访问网络
```

`test/fixtures/openapi.json` 是 API 的 OpenAPI 文档。测试会对照它检查每个请求类（方法、路径、
查询参数名、请求体字段、必填字段）、每个响应模型的 JSON 字段名是否符合响应
schema，以及每个枚举值；当 API 新增了没有对应请求类的操作时，测试会失败。更新方法：

```bash
curl -fsSL -A "ruby-dna-spec-update" -o test/fixtures/openapi.json https://api.domainresellerapi.com/swagger/v1/swagger.json
bundle exec rake test
```

本仓库的约定请参见 [AGENTS.md](AGENTS.md)。

## 支持

- API 文档：<https://www.domainnameapi.com/docs/>
- CLI 与 MCP 服务器：<https://github.com/domainreseller/cli>
- 网站：<https://www.domainnameapi.com>

## 许可证

Apache License 2.0。参见 [LICENSE](LICENSE)。
