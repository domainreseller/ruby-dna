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

# ruby-dna — 适用于 Ruby 的 DomainNameAPI 客户端

通过 DomainNameAPI REST API 注册、续费和转移域名，管理联系人、名称服务器、子名称服务器、DNS 区域以及 URL 转发。`ruby-dna` 是 [php-dna](https://github.com/domainreseller/php-dna) 的忠实移植版本：方法相同、实际发出的请求相同、返回值也相同，并已通过 php-dna 的一致性测试用例（conformance fixtures）验证。

## 📦 下载 — 请务必使用 Releases！

⬇️ **在此获取最新的经过测试的版本：https://github.com/domainreseller/ruby-dna/releases/latest**

> ⚠️ 请**不要**使用绿色的 **Code → Download ZIP** 按钮 — 它下载的是原始的开发分支。Release 包经过版本管理和测试，可直接用于生产环境。

## 安装和集成指南

### 最低要求

- Ruby 2.7 或更高版本（推荐 3.3+）
- 无运行时依赖：仅使用标准库（`net/http`、`json`、`openssl`）。

### A) Bundler

```ruby
# Gemfile
gem 'domainnameapi', git: 'https://github.com/domainreseller/ruby-dna.git', tag: 'v1.0.0'
```

```bash
bundle install
```

### B) 使用 Release 中的 gem 文件

从[最新 Release](https://github.com/domainreseller/ruby-dna/releases/latest) 下载 `domainnameapi-1.0.0.gem`，然后执行：

```bash
gem install ./domainnameapi-1.0.0.gem
```

### C) 手动使用

下载 Release 压缩包，将 `lib` 文件夹复制到您的项目中，并查看 [examples](examples) 文件夹中的示例：

```ruby
$LOAD_PATH.unshift File.expand_path('lib', __dir__)
require 'domainnameapi'
```

## 🔑 API 凭据 — Reseller ID 与 API Key

本库通过 DomainNameAPI REST API 通信，只需向构造函数传入两项凭据：

| 参数 | 值 |
|---|---|
| 第一个 | Reseller ID — 形如 `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx` 的 UUID |
| 第二个 | API Key |

> 💡 您可以在 DomainNameAPI 面板的 **API 设置** 中找到您的 **Reseller ID** 和 **API Key**。
> ⚠️ 这些是 **API 凭据** — 面板登录信息在此**无法使用**。

## 快速开始

```ruby
require 'domainnameapi'

reseller_id = 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx'
api_key     = 'your-api-key'

# 正式环境
dna = DomainNameApi::Client.new(reseller_id, api_key)

# 测试（OTE）环境
dna = DomainNameApi::Client.new(reseller_id, api_key, true)

result = dna.get_details('example.com')
if result['result'] == 'OK'
  puts result['data']['Dates']['Expiration']
else
  puts "#{result['error']['Code']}: #{result['error']['Message']}"
end
```

方法名是 php-dna 方法名的 snake_case 形式（`getDetails` → `get_details`，`registerWithContactInfo` → `register_with_contact_info`），参数顺序和默认值保持不变。返回结果是使用 **String 键**的普通 Ruby Hash 和 Array，结构与 php-dna 返回的完全一致（包括 `'LockStatus' => 'true'` 这样的字符串标志，以及 `'11.9900'` 这样的格式化价格）。凭据会被去除首尾空白；测试模式标志也接受字符串：`"true"`、`"1"`、`"on"` 和 `"yes"` 表示测试模式，其他任何值都表示正式环境。

## 错误处理

方法在遇到 API 或网络问题时绝不会抛出异常。调用失败时会返回一个错误信封（error envelope）：

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

- 对于网关错误，`Code` 为 `API_<HTTP 状态码>`（`API_400`、`API_401`、`API_429`、`API_500` 等）。`301`/`302` 响应表示凭据错误（`Invalid API credentials`）。
- 空的错误响应体会被转换为可读的消息，例如 `HTTP 429 - Too Many Requests`。
- 字段校验错误会被展平到 `Details` 中，例如 `Admin PostalCode - 'PostalCode' is required`。
- 网络故障一律视为错误，绝不会作为空的成功结果返回。超时的消息为 `Could not reach the DomainNameAPI service: the connection timed out. (...)`；其他传输层故障的消息为 `Curl error during request: ...`。其错误代码沿用 curl 的编号（`API_28` 超时、`API_6` DNS、`API_7` 连接被拒绝、`API_35`/`API_60` TLS）；`get_parsed_response_data['Code']` 中保存的是 `CURL_<n>`。
- `get_current_balance` 使用自己的信封格式：`'OperationResult' => 'FAILED'`，并带有 `ErrorCode` 和 `OperationMessage`。
- `check_availability` 成功时返回普通列表，失败时返回错误信封。

只有编程错误才会抛出异常（例如，向 `set_resource_record_set` 传入的 `contents` 不是列表时会抛出 `TypeError`）。

每次调用的超时时间为 30 秒，连接超时为 10 秒。对 DNS 区域端点的调用之间至少间隔一秒，因为网关会对突发请求返回 `HTTP 429`。

### 诊断

```ruby
dna.get_request_data         # 上一次调用的 { 'url' => ..., 'method' => 'GET', 'payload' => {...} }
dna.get_response_data        # 上一次解码后的响应体（或 { 'raw_response' => body }）
dna.get_response_headers     # { 'url', 'http_code', 'headers', 'total_time' }
dna.get_parsed_response_data # 上一次解析后的响应体，或上一次的错误 { 'Code', 'Message', 'Details' }
dna.get_last_function        # 例如 'request:GET domains/info'
dna.get_service_url          # https://api.domainresellerapi.com/api/v1
dna.set_service_url('https://ote.domainresellerapi.com/api/v1')
```

## 测试模式

将 `true` 作为构造函数的第三个参数传入，即可使用 OTE 测试网关（`https://ote.domainresellerapi.com/api/v1`）。正式调用发送至 `https://api.domainresellerapi.com/api/v1`。测试模式使用单独的测试凭据。

## 错误报告（遥测）

当 API 调用失败时，本库可以向 DomainNameAPI 自己的错误跟踪系统（Sentry）发送一份错误报告。成功调用中会随机抽取一小部分（4%，另外所有耗时超过 1 秒的调用）作为性能记录发送。这有助于 DomainNameAPI 发现并修复问题。错误报告**默认开启**。

> ℹ️ 在 1.0.0 版本中，ruby-dna 的 Sentry 项目尚未创建，因此内置的 DSN 为空，**不会发送任何数据**。待某个 Release 内置 DSN 之后才会开始发送报告。可以通过 `DomainNameApi::Client.new(id, key, false, sentry_dsn: '...')` 显式设置 DSN。

**发送的内容：**

- 错误代码和消息
- 所调用端点的路径和 HTTP 方法
- 调用耗时
- 库名称（`DomainNameAPI-Ruby`）、库版本和 Ruby 版本
- 经销商 ID（Reseller ID）和域名
- 服务器的公网 IP 地址（在后台通过 `api.ipify.org` 获取）
- 运行该进程的操作系统用户名
- API 请求和响应，包括域名的联系人信息；仅凭据会被屏蔽——EPP/授权码、API 密钥、密码和令牌会被替换为 `***`

**绝不发送的内容：** 可读形式的 EPP/授权码、API 密钥、密码或令牌；堆栈跟踪中的方法调用参数。

预期内的高频错误（域名未找到、余额不足、凭据无效等）不会被报告。报告由后台线程以较短的超时时间发送：它们绝不会拖慢或中断您的调用。

**用途与保留期限：** 这些数据仅用于使用情况统计和问题的早期诊断，在 DomainNameAPI 自己的 Sentry 服务器上保存 30 天，之后自动删除。

**如何关闭：**

```ruby
dna = DomainNameApi::Client.new(reseller_id, api_key)
dna.set_error_reporting_enabled(false)
```

**精简模式**仅发送错误代码和消息、端点、耗时、版本信息以及 Reseller ID——不包含请求/响应数据、域名、服务器 IP 或用户名：

```ruby
dna.set_telemetry_minimal(true)
```

> 🔒 **安全：** TLS 证书验证默认开启。在 CA 证书包过旧的服务器上，可以通过 `dna.set_ssl_verification(false)` 关闭——不建议这样做；更新 CA 证书包才是更好的解决办法。

## 使用方法

以下所有示例均假定 `dna = DomainNameApi::Client.new(reseller_id, api_key)`。每个方法的可运行脚本都位于 [examples](examples) 中。

### 账户

#### 经销商详细信息

```ruby
dna.get_reseller_details
```

<details>
<summary>示例输出</summary>

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

#### 当前余额

`get_current_balance(currency = 'USD')` — 可选 `'USD'`、`'TRY'`、`'EUR'` 或 `'GBP'`。

```ruby
dna.get_current_balance('USD')
```

<details>
<summary>示例输出</summary>

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

### 查询与列表

#### 域名可用性检查

`check_availability(domains, extensions, period, command = 'create')`

```ruby
dna.check_availability(['hello', 'world123x0'], ['com', 'net'], 1, 'create')
```

<details>
<summary>示例输出</summary>

```ruby
[
  { 'TLD' => 'com', 'DomainName' => 'hello', 'Status' => 'notavailable', 'Command' => 'create',
    'Period' => 1, 'IsFee' => false, 'Price' => '10.8100', 'Currency' => 'USD', 'Reason' => 'Domain exists' },
  { 'TLD' => 'com', 'DomainName' => 'world123x0', 'Status' => 'available', 'Command' => 'create',
    'Period' => 1, 'IsFee' => false, 'Price' => '10.8100', 'Currency' => 'USD', 'Reason' => nil }
]
```

</details>

#### 域名列表

`get_list(extra_parameters = {})` — 支持 `PageNumber`（从 0 开始）、`PageSize`、`OrderColumn`、`OrderDirection` 以及网关自身的过滤条件（例如 `DomainName`）。

```ruby
dna.get_list('OrderColumn' => 'Id', 'OrderDirection' => 'ASC', 'PageNumber' => 0, 'PageSize' => 1000)
```

<details>
<summary>示例输出</summary>

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

#### TLD 列表

`get_tld_list(count = 20)`

```ruby
dna.get_tld_list(100)
```

<details>
<summary>示例输出</summary>

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

### 域名

#### 域名注册

`register_with_contact_info(domain, period, contacts, name_servers = [], epp_lock = true, privacy_lock = false, additional_attributes = {})`

联系人使用 php-dna 的键名。下面的扁平结构以及 `get_contacts` 返回的嵌套结构（`Address => { Line1, City, ... }`、`Phone => { Phone => { Number, CountryCode } }`）均可接受；缺失的字段会被自动补全，姓名、电话和国家也会被规范化（参见 `validate_contact`）。如果未提供名称服务器，则使用 `ns1.domainnameapi.com` 和 `ns2.domainnameapi.com`。

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

对于 `.tr` 域名，请将 TRABIS 属性作为第 7 个参数传入：

```ruby
# 个人所有者
{ 'TRABISDOMAINCATEGORY' => 1, 'TRABISCITIZIENID' => '12345678901' }
# 公司所有者
{ 'TRABISDOMAINCATEGORY' => 0, 'TRABISTAXOFFICE' => 'Istanbul VD', 'TRABISTAXNUMBER' => '1234567890' }
```

类别会以 `Owner`/`Corporate` 的形式发送，`TRABISCITIZIENID` 会以 `TRABISCITIZENID` 的形式发送，而旧版键（`TRABISNAMESURNAME`、`TRABISCOUNTRYID`、`TRABISCITYID` 等）会被丢弃，因为网关现在会从联系人信息中读取这些数据。

<details>
<summary>示例输出</summary>

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

#### 域名续费

```ruby
dna.renew('example.com', 1)
```

<details>
<summary>示例输出</summary>

```ruby
{ 'result' => 'OK', 'data' => { 'ExpirationDate' => '2025-03-15T10:00:00' } }
```

</details>

#### 域名详细信息

```ruby
dna.get_details('example.com')
```

<details>
<summary>示例输出</summary>

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

#### 从注册局同步

调用方式和输出与 `get_details` 相同。

```ruby
dna.sync_from_registry('example.com')
```

#### 修改名称服务器

可传入列表或 Hash（使用其中的值）。

```ruby
dna.modify_name_server('example.com', ['ns1.example.com', 'ns2.example.com'])
```

<details>
<summary>示例输出</summary>

```ruby
{ 'result' => 'OK', 'data' => { 'NameServers' => ['ns1.example.com', 'ns2.example.com'] } }
```

</details>

#### 启用域名锁定

```ruby
dna.enable_theft_protection_lock('example.com')
```

<details>
<summary>示例输出</summary>

```ruby
{ 'result' => 'OK', 'data' => { 'LockStatus' => true } }
```

</details>

#### 禁用域名锁定

```ruby
dna.disable_theft_protection_lock('example.com')
```

<details>
<summary>示例输出</summary>

```ruby
{ 'result' => 'OK', 'data' => { 'LockStatus' => false } }
```

</details>

#### 修改域名隐私保护

`modify_privacy_protection_status(domain, status, reason = 'Owner request')` — 仅当 `status` 严格等于 `true` 时才会开启隐私保护。

```ruby
dna.modify_privacy_protection_status('example.com', true, 'Owner request')
```

<details>
<summary>示例输出</summary>

```ruby
{ 'data' => { 'PrivacyProtectionStatus' => true }, 'result' => 'OK' }
```

</details>

#### 获取域名联系人

```ruby
dna.get_contacts('example.com')
```

<details>
<summary>示例输出</summary>

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

#### 保存域名联系人

```ruby
dna.save_contacts('example.com', {
  'Administrative' => contact,
  'Billing'        => contact,
  'Technical'      => contact,
  'Registrant'     => contact
})
```

<details>
<summary>示例输出</summary>

```ruby
{ 'result' => 'OK', 'data' => { 'contacts' => {} } }
```

</details>

<hr style="border: 4px solid #000; border-style: dashed;">

### 子名称服务器

#### 添加子名称服务器

```ruby
dna.add_child_name_server('example.com', 'ns1.example.com', '1.2.3.4')
```

<details>
<summary>示例输出</summary>

```ruby
{ 'result' => 'OK', 'data' => { 'NameServer' => 'ns1.example.com', 'IPAdresses' => ['1.2.3.4'] } }
```

</details>

#### 删除子名称服务器

```ruby
dna.delete_child_name_server('example.com', 'ns1.example.com')
```

<details>
<summary>示例输出</summary>

```ruby
{ 'result' => 'OK', 'data' => { 'NameServer' => 'ns1.example.com' } }
```

</details>

#### 更新子名称服务器

```ruby
dna.modify_child_name_server('example.com', 'ns1.example.com', '1.2.3.5')
```

<details>
<summary>示例输出</summary>

```ruby
{ 'result' => 'OK', 'data' => { 'NameServer' => 'ns1.example.com', 'IPAdresses' => ['1.2.3.5'] } }
```

</details>

<hr style="border: 4px solid #000; border-style: dashed;">

### 转移

#### 域名转移

`transfer(domain, epp_code, period, contacts = {})` — 与 php-dna 的外观接口（facade）一样，转移请求不携带联系人信息发送（网关会保留当前的联系人）。

```ruby
dna.transfer('example.com', 'Xy9#mK2$', 3)
```

<details>
<summary>示例输出</summary>

```ruby
{
  'data' => { 'ID' => 0, 'Status' => 'WaitingForIncomingTransfer', 'DomainName' => 'example.com', ... },
  'result' => 'OK'
}
```

</details>

#### 检查转移

仅当注册局报告该域名可转移时，`result` 才为 `'OK'`。

```ruby
dna.check_transfer('example.com', 'Xy9#mK2$')
```

<details>
<summary>示例输出</summary>

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

#### 取消、批准或拒绝转移

`cancel_transfer` 用于取消待处理的转入请求；`approve_transfer` 和 `reject_transfer` 用于答复待处理的转出请求。

```ruby
dna.cancel_transfer('example.com')
dna.approve_transfer('example.com')
dna.reject_transfer('example.com')
```

<details>
<summary>示例输出</summary>

```ruby
{ 'result' => 'OK', 'data' => { 'DomainName' => 'example.com', 'Status' => 'Cancelled' } } # 'Approved' / 'Rejected'
```

</details>

<hr style="border: 4px solid #000; border-style: dashed;">

### DNS 区域

支持的记录类型：`A`、`AAAA`、`ALIAS`、`CAA`、`CNAME`、`DS`、`MX`、`NAPTR`、`PTR`、`SRV`、`TLSA`、`TXT`（其他类型会在发出任何调用之前被拒绝）。名称使用相对形式（`'www'`）；`''` 或 `'@'` 表示区域顶点（apex），而 `'www.example.com'` 这样的完整名称会被缩减为其标签部分。更改会立即生效；如需暂存多项更改，请传入 `apply = false`，最后调用一次 `apply_resource_records`。TTL 范围为 1–86400 秒。

网关将“名称 + 类型”作为一个**集合（set）**存储：写入一个集合会替换其中的所有值，而删除其中一个值会删除整个集合。`*_resource_record_value` 系列方法会替您完成“读取-合并-写入”的过程。

#### 列出记录

```ruby
dna.get_resource_records('example.com')
```

<details>
<summary>示例输出</summary>

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

#### 替换记录集合

`set_resource_record_set(domain, name, type, contents, ttl = 3600, apply = true)` — 传入空列表会删除该集合。

```ruby
dna.set_resource_record_set('example.com', 'www', 'A', ['192.0.2.10', '192.0.2.11'], 3600)
```

<details>
<summary>示例输出</summary>

```ruby
{ 'result' => 'OK', 'data' => { 'Name' => 'www', 'Type' => 'A', 'TTL' => 3600, 'Contents' => ['192.0.2.10', '192.0.2.11'] } }
```

</details>

#### 添加、替换或删除单个值

`add_resource_record_value(domain, name, type, value, ttl = nil, apply = true)`、`replace_resource_record_value(domain, name, type, old_value, new_value, ttl = nil, apply = true)`、`remove_resource_record_value(domain, name, type, value, apply = true)`。TTL 为 `nil` 时保留该集合当前的 TTL；添加一个已存在的值或删除一个不存在的值不会执行任何操作（`'Changed' => false`）。

```ruby
dna.add_resource_record_value('example.com', '', 'MX', '10 mail.example.com.')
dna.replace_resource_record_value('example.com', '', 'MX', '10 mail.example.com.', '20 mail.example.com.')
dna.remove_resource_record_value('example.com', '', 'MX', '20 mail.example.com.')
```

<details>
<summary>示例输出</summary>

```ruby
{ 'result' => 'OK', 'data' => { 'Name' => '', 'Type' => 'MX', 'TTL' => 3600, 'Contents' => ['10 mail.example.com.'] } }
# 值已存在：
{ 'result' => 'OK', 'data' => { 'Name' => '', 'Type' => 'MX', 'Contents' => ['10 mail.example.com.'], 'Changed' => false } }
```

</details>

#### 删除记录集合

`delete_resource_record_set(domain, name, type, apply = true, known_value = '')` — 删除该集合中的所有值；如果没有可删除的内容，则返回成功并带有 `'Removed' => false`。

```ruby
dna.delete_resource_record_set('example.com', 'www', 'A')
```

<details>
<summary>示例输出</summary>

```ruby
{ 'result' => 'OK', 'data' => { 'Name' => 'www.example.com.', 'Type' => 'A', 'Content' => '192.0.2.10' } }
```

</details>

#### 底层记录调用

```ruby
dna.add_resource_record('example.com', 'www', 'A', '192.0.2.10', 3600, true)
dna.edit_resource_record('example.com', 'www', 'www', 'A', '192.0.2.20', 3600, true)
dna.delete_resource_record('example.com', 'www.example.com.', '192.0.2.20', 'A', true)
dna.apply_resource_records('example.com')
```

<details>
<summary>示例输出</summary>

```ruby
{ 'result' => 'OK', 'data' => { 'Name' => 'www', 'Type' => 'A', 'TTL' => 3600, 'Content' => '192.0.2.10' } }   # 添加 / 编辑
{ 'result' => 'OK', 'data' => { 'Name' => 'www.example.com.', 'Type' => 'A', 'Content' => '192.0.2.20' } }    # 删除
{ 'result' => 'OK', 'data' => { 'DomainName' => 'example.com' } }                                              # 应用
```

</details>

<hr style="border: 4px solid #000; border-style: dashed;">

### URL 转发

转发类型：`'Standard'`（普通重定向）和 `'Frame'`（隐藏/框架转发）。

```ruby
dna.set_forwarding('example.com', 'https://www.example.org', 'Standard')
dna.get_forwarding('example.com')
dna.delete_forwarding('example.com')
```

<details>
<summary>示例输出</summary>

```ruby
# set_forwarding
{ 'result' => 'OK', 'data' => { 'RedirectAddress' => 'https://www.example.org', 'ForwardType' => 'Standard' } }
# get_forwarding（未配置转发时返回 Enabled => false，而不是错误）
{ 'result' => 'OK', 'data' => { 'Enabled' => true, 'RedirectAddress' => 'https://www.example.org', 'ForwardType' => 'Standard' } }
# delete_forwarding
{ 'result' => 'OK', 'data' => { 'DomainName' => 'example.com' } }
```

</details>

<hr style="border: 4px solid #000; border-style: dashed;">

### 实用工具（无网络请求）

#### 是否为 .tr 域名？

```ruby
dna.is_tr_tld('example.com.tr') # => true
dna.is_tr_tld('example.com')    # => false
```

#### 校验联系人

按照注册时相同的方式补全并规范化联系人信息：去除姓名中的数字和标点符号，缺失的州/省会以城市填充，国家名称会转换为 ISO 代码，电话号码会被拆分为号码和国家代码。

```ruby
dna.validate_contact('FirstName' => 'J0hn', 'Phone' => '+90 532 374 33 88', 'Country' => 'Turkey')
```

<details>
<summary>示例输出</summary>

```ruby
{
  'FirstName' => 'Jhn', 'Phone' => '5323743388', 'Country' => 'TR', 'LastName' => 'Isimyok',
  'AddressLine1' => 'Addres yok', 'City' => 'ISTANBUL', 'State' => 'ISTANBUL', 'ZipCode' => '34000',
  'PhoneCountryCode' => '90', 'Fax' => '', 'FaxCountryCode' => ''
}
```

</details>

<hr style="border: 4px solid #000; border-style: dashed;">

### 设置

| 方法 | 作用 |
|---|---|
| `set_error_reporting_enabled(false)` | 关闭遥测 |
| `set_telemetry_minimal(true)` | 发送精简的遥测数据 |
| `set_ssl_verification(false)` | 跳过 TLS 证书验证（不推荐） |
| `set_service_url(url)` | 使用其他网关 URL |
| `set_transport(callable)` | 替换 HTTP 传输层（见下文） |

HTTP 传输层可以是任何响应 `call(request)` 的对象，其中 `request` 是一个包含 `:method`、`:url`、`:headers`、`:body`、`:timeout`、`:connect_timeout` 和 `:verify_ssl` 的 Hash，并返回一个 `DomainNameApi::Response`（或包含 `:status`、`:body`、`:headers` 的 Hash）。默认实现为 `DomainNameApi::NetHttpTransport`（Net::HTTP）。测试正是借此在无网络的情况下运行的：

```ruby
fake = ->(request) { DomainNameApi::Response.new(status: 200, body: '{"resellerId":"abc"}', headers: {}) }
dna = DomainNameApi::Client.new(reseller_id, api_key, false, transport: fake)
```

<hr style="border: 4px solid #000; border-style: dashed;">

## 测试

测试套件仅使用 Minitest，且从不访问网络：

```bash
bundle install
bundle exec rake test
```

`test/conformance_test.rb` 运行 php-dna 的 126 个一致性测试用例（`test/fixtures/conformance/`）：针对每个场景，它会将发出的请求（方法、路径、查询参数、JSON 请求体、认证头）以及返回值与 php-dna 的结果进行比对。其他测试覆盖 HTTP 层、错误映射、遥测数据屏蔽、Net::HTTP 传输层以及实用工具。

<hr style="border: 4px solid #000; border-style: dashed;">

## 返回和错误代码及说明

| 代码 | 描述 | 详细 |
|------|------|------|
| 1000 | 命令成功完成 | 操作成功。 |
| 1001 | 命令成功完成；操作待处理 | 操作成功。但是，操作当前已排队等待完成。 |
| 2003 | 缺少必需参数 | 参数缺失错误。例如：联系信息中没有电话输入。 |
| 2105 | 对象不符合续费条件 | 域名状态不适合续费，已锁定更新操作。状态不应为"clientupdateprohibited"。可能由于其他状态条件。 |
| 2200 | 身份验证错误 | 授权错误，安全代码不正确或域名在另一个注册商处注册。 |
| 2302 | 对象已存在 | 域名或名称服务器信息已存在于数据库中。无法注册。 |
| 2303 | 对象不存在 | 域名或名称服务器信息在数据库中不存在。需要新注册。 |
| 2304 | 对象状态禁止操作 | 域名状态不适合更新，已锁定更新操作。状态不应为"clientupdateprohibited"。可能由于其他状态条件。 |

| 代码 | 详细 |
|------|------|
| 101 | 系统错误详细信息 ({0})！ |
| 102 | 多个错误详细信息 ({0})！ |
| 103 | 未知错误详细信息 ({0})！ |
| 200 | 未找到 API 命令 ({0})！ |
| 210 | 未找到 API 服务 ({0})！ |
| 211 | 未设置 API 服务提供商！ |
| 300 | 未找到经销商！ |
| 301 | 您当前的 IP 地址未被授权访问。请确保您从授权的 IP 地址连接并重试 |
| 310 | 不支持 TLD！ |
| 320 | 未找到 API！ |
| 321 | 不支持货币！ |
| 330 | 未设置必需参数 ({0})。 |
| – | 确保您完整发送所有联系对象 |
| 340 | 未找到价格定义 ({0}[{1}]-{2}{3})。 |
| 350 | 经销商余额不足。(经销商 Id : {0} - 当前余额 : {1} {2})。 |
| 350 | 会计货币不匹配或余额不足。 |
| 360 | 字段 ({0}) 的无效 API 请求。 |
| 360 | API 配额已超出！ |
| 361 | 限流错误！ |
| 362 | 高级域名目前无法注册。 |
| 363 | 由于域名处于自动续费期间，操作已取消 |
| 364 | 由于注册处问题，此域名目前无法进行交易 |

| 代码 | 详细 |
|------|------|
| 400 | 无效联系人 ({0})。 |
| 401 | 联系信息无法同步。 |
| 402 | 无法从注册处访问联系信息。 |
| 403 | 系统缺少信息。输入您的默认信息或联系支持团队。 |
| 404 | 域名联系人无法更新。来自注册处的权限。 |
| 410 | 未找到联系人。 |
| 410 | 未找到联系人 ({0})。 |
| 420 | 联系人 {0} 的无效 Api 命令。 |
| 430 | 未找到联系人 api。 |
| 440 | 联系人未同步。 |
| 450 | 域名联系人太多..！ |
| 451 | 无法继续进行联系人更新。 |

| 代码 | 详细 |
|------|------|
| 500 | 无效域名 id。 |
| 500 | 无效域名 id ({0})。 |
| 501 | 域名无法同步({0}) |
| 502 | 内部转移失败 |
| 503 | 域名注册不可用。 |
| 504 | 域名信息不匹配 .. 之前 :{0} |
| 505 | 输入 IP 地址。 |
| 506 | 域名转移已开始但无法读取联系信息 .. |
| 507 | 授权错误。 |
| 510 | 未找到域名。 |
| 511 | 无法找到过期域名。 |
| 512 | 域名不可续费。 |
| 513 | 域名不处于可更新状态。必须处于活动状态才能更新 |
| 514 | 预期赎回期。 |
| 520 | 域名 "{0}" 的无效 Api 命令。 |
| 530 | 无效域名期限。期限必须为 {0} 到 {1} 年。请求的期限为 {2} 年。 |
| 540 | 域名无法延长到当前日期 {0} 年以后。 |
| 550 | 无效域名。域名必须为 {0} 到 {1} 个字符长度。请求的域名为 {2} 个字符。 |
| 560 | 无效名称服务器数量。域名必须有 {0} 到 {1} 个名称服务器。请求的名称服务器数量为 {2}。 |
| 561 | 在传入请求中未找到名称服务器信息 |
| 570 | tld "{0}" 不支持 Idn。 |
| 571 | 期限无效。 |
| 572 | 命令无效。 |
| 573 | 未找到域名。 |
| 574 | 未找到 TLD 名称。 |
| 575 | 域名不处于可更新状态。必须处于活动状态才能更新名称服务器 |
| 576 | 域名可在到期日期前最后 1 个月内续费 |
| 580 | tld "{0}" 不支持转移。 |
| 581 | 未找到子名称服务器 |
| 582 | 转移由其他经销商发起。 |
| 583 | 转移未初始化。请联系支持团队。 |
| 584 | 对象状态禁止操作 |
| 590 | 此转移需要授权代码。 |
| 591 | 授权代码无效。 |
| 592 | 域名上存在转移锁定。 |
| 593 | 域名无法转移，状态信息和转移锁定必须符合所需标准。(状态信息: #ok) |
| 594 | 域名服务器地址无法解析 ({0}) |
| 595 | 无法读取联系信息 (whois.registrar.tld) 请确保隐私保护状态开放 |
| 596 | 联系信息无法验证 |
| 597 | 未找到 Tld |
| 598 | 发生未知错误 |
| 599 | 未找到域名转发 |

## 许可证

Apache License 2.0 — 详见 [LICENSE](LICENSE)。
