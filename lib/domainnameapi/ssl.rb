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
    # The certificate that was checked.
    field :certificate_id
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

    # Identifies the certificate in every other ssl call.
    field :certificate_id
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

  # One certificate of ssl.list: enough to find its certificate_id and see
  # where it stands. ssl.get has the full record.
  class CertificateListItem < Model
    # Identifies the certificate in every other ssl call.
    field :certificate_id
    field :domain_name
    field :package_code
    field :package_name
    # The API's status name, e.g. "Active", "WaitingForInstall" or "Renewed".
    field :status
    # Why it has that status, e.g. "None" or "ConfigurationWindowExpired".
    field :status_reason
    field :configured, :boolean, from: 'isConfigured'
    field :issued, :boolean, from: 'isIssued'
    # The paid subscription: when it was bought and until when it runs. Renewal
    # opens 30 days before subscription_expires_at.
    field :purchased_at, :time
    field :subscription_expires_at, :time
    # Until when the issued certificate is valid; nil until it is issued.
    field :certificate_expires_at, :time
    # Set on a renewal: the certificate it renews.
    field :renewed_from_certificate_id
  end

  # An issued certificate and its chain, PEM-encoded.
  class CertificateContent < Model
    # The certificate the content belongs to.
    field :certificate_id
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

  # The certificate_id attribute of the requests that act on an existing
  # certificate. A domain can have several certificates, so the API addresses
  # them by id only; a domain name is refused before anything is sent.
  # @api private
  module CertificateLookup
    NOT_A_CERTIFICATE_ID =
      'must be a certificate id (GUID). Certificates are no longer addressed by domain name: use the ' \
      'certificate_id returned by ssl.purchase or ssl.renew, or look it up with ssl.list(domain_name: ...)'

    private

    def certificate_body
      { 'certificateId' => clean(certificate_id) }
    end

    def certificate_query
      params.string('CertificateId', certificate_id)
    end

    def validate_certificate_id
      return required(:certificate_id) if Util.blank?(certificate_id)

      check(Util.guid?(certificate_id), :certificate_id, NOT_A_CERTIFICATE_ID)
    end
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

  # Buys a certificate package for a domain. Charges your balance. The answer's
  # certificate_id identifies the new certificate from then on: store it.
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
  # issuance, within 15 days of its purchase or renewal. CLI: dna ssl configure
  class SSLConfigureRequest < BaseRequest
    include CertificateLookup

    endpoint :put, '/api/v1/ssls/configure', safety: :write
    returns SSLOperationResult
    # The certificate to configure: the certificate_id ssl.purchase or ssl.renew
    # returned.
    attribute :certificate_id
    # PEM-encoded. Its common name must match the certificate's domain.
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
      certificate_body
        .merge('csr' => clean(csr), 'contact' => SSLContact.coerce(contact)&.to_api || {})
        .merge(optional(
                 'privateKey' => private_key, 'approverMail' => approver_mail,
                 'authenticationType' => AuthenticationType[authentication_type]&.value,
                 'webServerType' => WebServerType[web_server_type]&.value,
                 'sanList' => clean_list(san_list).join(','), 'wildcardList' => clean_list(wildcard_list).join(',')
               ))
    end

    def validate
      validate_certificate_id
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
    include CertificateLookup

    endpoint :put, '/api/v1/ssls/check-status', safety: :read
    returns CertificateStatus
    attribute :certificate_id

    def body
      certificate_body
    end

    def validate
      validate_certificate_id
    end
  end

  # Reads the full record of a certificate. CLI: dna ssl get
  class SSLGetRequest < BaseRequest
    include CertificateLookup

    endpoint :get, '/api/v1/ssls/certificate', safety: :read
    returns Certificate
    attribute :certificate_id

    def query
      certificate_query
    end

    def validate
      validate_certificate_id
    end
  end

  # Downloads an issued certificate. CLI: dna ssl content
  class SSLContentRequest < BaseRequest
    include CertificateLookup

    endpoint :get, '/api/v1/ssls/certificate-content', safety: :read
    returns CertificateContent
    attribute :certificate_id

    def query
      certificate_query
    end

    def validate
      validate_certificate_id
    end
  end

  # Reissues a certificate with a new CSR, key or approver. CLI: dna ssl reissue
  class SSLReissueRequest < BaseRequest
    include CertificateLookup

    endpoint :post, '/api/v1/ssls/reissue', safety: :write
    returns SSLOperationResult
    attribute :certificate_id
    attribute :approver_mail
    attribute :csr
    attribute :private_key

    def body
      certificate_body.merge(optional('approverMail' => approver_mail, 'csr' => csr, 'privateKey' => private_key))
    end

    def validate
      validate_certificate_id
    end
  end

  # Lists the e-mail addresses allowed for e-mail validation. Set either
  # certificate_id (an existing certificate: its domain and package are used) or
  # domain_name and package_code (before a purchase). CLI: dna ssl approvers
  class SSLApproversRequest < BaseRequest
    include CertificateLookup

    endpoint :get, '/api/v1/ssls/approvers', safety: :read
    returns SSLApproverList
    # An existing certificate.
    attribute :certificate_id
    # The domain you are about to buy a certificate for; needs package_code.
    attribute :domain_name
    # The package you are about to buy (an SSLProduct#product_code).
    attribute :package_code

    def query
      certificate_query.string('DomainName', domain_name).string('PackageCode', package_code)
    end

    def validate
      if Util.blank?(certificate_id)
        validate_purchase
      else
        validate_certificate_id
        check(Util.blank?(domain_name) && Util.blank?(package_code), :certificate_id,
              'is used alone: its domain and package are taken from the certificate, so leave out domain_name ' \
              'and package_code')
      end
    end

    private

    def validate_purchase
      if Util.blank?(domain_name)
        return invalid(:certificate_id, 'set either certificate_id (an existing certificate) or domain_name and ' \
                                        'package_code (before a purchase)')
      end

      check(!Util.blank?(package_code), :package_code,
            'is required with domain_name; for an existing certificate pass certificate_id instead')
    end
  end

  # Revokes a certificate. This cannot be undone and is not a refund.
  # CLI: dna ssl revoke
  class SSLRevokeRequest < BaseRequest
    include CertificateLookup

    endpoint :delete, '/api/v1/ssls/revoke', safety: :destructive
    returns SSLOperationResult
    attribute :certificate_id

    def query
      certificate_query
    end

    def validate
      validate_certificate_id
    end
  end

  # Renews a certificate: opens a new 1-year order for the same domain and
  # package, linked to it. Charges your balance (the renewal price). The answer's
  # certificate_id is the new certificate, which must then be configured.
  # CLI: dna ssl renew
  class SSLRenewRequest < BaseRequest
    include CertificateLookup

    endpoint :post, '/api/v1/ssls/renew', safety: :billable
    returns SSLOperationResult
    # The certificate to renew.
    attribute :certificate_id

    def body
      certificate_body
    end

    def validate
      validate_certificate_id
    end
  end

  # Lists your certificates, newest first. CLI: dna ssl list
  class SSLListRequest < PagedRequest
    endpoint :get, '/api/v1/ssls', safety: :read
    returns Page.of(CertificateListItem)
    # Keeps only the certificates of this domain. For wildcards both
    # "*.example.com" and "example.com" match.
    attribute :domain_name

    def query
      params.string('DomainName', domain_name).page(skip: skip, limit: limit)
    end

    def validate
      super
      check(Util.blank?(sort), :sort, 'is not supported: certificates are always listed newest first')
    end
  end

  # Buys, configures, issues, renews, reissues and revokes SSL certificates.
  # CLI: dna ssl
  #
  # The flow: find a package with products.ssls, #generate_csr (or bring your
  # own), #purchase (charges the balance) and keep the certificate_id it
  # returns, #configure within 15 days, then poll #status until the certificate
  # is issued and download it with #content.
  #
  # A domain can have several certificates, so an existing certificate is
  # addressed by its certificate_id (a GUID), never by its domain name:
  # #purchase and #renew return it, #list finds it by domain.
  #
  # To renew, call #renew (charges the renewal price) and #configure the new
  # certificate it returns. Do not #purchase again for that: it is an unrelated
  # new order at the purchase price, and the old certificate never becomes
  # "Renewed".
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

    # Buys a certificate package for a domain and charges your balance. Store
    # the certificate_id of the result: every later call for this certificate
    # takes it. Then call #configure within 15 days. CLI: dna ssl initialize
    #
    #   certificate_id = client.ssl.purchase('example.com', package_code: 'PositiveSSL').certificate_id
    def purchase(domain_name, package_code:)
      operation(SSLInitializeRequest.new(domain_name: domain_name, package_code: package_code))
    end

    # Submits the CSR, validation method and contact of the certificate
    # +certificate_id+ names (from #purchase or #renew); then poll #status until
    # issued? is true. The CSR's common name must match the certificate's domain.
    #
    #   client.ssl.configure(certificate_id: certificate_id, csr: csr.csr, approver_mail: 'admin@example.com',
    #                        authentication_type: :email, web_server_type: :apache, contact: contact)
    def configure(request = nil, **attributes)
      operation(build(SSLConfigureRequest, request, attributes))
    end

    # Refreshes and returns the state of a certificate.
    def status(certificate_id)
      call(SSLStatusRequest.new(certificate_id: certificate_id))
    end

    # The full record of a certificate: subscription, configuration, contacts.
    def get(certificate_id)
      call(SSLGetRequest.new(certificate_id: certificate_id))
    end

    # The issued certificate and its chain.
    #
    #   File.write('example.com.crt', client.ssl.content(certificate_id).chain)
    def content(certificate_id)
      call(SSLContentRequest.new(certificate_id: certificate_id))
    end

    # Reissues a certificate with a new CSR, key or approver.
    def reissue(certificate_id, csr: nil, private_key: nil, approver_mail: nil)
      operation(SSLReissueRequest.new(certificate_id: certificate_id, csr: csr, private_key: private_key,
                                      approver_mail: approver_mail))
    end

    # The e-mail addresses allowed for e-mail validation: of an existing
    # certificate, or of a domain and package before a purchase.
    #
    #   client.ssl.approvers(certificate_id: certificate_id)
    #   client.ssl.approvers(domain_name: 'example.com', package_code: 'PositiveSSL')
    def approvers(certificate_id: nil, domain_name: nil, package_code: nil)
      call(SSLApproversRequest.new(certificate_id: certificate_id, domain_name: domain_name,
                                   package_code: package_code)).mails
    end

    # Revokes a certificate. This cannot be undone, and the fee is not refunded.
    def revoke(certificate_id)
      operation(SSLRevokeRequest.new(certificate_id: certificate_id))
    end

    # Renews a certificate and charges your balance (the renewal price). The
    # API allows it from 30 days before the subscription ends. The result's
    # certificate_id is the new certificate: #configure it within 15 days; the
    # old one becomes "Renewed" once the new one is active. While the renewal
    # waits for configuration, renewing again returns it without a second charge.
    #
    #   renewal = client.ssl.renew(certificate_id)
    #   client.ssl.configure(certificate_id: renewal.certificate_id, csr: csr.csr, contact: contact, ...)
    def renew(certificate_id)
      operation(SSLRenewRequest.new(certificate_id: certificate_id))
    end

    # One page of your certificates, newest first; +domain_name+ keeps those of
    # one domain. This is how to find a certificate_id.
    #
    #   client.ssl.list(domain_name: 'example.com').each { |c| puts "#{c.certificate_id} #{c.status}" }
    def list(request = nil, **filters)
      call(build(SSLListRequest, request, filters))
    end

    # Every matching certificate, fetching pages as you go. Returns an
    # Enumerator, or iterates when given a block.
    #
    #   client.ssl.all { |c| puts "#{c.domain_name} #{c.subscription_expires_at}" if c.status == 'Active' }
    def all(request = nil, **filters, &block)
      enum = paginate(build(SSLListRequest, request, filters)) { |req| call(req) }
      block ? enum.each(&block) : enum
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
