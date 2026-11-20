# frozen_string_literal: true

module DomainNameApi
  # The contact of a certificate order.
  class SSLContact < Model
    field :title
    field :first_name
    field :last_name
    field :company_name
    field :email, from: 'eMail'
    field :address
    field :city
    field :state
    field :postal_code
    field :country
    field :phone_country_code
    field :phone
    field :fax_country_code
    field :fax
    # The contact's role, set by the API.
    field :type

    # The contact as the API expects it: trimmed, country upper-cased, phone
    # fields as digits, without the role.
    def to_api
      out = {
        'firstName' => Util.clean(first_name), 'lastName' => Util.clean(last_name),
        'companyName' => Util.clean(company_name), 'eMail' => Util.clean(email), 'address' => Util.clean(address),
        'city' => Util.clean(city), 'postalCode' => Util.clean(postal_code),
        'country' => Util.clean(country).upcase, 'phoneCountryCode' => Util.digits(phone_country_code),
        'phone' => Util.digits(phone)
      }
      out.merge(Util.compact('title' => title, 'state' => state, 'faxCountryCode' => Util.digits(fax_country_code),
                             'fax' => Util.digits(fax)))
    end

    # @api private
    def validate_into(v, prefix = 'contact.')
      c = to_api
      { first_name: 'firstName', last_name: 'lastName', company_name: 'companyName', email: 'eMail',
        address: 'address', city: 'city', postal_code: 'postalCode', country: 'country',
        phone_country_code: 'phoneCountryCode', phone: 'phone' }.each do |name, key|
        v.required("#{prefix}#{name}", c[key])
      end
      { first_name: ['firstName', 70], last_name: ['lastName', 70], company_name: ['companyName', 150],
        address: ['address', 200], city: ['city', 20], state: ['state', 20], postal_code: ['postalCode', 10],
        phone: ['phone', 15] }.each do |name, (key, max)|
        v.max_length("#{prefix}#{name}", c[key], max)
      end
      v
    end
  end

  # A certificate signing request and its private key.
  class CSR < Model
    field :csr
    # Needed to install the certificate. Store it safely.
    field :private_key
  end

  # The decoded subject of a CSR.
  class CSRInfo < Model
    field :domain_name
    field :country
    field :state
    field :locality
    field :organization
    field :organization_unit
    field :alternative_names
    field :wildcard, :boolean, from: 'isWildcard'
    field :san, :boolean, from: 'isSan'
  end

  # The API's answer to a certificate operation.
  class SSLOperationResult < Model
    field :success, :boolean
    field :message
    field :certificate_id
    field :status
    # How to complete domain control validation (e.g. the CNAME record or file
    # to create).
    field :dcv_details, from: 'dcvDetails'
    field :csr
    field :private_key
  end

  # The current state of a certificate.
  class CertificateStatus < Model
    field :domain_name
    field :status
    field :status_message
    field :configured, :boolean, from: 'isConfigured'
    field :issued, :boolean, from: 'isIssued'
    field :expires_at, :time, from: 'certificateExpiresAt'
  end

  # The full record of a certificate.
  class Certificate < Model
    # When it was bought and until when the subscription runs.
    class Subscription < Model
      field :purchased_at, :time
      field :expires_at, :time
    end

    # What was submitted with ssl.configure.
    class Configuration < Model
      field :configured_at, :time
      field :configuration_link
      field :pin
      field :web_server
      field :authentication_type
      field :san_list, from: 'sanList'
      field :wildcard_list
      field :approver_mail
      field :csr
      field :dcv_details, from: 'dcvDetails'
    end

    # The issued certificate's validity.
    class Issued < Model
      field :issued_at, :time
      field :valid_until, :time
    end

    field :domain_name
    field :status
    field :configured, :boolean, from: 'isConfigured'
    field :issued, :boolean, from: 'isIssued'
    field :package_name
    field :package_code
    field :subscription, Subscription
    field :configuration, Configuration
    field :certificate, Issued
    field :contacts, [SSLContact]
  end

  # An issued certificate and its chain, PEM-encoded.
  class CertificateContent < Model
    field :certificate
    field :intermediate1, from: 'intermediateCertificate1'
    field :intermediate2, from: 'intermediateCertificate2'
    field :root, from: 'rootCertificate'

    # The certificate followed by its intermediates, the bundle most web
    # servers want.
    def chain
      "#{[certificate, intermediate1, intermediate2].map { |p| Util.clean(p) }.reject(&:empty?).join("\n")}\n"
    end
  end

  # The "mails" wrapper of SSLApproversRequest. @api private
  class SSLApproverList < Model
    field :mails, [:string]
  end

  # Generates a CSR and private key. CLI: dna ssl generate-csr
  class SSLGenerateCSRRequest < BaseRequest
    endpoint :post, '/api/v1/ssls/generate-csr', safety: :read
    returns CSR
    attribute :domain_name
    # The 2-letter ISO code.
    attribute :country
    attribute :state
    attribute :locality
    attribute :organization
    attribute :organization_unit
    # Extra names (SAN).
    attribute :alternative_names, default: []

    def body
      { 'domainName' => clean(domain_name), 'country' => clean(country).upcase, 'state' => clean(state),
        'locality' => clean(locality), 'organization' => clean(organization),
        'organizationUnit' => clean(organization_unit) }
        .merge(optional('alternativeNames' => clean_list(alternative_names)))
    end

    def validate
      required :domain_name
      max_length :domain_name, 72, clean(domain_name)
      required :country
      check(Util.blank?(country) || clean(country).length == 2, :country, 'must be a 2-letter ISO code')
      required :state
      required :locality
      required :organization
      required :organization_unit
    end
  end

  # Decodes a CSR. CLI: dna ssl check-csr
  class SSLCheckCSRRequest < BaseRequest
    endpoint :post, '/api/v1/ssls/check-csr', safety: :read
    returns CSRInfo
    # PEM-encoded.
    attribute :csr

    def body
      { 'csr' => clean(csr) }
    end

    def validate
      required :csr
    end
  end

  # Buys a certificate package for a domain. Charges your balance.
  # CLI: dna ssl initialize
  class SSLInitializeRequest < BaseRequest
    endpoint :post, '/api/v1/ssls/initialize', safety: :billable
    returns SSLOperationResult
    attribute :domain_name
    # An SSLProduct#product_code from products.ssls.
    attribute :package_code

    def body
      { 'domainName' => clean(domain_name), 'packageCode' => clean(package_code) }
    end

    def validate
      required :domain_name
      required :package_code
    end
  end

  # Submits the CSR, validation method and contact of a certificate for
  # issuance. CLI: dna ssl configure
  class SSLConfigureRequest < BaseRequest
    endpoint :put, '/api/v1/ssls/configure', safety: :write
    returns SSLOperationResult
    attribute :domain_name
    # PEM-encoded.
    attribute :csr
    # PEM-encoded; optional when the CSR was made elsewhere.
    attribute :private_key
    # Receives the approval e-mail (authentication_type :email); ssl.approvers
    # lists the allowed addresses.
    attribute :approver_mail
    # AuthenticationType: :email, :cname, :http or :file.
    attribute :authentication_type
    # WebServerType: :apache, :iis, ...
    attribute :web_server_type
    # Additional names.
    attribute :san_list, default: []
    attribute :wildcard_list, default: []
    # An SSLContact or a Hash of its fields.
    attribute :contact

    def body
      { 'domainName' => clean(domain_name), 'csr' => clean(csr), 'contact' => SSLContact.coerce(contact)&.to_api || {} }
        .merge(optional(
                 'privateKey' => private_key, 'approverMail' => approver_mail,
                 'authenticationType' => AuthenticationType[authentication_type]&.value,
                 'webServerType' => WebServerType[web_server_type]&.value,
                 'sanList' => clean_list(san_list).join(','), 'wildcardList' => clean_list(wildcard_list).join(',')
               ))
    end

    def validate
      required :domain_name
      required :csr
      check(Util.blank?(approver_mail) || approver_mail.to_s.include?('@'), :approver_mail, 'is not an e-mail address')
      enum(:authentication_type, AuthenticationType)
      enum(:web_server_type, WebServerType)
      return invalid(:contact, 'is required') if contact.nil?

      SSLContact.coerce(contact).validate_into(validator, 'contact.')
    end
  end

  # Refreshes and reads the state of a certificate. CLI: dna ssl status
  class SSLStatusRequest < BaseRequest
    endpoint :put, '/api/v1/ssls/check-status', safety: :read
    returns CertificateStatus
    attribute :domain_name

    def body
      domain_body
    end

    def validate
      required :domain_name
    end
  end

  # Reads the full record of a certificate. CLI: dna ssl get
  class SSLGetRequest < BaseRequest
    endpoint :get, '/api/v1/ssls/certificate', safety: :read
    returns Certificate
    attribute :domain_name

    def query
      params.string('DomainName', domain_name)
    end

    def validate
      required :domain_name
    end
  end

  # Downloads an issued certificate. CLI: dna ssl content
  class SSLContentRequest < BaseRequest
    endpoint :get, '/api/v1/ssls/certificate-content', safety: :read
    returns CertificateContent
    attribute :domain_name

    def query
      params.string('DomainName', domain_name)
    end

    def validate
      required :domain_name
    end
  end

  # Reissues a certificate with a new CSR, key or approver. CLI: dna ssl reissue
  class SSLReissueRequest < BaseRequest
    endpoint :post, '/api/v1/ssls/reissue', safety: :write
    returns SSLOperationResult
    attribute :domain_name
    attribute :approver_mail
    attribute :csr
    attribute :private_key

    def body
      domain_body.merge(optional('approverMail' => approver_mail, 'csr' => csr, 'privateKey' => private_key))
    end

    def validate
      required :domain_name
    end
  end

  # Lists the e-mail addresses allowed for e-mail validation.
  # CLI: dna ssl approvers
  class SSLApproversRequest < BaseRequest
    endpoint :get, '/api/v1/ssls/approvers', safety: :read
    returns SSLApproverList
    attribute :domain_name
    # Narrows the list to a package; optional.
    attribute :package_code

    def query
      params.string('DomainName', domain_name).string('PackageCode', package_code)
    end

    def validate
      required :domain_name
    end
  end

  # Revokes a certificate. This cannot be undone. CLI: dna ssl revoke
  class SSLRevokeRequest < BaseRequest
    endpoint :delete, '/api/v1/ssls/revoke', safety: :destructive
    returns SSLOperationResult
    attribute :domain_name

    def query
      params.string('DomainName', domain_name)
    end

    def validate
      required :domain_name
    end
  end

  # Buys, configures, issues, reissues and revokes SSL certificates.
  # CLI: dna ssl
  #
  # The flow: find a package with products.ssls, #generate_csr (or bring your
  # own), #purchase (charges the balance), #configure, then poll #status until
  # the certificate is issued and download it with #content.
  class SSLService < Service
    # A new CSR and its private key.
    #
    #   client.ssl.generate_csr(domain_name: 'example.com', country: 'TR', state: 'Istanbul',
    #                           locality: 'Istanbul', organization: 'Example Ltd', organization_unit: 'IT')
    def generate_csr(request = nil, **attributes)
      call(build(SSLGenerateCSRRequest, request, attributes))
    end

    # Decodes a PEM-encoded CSR.
    def check_csr(csr)
      call(SSLCheckCSRRequest.new(csr: csr))
    end

    # Buys a certificate package for a domain and charges your balance; then
    # call #configure. CLI: dna ssl initialize
    def purchase(domain_name, package_code:)
      operation(SSLInitializeRequest.new(domain_name: domain_name, package_code: package_code))
    end

    # Submits the CSR, validation method and contact; then poll #status until
    # issued? is true.
    def configure(request = nil, **attributes)
      operation(build(SSLConfigureRequest, request, attributes))
    end

    # Refreshes and returns the state of a certificate.
    def status(domain_name)
      call(SSLStatusRequest.new(domain_name: domain_name))
    end

    # The full record of a certificate: subscription, configuration, contacts.
    def get(domain_name)
      call(SSLGetRequest.new(domain_name: domain_name))
    end

    # The issued certificate and its chain.
    #
    #   File.write('example.com.crt', client.ssl.content('example.com').chain)
    def content(domain_name)
      call(SSLContentRequest.new(domain_name: domain_name))
    end

    # Reissues a certificate with a new CSR, key or approver.
    def reissue(domain_name, csr: nil, private_key: nil, approver_mail: nil)
      operation(SSLReissueRequest.new(domain_name: domain_name, csr: csr, private_key: private_key,
                                      approver_mail: approver_mail))
    end

    # The e-mail addresses allowed for e-mail validation.
    def approvers(domain_name, package_code: nil)
      call(SSLApproversRequest.new(domain_name: domain_name, package_code: package_code)).mails
    end

    # Revokes a certificate. This cannot be undone.
    def revoke(domain_name)
      operation(SSLRevokeRequest.new(domain_name: domain_name))
    end

    private

    def operation(request)
      response = execute(request)
      res = response.value
      raise operation_error(request, response, nil, res.message) unless res.success?

      res
    end
  end
end
