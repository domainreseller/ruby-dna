# frozen_string_literal: true

require 'json'
require 'securerandom'
require 'time'
require 'uri'

module DomainNameApi
  # Runs the block with a correlation ID: every request sent from it (by any
  # client, on this thread or fiber) carries it in the X-Correlation-ID header.
  # Without it each request gets a random one. The API logs it; quote it when
  # contacting support.
  #
  #   DomainNameApi.with_correlation_id(job.id) { client.domains.renew('example.com', years: 1) }
  def self.with_correlation_id(id)
    previous = Thread.current[:domainnameapi_correlation_id]
    Thread.current[:domainnameapi_correlation_id] = id.to_s.strip.empty? ? nil : id.to_s.strip
    yield
  ensure
    Thread.current[:domainnameapi_correlation_id] = previous
  end

  # Talks to the DomainNameAPI REST API. The services group the operations the
  # same way the dna CLI groups its commands: `dna domain info` is
  # client.domains.info, `dna dns add` is client.dns.add.
  #
  #   client = DomainNameApi::Client.new(reseller_id: '...', api_key: '...', environment: :ote)
  #   client.domains.search('example.com').available?
  #
  # A client is safe to share between threads. Create one and reuse it: it paces
  # requests to stay under the API's rate limits.
  class Client
    # The live environment: real domains, real charges.
    PRODUCTION_URL = 'https://api.domainresellerapi.com'
    # The test environment (Operational Test & Evaluation). It has its own data
    # and its own API key; nothing you do there touches live domains or money.
    OTE_URL = 'https://ote.domainresellerapi.com'

    ENVIRONMENTS = { production: PRODUCTION_URL, ote: OTE_URL }.freeze

    # Environment variables read by Client.from_env: the ones the dna CLI uses.
    ENV_RESELLER_ID = 'DNA_RESELLER_ID'
    ENV_API_KEY = 'DNA_API_KEY'
    ENV_ENVIRONMENT = 'DNA_ENV'      # "production" or "ote"
    ENV_TEST_MODE = 'DNA_TEST_MODE'  # "true" selects OTE
    ENV_BASE_URL = 'DNA_BASE_URL'    # overrides the environment's URL

    METHODS = %w[GET POST PUT DELETE PATCH].freeze

    # Account: balance, profile and balance transactions (dna account).
    attr_reader :account
    # Contacts: reusable contact handles (dna contact).
    attr_reader :contacts
    # Domains: search, register, renew, transfer and manage domains (dna domain).
    attr_reader :domains
    # DNS: zone records of domains on the platform nameservers (dna dns).
    attr_reader :dns
    # DNSSEC: DS records of domains (dna dnssec).
    attr_reader :dnssec
    # SSL: certificates (dna ssl).
    attr_reader :ssl
    # Hosting: web hosting packages and services (dna hosting).
    attr_reader :hosting
    # Orders (dna order).
    attr_reader :orders
    # Products: the catalogue and prices of TLDs, SSL and other products (dna product).
    attr_reader :products

    attr_reader :base_url, :reseller_id, :currency, :retries, :max_retry_wait, :timeout, :open_timeout,
                :user_agent, :transport

    # Accepts :production, :ote and the spellings panels and the other SDKs
    # store: "prod", "live", "test", "sandbox", and test-mode flags ("true",
    # "1", "on", "yes" mean OTE).
    def self.parse_environment(value)
      return value if ENVIRONMENTS.key?(value)
      return :ote if value == true
      return :production if value == false || value.nil?

      case value.to_s.strip.downcase
      when '', 'production', 'prod', 'live', 'false', '0', 'off', 'no' then :production
      when 'ote', 'test', 'testing', 'sandbox', 'true', '1', 'on', 'yes' then :ote
      else raise ConfigurationError, "unknown environment #{value.inspect} (use :production or :ote)"
      end
    end

    # Creates a client from the environment variables the dna CLI uses:
    # DNA_RESELLER_ID, DNA_API_KEY, DNA_ENV ("production" or "ote"; or
    # DNA_TEST_MODE=true) and DNA_BASE_URL. Options given here win.
    def self.from_env(env = nil, **options)
      if env.nil?
        # from_env('DNA_API_KEY' => ...) arrives as keywords with String keys.
        given, options = options.partition { |k, _| k.is_a?(String) }.map(&:to_h)
        env = given.empty? ? ENV : given
      end
      mode = env[ENV_ENVIRONMENT]
      mode = env[ENV_TEST_MODE] if Util.blank?(mode)
      settings = { environment: parse_environment(mode) }
      settings[:base_url] = env[ENV_BASE_URL].strip unless Util.blank?(env[ENV_BASE_URL])
      reseller_id = env[ENV_RESELLER_ID]
      api_key = env[ENV_API_KEY]
      if Util.blank?(reseller_id) || Util.blank?(api_key)
        raise MissingCredentialsError, "#{ENV_RESELLER_ID} and #{ENV_API_KEY} must both be set (find both in the " \
                                       'reseller panel under API settings)'
      end

      new(reseller_id: reseller_id, api_key: api_key, **settings, **options)
    end

    # Find the reseller ID (a UUID) and the API key in the reseller panel under
    # API settings; production and OTE have different keys. Panel login details
    # do not work. Surrounding whitespace is trimmed.
    #
    # Options:
    # environment::    :production (default) or :ote
    # base_url::       a custom base URL (a proxy or a test server); wins over environment
    # timeout::        seconds per HTTP attempt (default 60). Keep it well above 5: over the
    #                  soft quota the API delays responses by up to 5 seconds
    # open_timeout::   seconds to connect (default 10)
    # user_agent::     your product, put in front of the User-Agent: "my-panel/1.4"
    # currency::       currency of search and catalogue prices ("USD", "TRY"); default: the account's
    # retries::        how often a failed request is retried (default 2)
    # max_retry_wait:: the longest Retry-After the client waits for, in seconds (default 30)
    # pacing::         space requests under the rate limits (default true)
    # read_only::      block every request that is not a read (default false)
    # logger::         a Logger: exchanges at debug, retries at warn, failures at error level
    # on_trace::       a callable (or several) receiving a TraceEvent for every request,
    #                  response and retry
    # transport::      the HTTP layer (default NetHTTPTransport.new)
    def initialize(reseller_id:, api_key:, environment: :production, base_url: nil, timeout: 60, open_timeout: 10,
                   user_agent: nil, currency: nil, retries: 2, max_retry_wait: 30, pacing: true, read_only: false,
                   logger: nil, on_trace: nil, transport: nil)
      @reseller_id = reseller_id.to_s.strip
      @api_key = api_key.to_s.strip
      raise MissingCredentialsError if @reseller_id.empty? || @api_key.empty?

      @base_url = normalize_base_url(base_url.nil? ? ENVIRONMENTS.fetch(self.class.parse_environment(environment)) : base_url)
      raise ConfigurationError, 'timeout must not be negative' if timeout.to_f.negative?

      @timeout = timeout
      @open_timeout = open_timeout
      product = user_agent.to_s.strip
      @user_agent = product.empty? ? USER_AGENT : "#{product} #{USER_AGENT}"
      @currency = Util.blank?(currency) ? nil : currency.to_s.strip.upcase
      @retries = [retries.to_i, 0].max
      @max_retry_wait = max_retry_wait.to_f
      @pacer = pacing ? Pacer.new : nil
      @read_only = read_only ? true : false
      @transport = transport || NetHTTPTransport.new
      @tracers = Array(on_trace).compact
      @tracers << logger_tracer(logger) if logger

      @account = AccountService.new(self)
      @contacts = ContactService.new(self)
      @domains = DomainService.new(self)
      @dns = DNSService.new(self)
      @dnssec = DNSSECService.new(self)
      @ssl = SSLService.new(self)
      @hosting = HostingService.new(self)
      @orders = OrderService.new(self)
      @products = ProductService.new(self)
    end

    # :ote when the client talks to the test environment, :production otherwise
    # (also for custom base URLs).
    def environment
      @base_url == OTE_URL ? :ote : :production
    end

    def ote?
      environment == :ote
    end

    def read_only?
      @read_only
    end

    def pacing?
      !@pacer.nil?
    end

    # Validates the request, sends it and returns the decoded result (see
    # BaseRequest.returns). Use it for your own BaseRequest subclasses; the
    # services call it for you.
    #
    # Raises InputError (validation failed; nothing was sent), ReadOnlyError
    # (nothing was sent), APIError (non-2xx answer) or NetworkError.
    def call(request, correlation_id: nil)
      execute(request, correlation_id: correlation_id).value
    end

    # Like #call, but returns the Response: status, headers, raw body, decoded
    # #value, correlation ID, quota, duration and number of attempts.
    #
    # Retries: 429 answers are always retried, honouring Retry-After (the API
    # rejects them before doing anything). Network errors and 502/503/504 are
    # retried only for reads and idempotent writes, so a registration or a
    # renewal is never sent twice.
    def execute(request, correlation_id: nil)
      endpoint, query, body = prepare_parts(request)
      corr = resolve_correlation_id(correlation_id)
      started = monotonic
      attempt = 0

      loop do
        attempt += 1
        sleep_for(@pacer.reserve(endpoint.path)) if @pacer
        prepared = build(endpoint, query, body, corr)
        trace(:request, prepared, endpoint, corr, attempt, body: Util.truncate(body))

        t0 = monotonic
        begin
          raw = @transport.call(prepared)
        rescue StandardError => e
          trace(:response, prepared, endpoint, corr, attempt, duration: monotonic - t0, error: e)
          if endpoint.idempotent? && attempt <= @retries && retryable_network_error?(e)
            wait = backoff(attempt)
            trace(:retry, prepared, endpoint, corr, attempt, wait: wait, error: e)
            sleep_for(wait)
            next
          end
          raise NetworkError.new(http_method: endpoint.http_method, path: endpoint.path, original: e,
                                 safety: endpoint.safety)
        end

        status, headers, text = unpack(raw)
        response = Response.new(status: status, headers: headers, body: text,
                                correlation_id: headers['x-correlation-id'] || corr,
                                quota: Quota.from_headers(headers), duration: monotonic - started,
                                attempts: attempt, request: request)
        trace(:response, prepared, endpoint, corr, attempt, status: status, duration: monotonic - t0,
                                                            body: Util.truncate(text), quota: response.quota)

        if response.success?
          response.value = request.decode(request.class.returns.nil? ? response.data : response.data!)
          return response
        end

        retry_it = status == 429 || (endpoint.idempotent? && [502, 503, 504].include?(status))
        if retry_it && attempt <= @retries
          wait = retry_after(headers, attempt)
          if wait <= @max_retry_wait
            trace(:retry, prepared, endpoint, corr, attempt, status: status, wait: wait)
            sleep_for(wait)
            next
          end
        end

        headers = headers.merge('x-correlation-id' => corr) if Util.blank?(headers['x-correlation-id'])
        raise APIError.from_response(http_method: endpoint.http_method, path: endpoint.path, status: status,
                                     headers: headers, body: text)
      end
    end

    # Validates the request and returns the PreparedRequest #execute would send,
    # without sending it: to log or review a billable request first. It carries
    # your credentials in its headers.
    def prepare(request, correlation_id: nil)
      endpoint, query, body = prepare_parts(request)
      build(endpoint, query, body, resolve_correlation_id(correlation_id))
    end

    # See DomainNameApi.with_correlation_id.
    def with_correlation_id(id, &block)
      DomainNameApi.with_correlation_id(id, &block)
    end

    def inspect
      "#<DomainNameApi::Client #{environment} #{@base_url} reseller_id=#{@reseller_id.inspect}" \
        "#{@read_only ? ' read_only' : ''}>"
    end
    alias to_s inspect

    private

    def prepare_parts(request)
      unless request.is_a?(BaseRequest)
        raise ArgumentError, "expected a DomainNameApi::BaseRequest, got #{request.nil? ? 'nil' : request.class}"
      end

      request.validate!
      endpoint = request.endpoint
      method = endpoint.http_method.to_s.strip.upcase
      method = 'GET' if method.empty?
      unless METHODS.include?(method)
        raise ArgumentError, "#{request.class.request_name}: unsupported HTTP method #{endpoint.http_method.inspect}"
      end

      path = endpoint.path.to_s
      path = "/#{path}" unless path.start_with?('/')
      endpoint = Endpoint.new(http_method: method, path: path, safety: endpoint.safety, idempotent: endpoint.idempotent)
      if @read_only && endpoint.safety != Safety::READ
        raise ReadOnlyError.new(request.class.request_name, method, path, endpoint.safety)
      end

      body = request.body
      [endpoint, Query.from(request.query), body.nil? ? nil : JSON.generate(Util.wire(body))]
    end

    def build(endpoint, query, body, corr)
      url = @base_url + endpoint.path
      url += "?#{query}" unless query.empty?
      headers = {
        'Accept' => 'application/json',
        'User-Agent' => @user_agent,
        'X-API-KEY' => @api_key,
        '__reseller' => @reseller_id,
        'X-Correlation-ID' => corr
      }
      headers['Content-Type'] = 'application/json' unless body.nil?
      PreparedRequest.new(http_method: endpoint.http_method, url: url, headers: headers, body: body,
                          timeout: @timeout, open_timeout: @open_timeout)
    end

    def unpack(raw)
      status, headers, body =
        case raw
        when Hash then [raw[:status] || raw['status'], raw[:headers] || raw['headers'], raw[:body] || raw['body']]
        when Array then raw
        else [raw.status, raw.headers, raw.body]
        end
      normalized = {}
      (headers || {}).each do |k, v|
        normalized[k.to_s.downcase] = v.is_a?(Array) ? v.join(', ') : v.to_s
      end
      [Integer(status), normalized, body.to_s]
    end

    def resolve_correlation_id(given)
      id = given.to_s.strip
      id = Thread.current[:domainnameapi_correlation_id].to_s if id.empty?
      id.empty? ? SecureRandom.hex(16) : id
    end

    def retryable_network_error?(error)
      return false if error.is_a?(OpenSSL::SSL::SSLError)
      return error.retryable? if error.respond_to?(:retryable?)

      error.is_a?(Timeout::Error) || error.is_a?(SocketError) || error.is_a?(SystemCallError) ||
        error.is_a?(IOError) || error.is_a?(EOFError) || error.is_a?(Net::HTTPBadResponse)
    end

    def backoff(attempt)
      (0.5 * (2**(attempt - 1))) + (rand * 0.25)
    end

    def retry_after(headers, attempt)
      raw = headers['retry-after'].to_s.strip
      unless raw.empty?
        seconds = Util.to_float(raw)
        return seconds + 0.05 if seconds && seconds >= 0

        begin
          wait = Time.httpdate(raw) - Time.now
          return wait if wait.positive?
        rescue ArgumentError
          nil
        end
      end
      backoff(attempt)
    end

    def sleep_for(seconds)
      sleep(seconds) if seconds.to_f.positive?
    end

    def monotonic
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end

    def trace(kind, prepared, endpoint, corr, attempt, **fields)
      return if @tracers.empty?

      event = TraceEvent.new(kind: kind, http_method: endpoint.http_method, url: prepared.url,
                             safety: endpoint.safety, correlation_id: corr, attempt: attempt, **fields)
      @tracers.each { |t| t.call(event) }
    end

    def logger_tracer(logger)
      lambda do |ev|
        head = "dna: #{ev.http_method} #{ev.url} attempt=#{ev.attempt} correlation_id=#{ev.correlation_id}"
        case ev.kind
        when :request
          logger.debug("#{head} request")
        when :retry
          reason = ev.error ? "error=#{ev.error.class}: #{ev.error.message}" : "status=#{ev.status}"
          logger.warn("#{head} retrying in #{format('%.2f', ev.wait)}s #{reason}")
        when :response
          took = "duration=#{(ev.duration.to_f * 1000).round}ms"
          if ev.error
            logger.error("#{head} failed #{took} error=#{ev.error.class}: #{ev.error.message}")
          elsif ev.status.to_i >= 400
            logger.error("#{head} error response status=#{ev.status} #{took}")
          else
            logger.debug("#{head} response status=#{ev.status} #{took}")
          end
        end
      end
    end

    def normalize_base_url(raw)
      text = raw.to_s.strip.sub(%r{/+\z}, '')
      uri = URI.parse(text)
      unless %w[http https].include?(uri.scheme) && !Util.blank?(uri.host)
        raise ConfigurationError, "invalid base URL #{raw.inspect} (want e.g. #{PRODUCTION_URL})"
      end

      text
    rescue URI::InvalidURIError
      raise ConfigurationError, "invalid base URL #{raw.inspect} (want e.g. #{PRODUCTION_URL})"
    end
  end
end
