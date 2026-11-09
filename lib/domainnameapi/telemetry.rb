# frozen_string_literal: true

require 'json'
require 'net/http'
require 'openssl'
require 'securerandom'
require 'uri'

module DomainNameApi
  # Error and performance reporting to Sentry, ported from php-dna's
  # SharedApiConfigAndUtilsTrait. Mixed into Rest; it reads the client's
  # last request/response state. Telemetry never raises into the caller and
  # never blocks it: events are posted from a background thread.
  module Telemetry
    # The Sentry DSN for ruby-dna; filled in when the Sentry project exists.
    DEFAULT_SENTRY_DSN = ''

    APPLICATION = 'DomainNameAPI-Ruby'

    # Successful calls sampled for performance: 40 out of 1000 (4%).
    PERFORMANCE_SAMPLE_RATE = 40

    # Expected, high-volume errors that are never reported.
    DEFAULT_IGNORED_ERRORS = [
      'Domain not found',
      'ERR_DOMAIN_NOT_FOUND',
      'Reseller not found',
      'Domain is not in updateable status',
      'balance is not sufficient',
      'Price definition not found',
      'TLD is not supported',
      'Invalid API credentials',
      'could not be found',
      'Insufficent reseller balance',
      'Redirect information not found'
    ].freeze

    IP_CACHE_TTL = 512
    MASK_KEY_RE = /auth|epp|password|passwd|secret|token|api[_-]?key/i.freeze

    # Default sender: POST in a background thread with short timeouts.
    # A replacement is any callable taking (url, payload_hash, auth_header,
    # resolve_ip) where resolve_ip says the payload still needs the server's
    # public IP in tags.ip_address.
    THREAD_SENDER = lambda do |url, payload, auth_header, resolve_ip|
      Thread.new do
        begin
          payload['tags']['ip_address'] = Telemetry.server_ip if resolve_ip
          Telemetry.post(url, Telemetry.encode(payload), auth_header)
        rescue StandardError, ScriptError
          nil
        end
      end
      nil
    end

    @ip_cache = nil
    @ip_cache_at = 0.0
    @ip_mutex = Mutex.new

    class << self
      # The server's public IP (api.ipify.org), cached for IP_CACHE_TTL seconds.
      def server_ip
        @ip_mutex.synchronize do
          now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          return @ip_cache if @ip_cache && (now - @ip_cache_at) < IP_CACHE_TTL

          ip = fetch_ip
          if ip
            @ip_cache = ip
            @ip_cache_at = now
            return ip
          end
          'unknown'
        end
      rescue StandardError
        'unknown'
      end

      def fetch_ip
        uri = URI('https://api.ipify.org')
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        http.open_timeout = 1
        http.read_timeout = 2
        body = http.get(uri.request_uri).body.to_s.strip
        body =~ /\A[0-9a-fA-F:.]+\z/ ? body : nil
      rescue StandardError
        nil
      end

      def post(url, body, auth_header)
        return if body.nil? || body.empty?

        uri = URI(url)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = uri.scheme == 'https'
        http.open_timeout = 0.2
        http.read_timeout = 0.5
        req = Net::HTTP::Post.new(uri.request_uri)
        req['Content-Type'] = 'application/json'
        req['X-Sentry-Auth'] = auth_header.sub(/\AX-Sentry-Auth:\s*/, '')
        req.body = body
        http.request(req)
      rescue StandardError
        nil
      end

      # JSON with invalid UTF-8 replaced, so a binary body never drops an event.
      def encode(payload)
        Php.json_encode(Php.scrub_utf8(payload))
      rescue StandardError
        ''
      end

      # Parse https://public[:secret]@host/project into its parts, or nil.
      def parse_dsn(dsn)
        return nil if dsn.nil? || dsn.to_s.strip.empty?

        uri = URI.parse(dsn.to_s.strip)
        project = uri.path.to_s.sub(%r{\A/+}, '')
        return nil if uri.host.nil? || uri.host.empty? || project.empty? || uri.user.nil? || uri.user.empty?

        { host: uri.host, project_id: project, public_key: uri.user, secret_key: uri.password }
      rescue URI::Error
        nil
      end
    end

    # --- public settings --------------------------------------------------

    # Turn error and performance reporting on (default) or off.
    def set_error_reporting_enabled(enabled)
      @error_reporting_enabled = enabled ? true : false
      nil
    end

    # Minimal mode: only error code/message, endpoint, timing, versions and
    # the reseller ID; no request/response data, domain or server IP.
    def set_telemetry_minimal(minimal)
      @telemetry_minimal = minimal ? true : false
      nil
    end

    # Override the Sentry DSN ('' disables telemetry).
    def set_sentry_dsn(dsn)
      @sentry_dsn = dsn.to_s
      nil
    end

    def get_sentry_dsn
      @sentry_dsn
    end

    # Replace the telemetry sender (see THREAD_SENDER).
    def set_telemetry_sender(sender)
      @telemetry_sender = sender
      nil
    end

    private

    def telemetry_minimal?
      @telemetry_minimal ? true : false
    end

    def send_error_to_sentry_async(error)
      do_send_error_to_sentry(error)
    rescue StandardError, ScriptError
      nil
    end

    def do_send_error_to_sentry(error)
      return unless @error_reporting_enabled

      message = error.message.to_s
      return if DEFAULT_IGNORED_ERRORS.any? { |ev| message.include?(ev) }

      dsn = Telemetry.parse_dsn(@sentry_dsn)
      return unless dsn

      elapsed = @start_at ? monotonic - @start_at : 0.0
      classification = build_sentry_classification(error)
      frames = telemetry_frames(error)
      culprit = "#{self.class.name} via #{File.basename(__FILE__)}"

      event = {
        'event_id' => SecureRandom.hex(16),
        'timestamp' => Time.now.utc.strftime('%Y-%m-%dT%H:%M:%SZ'),
        'level' => 'error',
        'logger' => 'ruby',
        'platform' => 'ruby',
        'culprit' => culprit,
        'message' => { 'formatted' => classification['value'] },
        'exception' => {
          'values' => [
            {
              'type' => "#{APPLICATION} Exception",
              'value' => classification['value'],
              'stacktrace' => { 'frames' => frames }
            }
          ]
        },
        'tags' => {
          'handled' => 'yes',
          'level' => 'error',
          'url' => 'NA',
          'transaction' => 'NA',
          'trace_id' => SecureRandom.hex(8),
          'runtime_name' => 'Ruby',
          'runtime_version' => RUBY_VERSION,
          'elapsed_time' => Php.number_format(elapsed, 4),
          'application' => APPLICATION,
          'library_version' => VERSION,
          'ip_address' => '',
          'vhost_user' => telemetry_minimal? ? '' : vhost_user
        },
        'extra' => {
          'request_data' => telemetry_mask(@last_request),
          'response_data' => telemetry_mask(@last_response),
          'openssl_v' => defined?(OpenSSL::OPENSSL_VERSION) ? OpenSSL::OPENSSL_VERSION : 'NA',
          'openssl_n' => defined?(OpenSSL::OPENSSL_VERSION_NUMBER) ? OpenSSL::OPENSSL_VERSION_NUMBER : 'NA'
        }
      }

      event['release'] = VERSION
      event['environment'] = telemetry_environment
      event['tags'] = event['tags'].merge(classification['tags'])
      event['extra']['original_message'] = message
      event['fingerprint'] = classification['fingerprint']

      if telemetry_minimal?
        %w[url ip_address vhost_user ip_value].each { |k| event['tags'].delete(k) }
        lr = @last_request.is_a?(Hash) ? @last_request : {}
        endpoint = begin
          URI.parse(Php.to_s(lr['url'])).path.to_s
        rescue URI::Error
          ''
        end
        event['extra']['request_data'] = { 'method' => Php.to_s(lr['method']), 'endpoint' => endpoint }
        event['extra']['response_data'] = { 'http_code' => Php.to_i(Php.get(@last_response_headers, 'http_code')) }
        event['exception']['values'].each do |value|
          value['stacktrace']['frames'].each { |f| f['filename'] = File.basename(f['filename'].to_s) }
        end
      end

      auth = ['sentry_version=7', "sentry_client=ruby-dna/#{VERSION}", "sentry_key=#{dsn[:public_key]}"]
      auth << "sentry_secret=#{dsn[:secret_key]}" if dsn[:secret_key] && !dsn[:secret_key].empty?
      url = "https://#{dsn[:host]}/api/#{dsn[:project_id]}/store/"
      sender.call(url, event, "X-Sentry-Auth: Sentry #{auth.join(', ')}", !telemetry_minimal?)
    end

    def send_performance_metrics_to_sentry(metrics)
      return unless @error_reporting_enabled

      dsn = Telemetry.parse_dsn(@sentry_dsn)
      return unless dsn

      trace_id = session_trace_id
      root_span_id = SecureRandom.hex(8)
      child_span_id = SecureRandom.hex(8)
      op = 'http.client'

      api_code = nil
      if @last_parsed_response.is_a?(Hash) && @last_parsed_response['Code'].is_a?(String)
        api_code = @last_parsed_response['Code']
      elsif Php.get(@last_response, 'error', 'code').is_a?(String)
        api_code = Php.get(@last_response, 'error', 'code')
      end
      trace_status = map_trace_status(metrics['success'] ? true : false, api_code)

      common = build_common_tags(nil)
      common['api_code'] = api_code.to_s if !api_code.nil? && !common.key?('api_code')
      http_code = Php.to_i(Php.get(@last_response_headers, 'http_code'))
      common['status_code'] = http_code.to_s if http_code != 0

      http_method = 'GET'
      lr = @last_request.is_a?(Hash) ? @last_request : {}
      http_method = Php.to_s(lr['method']) unless Php.empty?(lr['method'])
      call_url = Php.empty?(lr['url']) ? '' : Php.to_s(lr['url'])
      call_host = host_of(call_url.empty? ? @service_url : call_url)

      span_data = { 'http.request.method' => http_method }
      span_data['server.address'] = call_host unless call_host.empty?
      span_data['url.full'] = call_url.split('?', 2).first if !call_url.empty? && !telemetry_minimal?
      span_data['http.response.status_code'] = common['status_code'].to_i if common.key?('status_code')
      description = call_host.empty? ? metrics['operation'].to_s : "#{http_method} https://#{call_host}"

      event = {
        'event_id' => SecureRandom.hex(16),
        'platform' => 'ruby',
        'level' => 'info',
        'type' => 'transaction',
        'transaction' => "API.#{metrics['operation']}",
        'transaction_info' => { 'source' => 'custom' },
        'release' => VERSION,
        'environment' => telemetry_environment,
        'timestamp' => metrics['timestamp'],
        'start_timestamp' => metrics['start_timestamp'],
        'contexts' => {
          'trace' => { 'trace_id' => trace_id, 'span_id' => root_span_id, 'op' => op, 'status' => trace_status },
          'runtime' => { 'name' => 'ruby', 'version' => RUBY_VERSION }
        },
        'tags' => {
          'application' => APPLICATION,
          'library_version' => VERSION,
          'ip_address' => '',
          'vhost_user' => telemetry_minimal? ? '' : vhost_user
        }.merge(common),
        'measurements' => {
          'duration' => { 'value' => metrics['duration'].to_f, 'unit' => 'millisecond' }
        },
        'spans' => [
          {
            'span_id' => child_span_id,
            'parent_span_id' => root_span_id,
            'trace_id' => trace_id,
            'op' => op,
            'description' => description,
            'status' => trace_status,
            'data' => span_data,
            'start_timestamp' => metrics['start_timestamp'],
            'timestamp' => metrics['timestamp']
          }
        ]
      }

      auth = ['sentry_version=7', "sentry_client=ruby-dna/#{VERSION}", "sentry_key=#{dsn[:public_key]}"]
      auth << "sentry_secret=#{dsn[:secret_key]}" if dsn[:secret_key] && !dsn[:secret_key].empty?
      url = "https://#{dsn[:host]}/api/#{dsn[:project_id]}/store/"
      sender.call(url, event, "X-Sentry-Auth: Sentry #{auth.join(', ')}", !telemetry_minimal?)
    rescue StandardError, ScriptError
      nil
    end

    def sender
      @telemetry_sender || THREAD_SENDER
    end

    # Mask credentials (auth/EPP codes, API keys, passwords, tokens) as ***.
    def telemetry_mask(data, depth = 0)
      return '[…]' if depth > 8

      case data
      when Hash
        data.each_with_object({}) do |(k, v), out|
          out[k] = if MASK_KEY_RE.match?(k.to_s)
                     v.nil? || v == '' ? v : '***'
                   else
                     telemetry_mask(v, depth + 1)
                   end
        end
      when Array
        data.map { |v| telemetry_mask(v, depth + 1) }
      else
        data
      end
    end

    # File, line and method names only, oldest first; never arguments.
    def telemetry_frames(error)
      lines = error.backtrace || caller(3) || []
      frames = lines.reverse.map do |line|
        m = line.to_s.match(/\A(.*?):(\d+)(?::in [`'](.*)')?\z/)
        if m
          { 'filename' => File.basename(m[1]), 'lineno' => m[2].to_i, 'function' => m[3].to_s }
        else
          { 'filename' => '', 'lineno' => 0, 'function' => line.to_s }
        end
      end
      frames << { 'filename' => File.basename(__FILE__), 'lineno' => 0, 'function' => '' } if frames.empty?
      frames
    end

    def build_common_tags(error)
      tags = {}
      tags['reseller'] = @reseller_id.to_s unless Php.empty?(@reseller_id)

      domain = Php.get(@last_request, 'payload', 'domainName')
      tags['domain'] = domain if domain.is_a?(String) && !Php.empty?(domain) && !telemetry_minimal?

      tags['operation'] = @last_function.to_s unless Php.empty?(@last_function)
      tags['api_type'] = 'REST'

      if error
        msg = error.message.to_s
        code = error.respond_to?(:code) ? error.code : 0
        if (m = msg.match(/API_(-?\d+)_ERROR/))
          tags['api_code'] = "API_#{m[1]}"
        elsif Php.numeric?(code) && Php.to_i(code) != 0
          tags['api_code'] = "API_#{Php.to_i(code)}"
        end
        tags['status_code'] = Php.to_i(code).to_s if Php.numeric?(code) && Php.to_i(code) != 0
      end
      tags
    end

    def map_trace_status(success, api_code)
      return 'ok' if success
      return 'unknown' if api_code.nil?

      m = api_code.to_s.match(/-?\d+/)
      return 'unknown' unless m

      code = m[0].to_i
      return 'unauthenticated' if [401, 2202].include?(code)
      return 'permission_denied' if code == 403
      return 'not_found' if [404, 510].include?(code)
      return 'deadline_exceeded' if [408, 504].include?(code)
      return 'unavailable' if code == -1
      return 'internal_error' if code >= 500 && code < 600
      return 'invalid_argument' if code >= 400 && code < 500

      'unknown'
    end

    def telemetry_environment
      @service_url.to_s.downcase.include?('ote.') ? 'ote' : 'production'
    end

    def session_trace_id
      @session_trace_id ||= SecureRandom.hex(16)
    end

    def build_sentry_classification(error)
      msg = error.message.to_s
      tags = build_common_tags(error)
      if (m = msg.match(/\b(\d{1,3}(?:\.\d{1,3}){3})\b/))
        tags['ip_value'] = m[1]
      end

      api_code = tags['api_code']
      n = msg.dup
      n = n.sub(/\A\[API_ERROR\]:\s*/i, '')
      n = n.gsub(/API_-?\d+_ERROR\s*-\s*Failed\s*-\s*/i, '')
      n = n.gsub(/\s*\(Reseller Id[^)]*\)\s*/i, '')
      n = n.gsub(/\b\d{1,3}(?:\.\d{1,3}){3}\b/, '{ip}')
      n = n.gsub(/'[^']{0,80}'|"[^"]{0,80}"/, '{v}')
      n = n.gsub(/\b\d{2,}\b/, '{n}')
      n = n.gsub(/\s+/, ' ').strip

      if n.empty?
        n = api_code || error.class.name.split('::').last || 'Exception'
      elsif api_code && !n.start_with?(api_code)
        n = "#{api_code}: #{n}"
      end
      n = "#{n.byteslice(0, 157).scrub('')}..." if n.bytesize > 160

      {
        'value' => n,
        'tags' => tags,
        'fingerprint' => ['dna', APPLICATION, tags['operation'] || 'unknown', n]
      }
    end

    def vhost_user
      ENV['USER'] || ENV['USERNAME'] || ''
    rescue StandardError
      ''
    end

    def host_of(url)
      URI.parse(url.to_s).host.to_s
    rescue URI::Error
      ''
    end

    def monotonic
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end
  end
end
