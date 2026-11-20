# frozen_string_literal: true

module DomainNameApi
  # Whether a domain can be transferred in.
  class TransferCheck < Model
    # The overall answer.
    field :transferable, :boolean, from: 'transferAvailabilityStatus'
    field :message_key
    field :message
    field :auth_code_required, :boolean, from: 'authCodeIsRequired'
    field :auth_code_valid, :boolean, from: 'authCodeIsValid'
    field :user_transfer_required, :boolean
    # The losing registrar still locks the domain.
    field :transfer_lock, :boolean
    field :domain_statuses, [:string]
    field :additional_attributes, :attributes
    field :premium, :boolean, from: 'isPremium'
    field :premium_price, :float
    field :premium_currency
  end

  # The state of a pending incoming transfer.
  class TransferStatus < Model
    field :domain_name
    field :status
    field :requested_date
    field :final_date
    field :requested_client_id
    field :action_client_id
  end

  # Starts an incoming transfer. Charges your balance. CLI: dna domain transfer
  class DomainTransferRequest < BaseRequest
    endpoint :post, '/api/v1/domains/transfer', safety: :billable
    returns DomainOperationResult
    attribute :domain_name
    # The transfer authorization (EPP) code from the current registrar. It is
    # sent as given: surrounding spaces can be part of it.
    attribute :auth_code
    # Years added on transfer, 1 to 10 (nil lets the registry decide; usually 1).
    attribute :years

    def body
      b = domain_body.merge(optional('period' => Util.to_int(years)))
      b['authCode'] = auth_code.to_s unless auth_code.nil? || auth_code.to_s.empty?
      b
    end

    def validate
      required :domain_name
      between :years, 1, 10
    end
  end

  # Checks whether a domain can be transferred in with an auth code.
  # CLI: dna domain transfer-check
  class DomainTransferCheckRequest < BaseRequest
    endpoint :post, '/api/v1/domains/transfers/check', safety: :read
    returns TransferCheck
    attribute :domain_name
    attribute :auth_code

    def body
      { 'domainName' => clean(domain_name), 'authCode' => auth_code.to_s }
    end

    def validate
      required :domain_name
      required :auth_code
    end
  end

  # Reads the state of a pending transfer. CLI: dna domain transfer-status
  class DomainTransferStatusRequest < BaseRequest
    endpoint :post, '/api/v1/domains/transfers/query', safety: :read
    returns TransferStatus
    attribute :domain_name

    def body
      domain_body
    end

    def validate
      required :domain_name
    end
  end

  class DomainService < Service
    # Starts an incoming transfer and charges your balance. Check it first with
    # #transfer_check; follow it with #transfer_status.
    #
    #   client.domains.transfer('example.com', auth_code: 'Xy7!kP2q')
    def transfer(domain_name, auth_code:, years: nil)
      operation(DomainTransferRequest.new(domain_name: domain_name, auth_code: auth_code, years: years))
    end

    # Whether a domain can be transferred in with +auth_code+: lock state, auth
    # code validity, registry statuses and premium price.
    def transfer_check(domain_name, auth_code)
      call(DomainTransferCheckRequest.new(domain_name: domain_name, auth_code: auth_code))
    end

    # The state of a pending incoming transfer.
    def transfer_status(domain_name)
      call(DomainTransferStatusRequest.new(domain_name: domain_name))
    end
  end
end
