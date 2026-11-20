# frozen_string_literal: true

require 'json'
require 'timeout'

module DomainNameApi
  # Error codes. The API's own codes look like "Dna.DomainService:Domain:10007"
  # (the full catalogue is at https://www.domainnameapi.com/docs/reference/errors.md);
  # the others are set by this gem when the API sends none.
  #
  # Branch on codes, not on messages: messages are localised.
  module ErrorCode
    # The reseller ID is unknown, inactive or suspended in this environment.
    INVALID_RESELLER = 'INVALID_RESELLER'
    # The API key does not match (production and OTE keys differ).
    INVALID_API_KEY = 'INVALID_API_KEY'
    # The X-API-KEY header was empty.
    MISSING_API_KEY = 'MISSING_API_KEY'
    # The __reseller header was empty.
    MISSING_RESELLER_ID = 'MISSING_RESELLER_ID'
    # Sub-reseller accounts cannot use the API.
    SUBRESELLER_NOT_ALLOWED = 'SUBRESELLER_NOT_ALLOWED'
    # Any other 401.
    UNAUTHORIZED = 'UNAUTHORIZED'
    # 429, still rate limited after the automatic retries.
    RATE_LIMITED = 'RATE_LIMITED'
    # Otherwise the code is "HTTP_<status>", e.g. "HTTP_502".

    # The domain does not exist, or is not yours.
    DOMAIN_NOT_FOUND = 'Dna.DomainService:Domain:10007'
    # The TLD has no WHOIS privacy.
    PRIVACY_NOT_SUPPORTED = 'Dna.DomainService:Domain:10040'
    # The domain has no URL forwarding.
    FORWARDING_NOT_FOUND = 'Dna.DomainService:Domain:10061'
    # Registered at the registry, not recorded yet.
    REGISTERED_NOT_RECORDED = 'Dna.DomainService:Domain:10058'
    # Renewed at the registry, not recorded yet.
    RENEWED_NOT_RECORDED = 'Dna.DomainService:Domain:10059'
    # Transfer started at the registry, not recorded yet.
    TRANSFER_NOT_RECORDED = 'Dna.DomainService:Domain:10060'
    # Sent to the certificate authority.
    SSL_SENT_TO_CA = 'Dna.SslService:Ssl:10053'
    # The certificate authority's answer is unknown.
    SSL_OUTCOME_UNVERIFIED = 'Dna.SslService:Ssl:10054'
    # There is no verification pending for the contact.
    VERIFICATION_NOT_PENDING = 'Dna.DomainService:Contact:Verification:10005'
    # The contact is already verified.
    VERIFICATION_ALREADY_DONE = 'Dna.DomainService:Contact:Verification:10003'

    # Codes meaning "the registry or CA may already have done it": never repeat
    # the request before checking the object's state.
    OUTCOME_UNKNOWN = [
      REGISTERED_NOT_RECORDED, RENEWED_NOT_RECORDED, TRANSFER_NOT_RECORDED, SSL_SENT_TO_CA, SSL_OUTCOME_UNVERIFIED
    ].freeze

    # Codes meaning "the balance is too low".
    INSUFFICIENT_BALANCE = %w[Dna.DomainService:Deposit:10001 Dna.DepositService:Deposit:10002].freeze
  end

  # Coarse, stable classification of failures (Error#kind). Branch on it, or on
  # the predicates (Error#not_found?, Error#auth?, ...), instead of on messages.
  module ErrorKind
    AUTH = :auth                   # wrong or missing credentials, the other environment's key, a suspended reseller
    NOT_FOUND = :not_found         # the object does not exist or is not yours (404)
    VALIDATION = :validation       # the API rejected the input (400, 422)
    REJECTED = :rejected           # a business rule refused it (402, 403) or the API answered "success": false
    CONFLICT = :conflict           # the object is in a conflicting state (409)
    RATE_LIMITED = :rate_limited   # still rate limited after the automatic retries (429)
    SERVER = :server               # the API failed (5xx); often transient
    NETWORK = :network             # the request did not complete: DNS, TLS, timeout, reset
    INVALID_INPUT = :invalid_input # the request failed its own validation; nothing was sent
    READ_ONLY = :read_only         # a read-only client blocked a change; nothing was sent
    UNKNOWN = :unknown             # anything else

    ALL = [AUTH, NOT_FOUND, VALIDATION, REJECTED, CONFLICT, RATE_LIMITED, SERVER, NETWORK, INVALID_INPUT,
           READ_ONLY, UNKNOWN].freeze
  end

  # Base class of every error this gem raises.
  #
  #   rescue DomainNameApi::Error => e
  #     e.kind              # => :not_found
  #     e.not_found?        # => true
  #     e.outcome_unknown?  # may a billable request have gone through anyway?
  class Error < StandardError
    # The ErrorKind of the failure.
    def kind
      ErrorKind::UNKNOWN
    end

    # The API's error code, or nil.
    def code
      nil
    end

    # Whether the error carries this code (see ErrorCode).
    def code?(value)
      !code.nil? && code == value.to_s
    end

    def not_found?
      kind == ErrorKind::NOT_FOUND
    end

    def auth?
      kind == ErrorKind::AUTH
    end

    def rate_limited?
      kind == ErrorKind::RATE_LIMITED
    end

    def insufficient_balance?
      false
    end

    # Whether a failed request may still have been carried out. Check the state
    # (e.g. client.domains.info) before sending such a request again: repeating a
    # registration or renewal blindly can charge twice.
    def outcome_unknown?
      false
    end

    # Whether sending the same request again later may succeed.
    def retryable?
      false
    end
  end

  # The client was configured wrongly: an unknown environment, an invalid base URL.
  class ConfigurationError < Error; end

  # The reseller ID or the API key is empty.
  class MissingCredentialsError < ConfigurationError
    def initialize(message = 'the reseller ID and the API key are required (find both in the reseller panel under ' \
                             'API settings, or set DNA_RESELLER_ID and DNA_API_KEY)')
      super
    end

    def kind
      ErrorKind::AUTH
    end
  end

  # One problem with one input field.
  FieldError = Struct.new(:field, :message) do
    def to_s
      field.to_s.empty? ? message.to_s : "#{field}: #{message}"
    end
  end

  # The request failed its own validation (BaseRequest#validate). Nothing was sent.
  class InputError < Error
    # The request class name, e.g. "DomainRenewRequest".
    attr_reader :request
    # The problems, as FieldError values.
    attr_reader :fields

    def initialize(request, fields)
      @request = request.to_s.empty? ? 'request' : request.to_s
      @fields = fields.freeze
      super("invalid #{@request}: #{fields.map(&:to_s).join('; ')}")
    end

    def kind
      ErrorKind::INVALID_INPUT
    end
  end

  # A read-only client (read_only: true) blocked a request that would change
  # something. Nothing was sent.
  class ReadOnlyError < Error
    attr_reader :request, :http_method, :path, :safety

    def initialize(request, http_method, path, safety)
      @request = request
      @http_method = http_method
      @path = path
      @safety = safety
      super("blocked by read-only mode: #{request} (#{http_method} #{path}) is a #{safety} request")
    end

    def kind
      ErrorKind::READ_ONLY
    end
  end

  # The API answered with a non-2xx status.
  #
  #   rescue DomainNameApi::APIError => e
  #     e.status          # => 404
  #     e.code            # => "Dna.DomainService:Domain:10007"
  #     e.api_message     # the API's message
  #     e.hint            # what to do about it, or nil
  #     e.correlation_id  # quote it when contacting support
  class APIError < Error
    # HTTP status.
    attr_reader :status
    # The API's error code (see ErrorCode), or one this gem sets when the API sends none.
    attr_reader :code
    # The API's message.
    attr_reader :api_message
    # The API's longer explanation, when it sends one.
    attr_reader :details
    # Per-field problems of a validation error, as FieldError values.
    attr_reader :fields
    # Extra facts some errors carry, e.g. the balances of an insufficient-balance error.
    attr_reader :data
    # Identifies the request; quote it when contacting support.
    attr_reader :correlation_id
    # Seconds the API asked to wait (429), or nil.
    attr_reader :retry_after
    # The request.
    attr_reader :http_method, :path
    # The raw response body and headers (lower-case names).
    attr_reader :body, :headers

    BOILERPLATE = /exception of type '[^']*' was thrown/i.freeze

    STATUS_TEXT = {
      400 => 'bad request', 401 => 'unauthorized', 402 => 'payment required', 403 => 'forbidden',
      404 => 'not found', 405 => 'method not allowed', 406 => 'not acceptable', 408 => 'request timeout',
      409 => 'conflict', 410 => 'gone', 413 => 'request entity too large', 415 => 'unsupported media type',
      418 => "i'm a teapot", 422 => 'unprocessable entity', 423 => 'locked', 429 => 'too many requests',
      500 => 'internal server error', 501 => 'not implemented', 502 => 'bad gateway',
      503 => 'service unavailable', 504 => 'gateway timeout'
    }.freeze

    # Builds the error from a response, normalising the shapes the API answers with.
    # @api private
    def self.from_response(http_method:, path:, status:, headers: {}, body: '')
      attrs = { http_method: http_method, path: path, status: status, headers: headers, body: body.to_s,
                correlation_id: headers['x-correlation-id'], fields: [], data: {} }
      text = body.to_s.strip

      case status
      when 301, 302
        # The gateway redirects to /Error/Suspend when the __reseller value is
        # unknown, inactive or suspended.
        return new(**attrs, code: ErrorCode::INVALID_RESELLER,
                            api_message: 'authentication failed: the reseller ID is unknown, inactive or suspended')
      when 429
        message = +'rate limit exceeded'
        retry_after = nil
        if (raw = headers['retry-after']) && (seconds = Util.to_float(raw))
          retry_after = seconds
          message << " (retry after #{raw.strip}s)"
        end
        return new(**attrs, code: ErrorCode::RATE_LIMITED, api_message: message, retry_after: retry_after)
      end

      code = nil
      message = nil
      details = nil
      if text.start_with?('{') && (json = parse_json(text)).is_a?(Hash)
        info = json['error'].is_a?(Hash) ? json['error'] : json
        code = info['code'].to_s unless info['code'].nil?
        message = info['message'].to_s unless info['message'].nil?
        details = info['details'].to_s unless info['details'].nil?
        attrs[:data] = info['data'] if info['data'].is_a?(Hash)
        Array(info['validationErrors']).each do |v|
          next unless v.is_a?(Hash)

          members = Array(v['members']).map { |m| m.to_s.delete_prefix('$.') }
          attrs[:fields] << FieldError.new(members.join(','), v['message'].to_s)
        end
      elsif !text.empty? && !text.start_with?('<')
        message = text # 401 bodies are plain text; HTML error pages are dropped.
      end

      code = unauthorized_code(message) if status == 401 && Util.blank?(code)

      # Replace boilerplate and code echoes with the details text.
      if message && (message.match?(BOILERPLATE) || (!message.empty? && message == code))
        d = details.to_s.strip.delete_prefix('Dna ').strip
        message = !d.empty? && !d.match?(BOILERPLATE) && d != code ? d : 'the operation could not be completed'
      end
      code = "HTTP_#{status}" if Util.blank?(code)
      message = STATUS_TEXT.fetch(status, 'unexpected status') if Util.blank?(message)

      new(**attrs, code: code, api_message: message, details: details)
    end

    def self.parse_json(text)
      JSON.parse(text)
    rescue JSON::ParserError
      nil
    end

    def self.unauthorized_code(message)
      lower = message.to_s.downcase
      if lower.include?('api key is missing') then ErrorCode::MISSING_API_KEY
      elsif lower.include?('resellerid is missing') then ErrorCode::MISSING_RESELLER_ID
      elsif lower.include?('invalid api key') then ErrorCode::INVALID_API_KEY
      elsif lower.include?('authorisation') || lower.include?('authorization') then ErrorCode::SUBRESELLER_NOT_ALLOWED
      else ErrorCode::UNAUTHORIZED
      end
    end
    private_class_method :parse_json, :unauthorized_code

    def initialize(status:, code:, api_message:, details: nil, fields: [], data: {}, correlation_id: nil,
                   retry_after: nil, http_method: nil, path: nil, body: '', headers: {})
      @status = status
      @code = code
      @api_message = api_message
      @details = details
      @fields = fields.freeze
      @data = data.freeze
      @correlation_id = correlation_id
      @retry_after = retry_after
      @http_method = http_method
      @path = path
      @body = body
      @headers = headers
      super(build_message)
    end

    def kind
      case status
      when 401, 301, 302 then ErrorKind::AUTH
      when 404 then ErrorKind::NOT_FOUND
      when 400, 422 then ErrorKind::VALIDATION
      when 402, 403 then ErrorKind::REJECTED
      when 409 then ErrorKind::CONFLICT
      when 429 then ErrorKind::RATE_LIMITED
      else status.to_i >= 500 ? ErrorKind::SERVER : ErrorKind::UNKNOWN
      end
    end

    # Rate limits and server errors, unless the API says the operation may
    # already have happened (see #outcome_unknown?).
    def retryable?
      return false if outcome_unknown?

      kind == ErrorKind::RATE_LIMITED || (kind == ErrorKind::SERVER && status != 501)
    end

    # Whether the API said the registry or certificate authority may already have
    # carried out the operation. Check the object's state (domains.info,
    # ssl.status, account.transactions) before repeating it.
    def outcome_unknown?
      ErrorCode::OUTCOME_UNKNOWN.include?(code)
    end

    def insufficient_balance?
      status == 402 || ErrorCode::INSUFFICIENT_BALANCE.include?(code)
    end

    # A short suggestion for fixing the error, or nil.
    def hint
      case code
      when ErrorCode::INVALID_RESELLER
        return 'The reseller ID is unknown, inactive or suspended in this environment. Check the reseller ID ' \
               "(a UUID from the panel's API settings) and the environment: option."
      when ErrorCode::INVALID_API_KEY
        return 'Production and OTE use different API keys. Make sure the key belongs to the environment the ' \
               'client uses.'
      when ErrorCode::MISSING_API_KEY, ErrorCode::MISSING_RESELLER_ID
        return 'Pass both reseller_id: and api_key: to DomainNameApi::Client.new.'
      when ErrorCode::SUBRESELLER_NOT_ALLOWED
        return "Sub-reseller accounts cannot use the API. Use the main reseller's credentials."
      when ErrorCode::RATE_LIMITED
        return 'The API allows 5 requests/second per key (2/s for domain search). Slow down, or keep pacing on ' \
               '(the default).'
      end
      if outcome_unknown?
        return "The operation may already have been carried out. Check the object's state before sending the " \
               'request again.'
      end

      case kind
      when ErrorKind::NOT_FOUND
        'Check the spelling and the environment: production and OTE hold different domains. ' \
          'client.domains.list shows what this account holds.'
      when ErrorKind::SERVER
        return nil if Util.blank?(correlation_id)

        "Server-side failure. If it persists, contact support and quote correlation ID #{correlation_id}."
      end
    end

    private

    def build_message
      text = +''
      text << "#{http_method} #{path}: " if http_method
      text << "#{status} #{code}: #{api_message}"
      fields.each { |f| text << "; #{f}" }
      text
    end
  end

  # The API answered 2xx but reported that the operation did not happen
  # ("success": false), for example the registration of a domain that is taken.
  class OperationError < Error
    attr_reader :code, :api_message, :correlation_id, :http_method, :path

    def initialize(http_method:, path:, code: nil, api_message: nil, correlation_id: nil)
      @http_method = http_method
      @path = path
      @code = Util.blank?(code) ? nil : code.to_s.strip
      @api_message = Util.blank?(api_message) ? nil : api_message.to_s.strip
      @correlation_id = correlation_id
      text = @api_message || 'the API reported that the operation failed'
      text = "#{@code}: #{text}" if @code
      super("#{http_method} #{path}: #{text}")
    end

    def kind
      ErrorKind::REJECTED
    end
  end

  # The request did not complete: DNS, TLS, proxy, timeout or connection reset.
  class NetworkError < Error
    # The request.
    attr_reader :http_method, :path
    # The exception the HTTP layer raised.
    attr_reader :original
    # The safety class of the request (see Safety).
    attr_reader :safety

    def initialize(http_method:, path:, original:, safety: Safety::READ, message: nil)
      @http_method = http_method
      @path = path
      @original = original
      @safety = safety
      super(message || "#{http_method} #{path}: #{original.class}: #{original.message}")
    end

    def kind
      ErrorKind::NETWORK
    end

    # Whether the request timed out.
    def timeout?
      original.is_a?(Timeout::Error) || original.is_a?(Errno::ETIMEDOUT)
    end

    # Whether the request may have reached the API before it failed. Reads are
    # harmless to repeat; check the state before repeating anything else.
    def outcome_unknown?
      safety != Safety::READ
    end

    def retryable?
      !outcome_unknown?
    end
  end

  # A wait (hosting.wait) ran out of time before the object reached its state.
  class WaitTimeoutError < NetworkError
    # The last state seen, e.g. the HostingStatus.
    attr_reader :last

    def initialize(http_method:, path:, message:, last: nil)
      @last = last
      super(http_method: http_method, path: path, original: Timeout::Error.new(message), message: message)
    end

    def timeout?
      true
    end
  end

  # A successful response could not be decoded.
  class DecodeError < Error
    # The Response.
    attr_reader :response

    def initialize(message, response = nil)
      @response = response
      super(message)
    end
  end
end
