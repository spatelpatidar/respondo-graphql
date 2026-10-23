# frozen_string_literal: true

require "time"

module RespondoGraphql
  # Builds a GraphQL-spec response envelope.
  #
  #   {
  #     errors:     [ { message:, extensions: { code:, http: { status: } } } ],  # only on failure
  #     data:       Hash | nil,
  #     extensions: { message:, timestamp:, ...meta }
  #   }
  #
  # On failure `data` is null and `errors` always starts with a summary entry
  # carrying the helper's message, followed by one entry per field-level error,
  # so `errors[0].message` is always safe to show to a user.
  #
  # The extensions block always contains the message and an ISO8601 timestamp,
  # plus request_id (config.include_request_id), config.default_meta,
  # caller-supplied meta, pagination, and the helper's code/status.
  class ResponseBuilder
    # @param success    [Boolean]
    # @param data       [Object]   anything — serialized automatically
    # @param message    [String]
    # @param meta       [Hash]     caller-supplied extra extensions (merged in)
    # @param errors     [Hash]     field-level errors, e.g. { email: ["is invalid"] }
    # @param pagination [Hash, nil] plain pagination hash supplied by the caller
    # @param request    [Object]   ActionDispatch::Request (for request_id)
    def initialize(success:, data: nil, message: nil, meta: {}, errors: nil,
                   pagination: nil, request: nil)
      @success    = success
      @raw_data   = data
      @message    = message
      @extra_meta = meta || {}
      @errors     = errors
      @pagination = pagination
      @request    = request
    end

    # @return [Hash] the complete GraphQL response payload
    def build
      payload = {}

      errors = build_errors
      payload[:errors] = errors unless errors.empty?

      payload[:data]       = build_data
      payload[:extensions] = { message: resolve_message }.merge(build_meta)

      apply_camelize(payload)
    end

    private

    def resolve_message
      return @message if @message && !@message.empty?

      @success ? RespondoGraphql.config.default_success_message : RespondoGraphql.config.default_error_message
    end

    # GraphQL requires `data` to be a map (or null when execution failed).
    def build_data
      return nil unless @success

      data = Serializer.call(@raw_data)
      return data if data.nil? || data.is_a?(Hash)

      { RespondoGraphql.config.data_key.to_sym => data }
    end

    def build_errors
      return [] if @success

      [{ message: resolve_message, extensions: error_extensions }] + field_error_entries
    end

    # One entry per field message, e.g. { email: ["is invalid"] } becomes
    #   { message: "email is invalid", extensions: { code: ..., field: "email" } }
    def field_error_entries
      return [] unless @errors.is_a?(Hash)

      @errors.flat_map do |field, messages|
        Array(messages).map do |text|
          label = field.to_s == "base" ? text.to_s : "#{field} #{text}"
          { message: label, extensions: error_extensions.merge(field: field.to_s) }
        end
      end
    end

    def error_extensions
      extensions = { code: error_code }
      extensions[:http] = { status: http_status } if http_status
      extensions
    end

    # A String `code:` passed to render_graphql_error is already machine-readable and
    # is used as-is; otherwise the status symbol is used, e.g. :not_found
    # becomes "NOT_FOUND". Falls back to "ERROR" when neither is available.
    def error_code
      custom = @extra_meta[:code]
      return custom if custom.is_a?(String) && !custom.empty?

      status = @extra_meta[:status]
      status.is_a?(Symbol) || status.is_a?(String) ? status.to_s.upcase : "ERROR"
    end

    # The numeric HTTP status the helper stands for, when known.
    def http_status
      [@extra_meta[:code], @extra_meta[:status]].find { |value| value.is_a?(Integer) }
    end

    def build_meta
      config = RespondoGraphql.config
      meta   = {}

      # 1. Request ID first (opt-in)
      meta[:request_id] = @request.request_id if config.include_request_id && @request.respond_to?(:request_id)

      # 2. Timestamp second
      meta[:timestamp] = current_timestamp

      # 3. Global defaults (lowest priority), then caller-supplied meta
      meta.merge!(config.default_meta)
      meta.merge!(@extra_meta)

      # 4. Pagination — plain hash from the caller
      meta[:pagination] = @pagination if @pagination.is_a?(Hash) && !@pagination.empty?

      # 5. Re-pin code and status to the very end
      code   = meta.delete(:code)
      status = meta.delete(:status)
      meta[:code]   = code   if code
      meta[:status] = status if status

      meta
    end

    def current_timestamp
      if Time.respond_to?(:current)
        Time.current.iso8601
      else
        Time.now.utc.iso8601
      end
    end

    def apply_camelize(hash)
      return hash unless RespondoGraphql.config.camelize_keys

      camelize_hash(hash)
    end

    def camelize_hash(obj)
      case obj
      when Hash
        obj.each_with_object({}) { |(key, value), memo| memo[camelize_key(key)] = camelize_hash(value) }
      when Array
        obj.map { |item| camelize_hash(item) }
      else
        obj
      end
    end

    def camelize_key(key)
      key.to_s.gsub(/_([a-z])/) { Regexp.last_match(1).upcase }.to_sym
    end
  end
end
