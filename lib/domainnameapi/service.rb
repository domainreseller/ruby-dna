# frozen_string_literal: true

module DomainNameApi
  # Base class of the services (client.domains, client.dns, ...). A service
  # builds requests, sends them through its client and turns answers that report
  # failure ("success": false) into OperationError.
  class Service
    attr_reader :client

    def initialize(client)
      @client = client
    end

    def inspect
      "#<#{self.class.name}>"
    end

    private

    def call(request)
      @client.call(request)
    end

    def execute(request)
      @client.execute(request)
    end

    # A request from a request object, a Hash of attributes or keyword attributes.
    def build(klass, request, attributes)
      case request
      when nil then klass.new(**attributes)
      when klass
        raise ArgumentError, "pass either a #{klass.request_name} or attributes, not both" unless attributes.empty?

        request
      when Hash then klass.new(**request.transform_keys(&:to_sym), **attributes)
      else raise ArgumentError, "expected a #{klass.request_name} or its attributes, got #{request.class}"
      end
    end

    def operation_error(request, response, code, message)
      OperationError.new(http_method: request.http_method, path: request.path, code: code, api_message: message,
                         correlation_id: response&.correlation_id)
    end

    def first_present(*values)
      values.find { |v| !Util.blank?(v) }
    end

    # An Enumerator over every item of a paged list. It fetches pages as you
    # consume it (first(10) fetches one page) and raises the first error.
    def paginate(request, &fetch)
      Enumerator.new do |out|
        limit = Util.to_int(request.limit)
        limit = PagedRequest::DEFAULT_PAGE_SIZE if limit.nil? || limit <= 0
        skip = Util.to_int(request.skip) || 0
        loop do
          page = fetch.call(request.with_page(skip: skip, limit: limit))
          items = page.items
          items.each { |item| out << item }
          following = skip + items.size
          total = page.total_count.to_i
          break if items.empty?
          break if total.positive? && following >= total
          break if !total.positive? && items.size < limit

          skip = following
        end
      end
    end
  end
end
