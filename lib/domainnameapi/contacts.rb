# frozen_string_literal: true

module DomainNameApi
  # A person or organisation in a contact role.
  #
  #   DomainNameApi::Contact.new(
  #     first_name: 'Ada', last_name: 'Lovelace', email: 'ada@example.com',
  #     address: '1 Example Street', city: 'Istanbul', state: 'Istanbul', postal_code: '34000',
  #     country: 'TR', phone_country_code: '90', phone: '555 123 45 67'
  #   )
  #
  # Requests tidy a contact before sending it: every field is trimmed, the
  # country upper-cased and the phone and fax fields keep only their digits
  # ("+90 (555) 123-45-67" works).
  class Contact < Model
    field :first_name
    field :last_name
    # Optional.
    field :company_name
    field :email, from: 'eMail'
    field :address
    field :city
    # Required; repeat the city when there is none.
    field :state
    field :postal_code
    # ISO 3166-1 alpha-2 code, e.g. "TR" ("GB", not "UK").
    field :country
    # Calling code without "+", e.g. "90".
    field :phone_country_code
    # Number without the calling code, e.g. "5551234567".
    field :phone
    field :fax_country_code
    field :fax
    # Publishes the contact in WHOIS. Leave it nil to keep the registry default
    # (recommended).
    field :disclose_flag, :boolean, nullable: true
    # The role. The API sets it on the contacts of a domain (DomainInfo#contacts);
    # requests that need it set it themselves.
    field :type, ContactType, from: 'contactType'
    # The handle, e.g. "DNA-12345". Set by the API.
    field :handle

    # A tidied copy, as sent to the API.
    def normalized
      Contact.new(
        first_name: Util.clean(first_name), last_name: Util.clean(last_name), company_name: Util.clean(company_name),
        email: Util.clean(email), address: Util.clean(address), city: Util.clean(city), state: Util.clean(state),
        postal_code: Util.clean(postal_code), country: Util.clean(country).upcase,
        phone_country_code: Util.digits(phone_country_code), phone: Util.digits(phone),
        fax_country_code: Util.digits(fax_country_code), fax: Util.digits(fax),
        disclose_flag: disclose_flag, type: type, handle: Util.clean(handle)
      )
    end

    # The contact details as the API expects them (ContactInformationDto),
    # without handle and, unless given, without role.
    def to_api(role = nil)
      c = normalized
      out = {
        'firstName' => c.first_name, 'lastName' => c.last_name, 'eMail' => c.email, 'address' => c.address,
        'city' => c.city, 'state' => c.state, 'postalCode' => c.postal_code, 'country' => c.country,
        'phoneCountryCode' => c.phone_country_code, 'phone' => c.phone
      }
      out.merge!(Util.compact('companyName' => c.company_name, 'faxCountryCode' => c.fax_country_code,
                              'fax' => c.fax))
      out['discloseFlag'] = c.disclose_flag unless c.disclose_flag.nil?
      role = ContactType[role] if role
      out['contactType'] = role.value if role
      out
    end

    # Adds the problems of the contact to a Validator, with field names
    # prefixed by +prefix+ ("contact.").
    def validate_into(v, prefix = '')
      c = normalized
      f = ->(name) { "#{prefix}#{name}" }
      v.required(f[:first_name], c.first_name)
      v.required(f[:last_name], c.last_name)
      v.required(f[:email], c.email)
      v.check(c.email.empty? || c.email.include?('@'), f[:email], 'is not an e-mail address')
      v.required(f[:address], c.address)
      v.required(f[:city], c.city)
      v.required(f[:state], c.state)
      v.required(f[:postal_code], c.postal_code)
      v.required(f[:country], c.country)
      v.check(c.country.empty? || c.country.length == 2, f[:country], 'must be a 2-letter ISO code such as TR or US')
      v.required(f[:phone_country_code], c.phone_country_code)
      v.check(c.phone_country_code.length <= 3, f[:phone_country_code], 'must be at most 3 digits, e.g. 90')
      v.required(f[:phone], c.phone)
      v.check(c.phone.length <= 16, f[:phone], 'must be at most 16 digits')
      v.max_length(f[:first_name], c.first_name, 80)
      v.max_length(f[:last_name], c.last_name, 80)
      v.max_length(f[:company_name], c.company_name, 256)
      v.max_length(f[:address], c.address, 256)
      v.max_length(f[:city], c.city, 80)
      v.max_length(f[:state], c.state, 80)
      v.max_length(f[:postal_code], c.postal_code, 15)
      v
    end
  end

  # The e-mail or phone verification state of a contact. A domain stays usable
  # after registration, but when the registrant e-mail is not verified within
  # 15 days the domain is put on hold.
  class ContactVerification < Model
    field :owner_name
    # The e-mail address or phone number.
    field :field_value
    field :field_type
    field :operation_status
    field :verified, :boolean, from: 'isUserVerified'
    field :verified_at, :time, from: 'userVerificationDate'
    field :created_at, :time, from: 'createdDate'
    field :token_expires_at, :time, from: 'tokenExpireDate'
    field :resent_at, :time, from: 'resendDate'
    field :resend_retry_count, :integer
    field :last_attempt_at, :time, from: 'lastAttemptDate'
    field :attempt_number, :integer
  end

  # A contact handle with its verification state.
  class ContactDetails < Model
    field :contact, Contact
    field :verifications, [ContactVerification], from: 'verificationObjects'
  end

  # The API's answer to ContactCreateRequest.
  class ContactCreateResult < Model
    field :handle
    field :message, from: 'operationMessage'
    field :success, :boolean, from: 'isSuccess'
  end

  # The API's answer to ContactUpdateRequest: the contact itself and every
  # domain that uses it.
  class ContactUpdateResult < Model
    # Counts over the affected domains.
    class Stats < Model
      field :total_domain_count, :integer
      field :success_count, :integer
      field :pending_document_count, :integer
      field :failed_count, :integer
      field :split_count, :integer
    end

    # One domain using the handle. Some registries cannot share a handle and
    # get a new one: store new_handle when it is set.
    class AffectedDomain < Model
      field :domain_name
      field :status
      field :new_handle
      field :reason
      field :message
    end

    field :handle
    field :success, :boolean, from: 'contactUpdateSuccess'
    field :stats, Stats
    field :affected_domains, [AffectedDomain]
  end

  # The "results" wrapper of ContactVerificationRequest. @api private
  class ContactVerificationList < Model
    field :results, [ContactVerification]
  end

  # Reads a contact handle. CLI: dna contact get
  class ContactGetRequest < BaseRequest
    endpoint :get, '/api/v1/contacts/{handle}', safety: :read
    returns ContactDetails
    attribute :handle

    def validate
      required :handle
    end
  end

  # Creates a contact handle. CLI: dna contact create
  class ContactCreateRequest < BaseRequest
    endpoint :post, '/api/v1/contacts', safety: :write
    returns ContactCreateResult
    # A Contact or a Hash of its fields.
    attribute :contact

    def body
      { 'contact' => Contact.coerce(contact).to_api }
    end

    def validate
      return invalid(:contact, 'is required') if contact.nil?

      Contact.coerce(contact).validate_into(validator, 'contact.')
    end
  end

  # Replaces a contact handle's details, and those of every domain using it.
  # CLI: dna contact update
  class ContactUpdateRequest < BaseRequest
    endpoint :put, '/api/v1/contacts/{handle}', safety: :write
    returns ContactUpdateResult
    attribute :handle
    # The complete new contact: the update replaces it, it does not patch it.
    attribute :contact

    def body
      { 'contact' => Contact.coerce(contact).to_api }
    end

    def validate
      required :handle
      return invalid(:contact, 'is required') if contact.nil?

      Contact.coerce(contact).validate_into(validator, 'contact.')
    end
  end

  # Reads the verification state of a contact. CLI: dna contact verification
  class ContactVerificationRequest < BaseRequest
    endpoint :get, '/api/v1/contacts/verification/check', safety: :read
    returns ContactVerificationList
    attribute :handle

    def query
      params.string('HandleCode', handle)
    end

    def validate
      required :handle
    end
  end

  # Sends the verification notice again. CLI: dna contact resend-verification
  class ContactResendVerificationRequest < BaseRequest
    endpoint :post, '/api/v1/contacts/verification/request', safety: :write
    attribute :handle

    def body
      { 'handleCode' => clean(handle) }
    end

    def validate
      required :handle
    end
  end

  # Reusable contact handles: create a contact once, then register domains with
  # its handle. CLI: dna contact
  class ContactService < Service
    # A contact handle and its verification state.
    def get(handle)
      call(ContactGetRequest.new(handle: handle))
    end

    # Creates a contact and returns its handle, which domains.register accepts.
    def create(contact)
      req = ContactCreateRequest.new(contact: contact)
      response = execute(req)
      res = response.value
      raise operation_error(req, response, nil, res.message) if !res.success? || Util.blank?(res.handle)

      res.handle
    end

    # Replaces the details of a contact handle. Every domain using the handle is
    # updated too; the result reports each of them.
    def update(handle, contact)
      req = ContactUpdateRequest.new(handle: handle, contact: contact)
      response = execute(req)
      res = response.value
      raise operation_error(req, response, nil, 'the contact could not be updated') unless res.success?

      res
    end

    # The e-mail and phone verification state of a contact.
    def verification(handle)
      call(ContactVerificationRequest.new(handle: handle)).results
    end

    # Sends the verification notice of a contact again. Returns true when it
    # was sent and false when there is nothing to verify (already verified, or
    # nothing pending).
    def resend_verification(handle)
      call(ContactResendVerificationRequest.new(handle: handle))
      true
    rescue APIError => e
      raise unless e.code?(ErrorCode::VERIFICATION_ALREADY_DONE) || e.code?(ErrorCode::VERIFICATION_NOT_PENDING)

      false
    end
  end
end
