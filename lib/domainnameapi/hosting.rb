# frozen_string_literal: true

module DomainNameApi
  # Hosting provisioning states (HostingStatus#status, Hosting#status).
  module HostingState
    PROVISIONING = 'Provisioning'
    ACTIVE = 'Active'
    # The balance is refunded automatically.
    FAILED = 'Failed'
    SUSPENDED = 'Suspended'
    DELETED = 'Deleted'
  end

  # A hosting package and the plans it offers.
  class HostingPackage < Model
    # A plan of the package.
    class Plan < Model
      # The value hosting.create takes.
      field :service_plan
      # Part of the plan; cannot be changed later.
      field :operating_system
      field :panel_type
    end

    field :name
    field :required_min_leasing, :integer
    field :permitted_max_leasing, :integer
    field :service_plans, [Plan]
  end

  # A hosting plan and its limits. A nil limit means unlimited, not zero.
  class ServicePlan < Model
    field :name
    field :external_id
    field :disk_quota_mb, :integer, from: 'diskQuotaMb'
    field :bandwidth_limit_mb, :integer, from: 'bandwidthLimitMb'
    field :max_domains, :integer
    field :max_sub_domains, :integer
    field :max_databases, :integer
    field :max_ftp_accounts, :integer, from: 'maxFtpAccounts'
    field :max_email_accounts, :integer
    field :dedicated_ip, :boolean, from: 'hasDedicatedIp'
    field :shell_access, :boolean, from: 'hasShellAccess'
  end

  # The API's answer to HostingCreateRequest.
  class HostingCreateResult < Model
    # Identifies the hosting ("HST-..."); store it.
    field :service_id
    field :status
    # The panel access fields are empty until the hosting is active.
    field :panel_address
    field :username
    field :password
    field :token
  end

  # A hosting service.
  class Hosting < Model
    # The UUID hosting.plans takes.
    field :hosting_id
    field :service_id
    field :domain_name
    field :package_name
    field :lease_on, :time
    field :expires_on, :time, from: 'expiredOn'
    field :status
    field :external_customer_id
  end

  # The provisioning state of a hosting. The panel access fields are set only
  # once the hosting is active.
  class HostingStatus < Model
    field :service_id
    field :domain_name
    field :status
    field :status_message
    field :panel_address
    field :username
    field :password
    field :token
    field :failure_reason

    # Whether the hosting is ready to use.
    def active?
      status.to_s.casecmp?(HostingState::ACTIVE)
    end

    # Whether provisioning failed.
    def failed?
      status.to_s.casecmp?(HostingState::FAILED)
    end
  end

  # Lists hosting packages. CLI: dna hosting packages
  class HostingPackagesRequest < BaseRequest
    endpoint :get, '/api/v1/hostings/packages', safety: :read
    returns [HostingPackage]
  end

  # Lists service plans and their limits. CLI: dna hosting plans
  class HostingPlansRequest < BaseRequest
    endpoint :get, '/api/v1/hostings/plans', safety: :read
    returns [ServicePlan]
    # Limits the list to the plans available to one hosting (Hosting#hosting_id); optional.
    attribute :hosting_id

    def query
      params.string('hostingId', hosting_id)
    end
  end

  # Orders a hosting for a domain. Charges your balance. CLI: dna hosting create
  class HostingCreateRequest < BaseRequest
    endpoint :post, '/api/v1/hostings/create', safety: :billable
    returns HostingCreateResult
    attribute :domain_name
    # From hosting.packages.
    attribute :service_plan

    def body
      { 'domainName' => clean(domain_name), 'servicePlan' => clean(service_plan) }
    end

    def validate
      required :domain_name
      required :service_plan
    end
  end

  # Looks a hosting up by service ID or domain name: set exactly one. @api private
  module HostingLookup
    private

    def validate_lookup
      check(Util.blank?(service_id) != Util.blank?(domain_name), :service_id,
            'set either the service ID or the domain name')
    end
  end

  # Reads a hosting by service ID or domain name (set exactly one).
  # CLI: dna hosting get
  class HostingGetRequest < BaseRequest
    include HostingLookup

    endpoint :get, '/api/v1/hostings', safety: :read
    returns Hosting
    attribute :service_id
    attribute :domain_name

    def query
      params.string('serviceId', service_id).string('domainName', domain_name)
    end

    def validate
      validate_lookup
    end
  end

  # Reads a hosting by the token hosting.create returned.
  # CLI: dna hosting get-by-token
  class HostingGetByTokenRequest < BaseRequest
    endpoint :get, '/api/v1/hostings/by-token', safety: :read
    returns Hosting
    attribute :token

    def query
      params.string('token', token)
    end

    def validate
      required :token
    end
  end

  # Reads the provisioning state of a hosting by service ID (preferred) or
  # domain name (set exactly one). CLI: dna hosting status
  class HostingStatusRequest < BaseRequest
    include HostingLookup

    endpoint :get, '/api/v1/hostings/check-status', safety: :read
    returns HostingStatus
    attribute :service_id
    attribute :domain_name

    def query
      params.string('ServiceId', service_id).string('DomainName', domain_name)
    end

    def validate
      validate_lookup
    end
  end

  # Orders and inspects web hosting. CLI: dna hosting
  #
  # The flow: pick a plan from #packages, #create (charges the balance; the API
  # answers 202 while provisioning runs), then #wait (or poll #status) until the
  # hosting is active. Never create again for a hosting that is still
  # provisioning: that charges twice.
  class HostingService < Service
    # Poll intervals of #wait, in seconds: fast for the first two minutes.
    POLL_FAST = 5
    POLL_SLOW = 30

    # The hosting packages and their service plans.
    def packages
      call(HostingPackagesRequest.new)
    end

    # Service plans and their limits; +hosting_id+ limits them to one hosting.
    def plans(hosting_id: nil)
      call(HostingPlansRequest.new(hosting_id: hosting_id))
    end

    # Orders a hosting and charges your balance. Provisioning continues after
    # the call returns: pass the result's service_id to #wait.
    def create(domain_name, service_plan:)
      call(HostingCreateRequest.new(domain_name: domain_name, service_plan: service_plan))
    end

    # A hosting by service ID or domain name.
    def get(service_id: nil, domain_name: nil)
      call(HostingGetRequest.new(service_id: service_id, domain_name: domain_name))
    end

    # A hosting by the token #create returned.
    def get_by_token(token)
      call(HostingGetByTokenRequest.new(token: token))
    end

    # The provisioning state of a hosting.
    def status(service_id: nil, domain_name: nil)
      call(HostingStatusRequest.new(service_id: service_id, domain_name: domain_name))
    end

    # Polls #status until the hosting is active and returns its panel access.
    # It polls every 5 seconds for 2 minutes, then every 30 seconds, for at most
    # +timeout+ seconds (provisioning rarely takes more than 30 minutes).
    #
    # A failed provisioning raises OperationError with the failure reason; a
    # timeout raises WaitTimeoutError (its #last is the last HostingStatus).
    #
    #   created = client.hosting.create('example.com', service_plan: 'Linux-Starter')
    #   st = client.hosting.wait(created.service_id)
    #   puts st.panel_address, st.username, st.password
    def wait(service_id, timeout: 30 * 60)
      req = HostingStatusRequest.new(service_id: service_id)
      started = monotonic
      loop do
        st = call(req)
        return st if st.active?

        if st.failed?
          raise operation_error(req, nil, HostingState::FAILED,
                                first_present(st.failure_reason, st.status_message, 'hosting provisioning failed'))
        end

        elapsed = monotonic - started
        if timeout && elapsed >= timeout
          raise WaitTimeoutError.new(http_method: req.http_method, path: req.path, last: st,
                                     message: "hosting #{service_id} is not active after #{timeout}s " \
                                              "(status: #{st.status || 'unknown'})")
        end

        interval = elapsed > 120 ? POLL_SLOW : POLL_FAST
        interval = [interval, timeout - elapsed].min if timeout
        pause(interval)
      end
    end

    private

    def pause(seconds)
      sleep(seconds)
    end

    def monotonic
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end
  end
end
