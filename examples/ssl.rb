# frozen_string_literal: true

# Buy, configure and download an SSL certificate. Purchasing charges your
# balance, so this only runs against OTE.
#
#   DNA_ENV=ote ruby examples/ssl.rb example.com PositiveSSL
$LOAD_PATH.unshift File.expand_path('../lib', __dir__)
require 'domainnameapi'

domain = ARGV[0] || 'example.com'
package = ARGV[1] || 'PositiveSSL'
client = DomainNameApi::Client.from_env
abort 'Refusing to buy a certificate in production from an example; set DNA_ENV=ote.' unless client.ote?

products = client.products.ssls(filter_text: package)
puts "packages: #{products.map(&:product_code).join(', ')}"

csr = client.ssl.generate_csr(domain_name: domain, country: 'TR', state: 'Istanbul', locality: 'Istanbul',
                              organization: 'Example Ltd', organization_unit: 'IT')
File.write("#{domain}.key", csr.private_key)

client.ssl.purchase(domain, package_code: package)
approver = client.ssl.approvers(domain, package_code: package).first
client.ssl.configure(
  domain_name: domain, csr: csr.csr, private_key: csr.private_key, approver_mail: approver,
  authentication_type: :email, web_server_type: :apache,
  contact: { first_name: 'Ada', last_name: 'Lovelace', company_name: 'Example Ltd', email: 'ada@example.com',
             address: '1 Example Street', city: 'Istanbul', postal_code: '34000', country: 'TR',
             phone_country_code: '90', phone: '5551234567' }
)

10.times do
  st = client.ssl.status(domain)
  puts "status: #{st.status} #{st.status_message}"
  if st.issued?
    File.write("#{domain}.crt", client.ssl.content(domain).chain)
    puts "saved #{domain}.crt and #{domain}.key"
    break
  end
  sleep 30
end
