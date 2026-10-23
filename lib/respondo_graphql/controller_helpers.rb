# frozen_string_literal: true

module RespondoGraphql
  # Mixed into Rails controllers to render GraphQL-spec responses with
  # expressive, status-aware helpers.
  #
  # Every public and private method here is prefixed (render_graphql_*, ...) so
  # this module can sit in the same controller as the respondo (JSON) gem's
  # helpers: render_ok is always JSON, render_graphql_ok is always GraphQL, and
  # neither depends on include order.
  #
  # Success helpers (2xx) — accept data:, message:, meta:, pagination:
  #   render_graphql_ok, render_graphql_created, render_graphql_accepted, render_graphql_non_authoritative,
  #   render_graphql_partial_content, render_graphql_multi_status, render_graphql_already_reported,
  #   render_graphql_im_used
  #
  # Success helpers (2xx) without a payload — accept message:, meta:, pagination:
  #   render_graphql_no_content, render_graphql_reset_content
  #
  # Error helpers (4xx / 5xx) — accept message:, errors:, meta:
  #   render_graphql_bad_request, render_graphql_unauthorized, render_graphql_payment_required,
  #   render_graphql_forbidden, render_graphql_not_found, render_graphql_method_not_allowed,
  #   render_graphql_not_acceptable, render_graphql_proxy_auth_required, render_graphql_request_timeout,
  #   render_graphql_conflict, render_graphql_gone, render_graphql_length_required,
  #   render_graphql_precondition_failed, render_graphql_payload_too_large, render_graphql_uri_too_long,
  #   render_graphql_unsupported_media_type, render_graphql_range_not_satisfiable,
  #   render_graphql_expectation_failed, render_graphql_im_a_teapot, render_graphql_misdirected_request,
  #   render_graphql_unprocessable, render_graphql_locked, render_graphql_failed_dependency,
  #   render_graphql_too_early, render_graphql_upgrade_required, render_graphql_precondition_required,
  #   render_graphql_too_many_requests, render_graphql_request_header_fields_too_large,
  #   render_graphql_unavailable_for_legal_reasons, render_graphql_server_error,
  #   render_graphql_not_implemented, render_graphql_bad_gateway, render_graphql_service_unavailable,
  #   render_graphql_gateway_timeout, render_graphql_http_version_not_supported,
  #   render_graphql_variant_also_negotiates, render_graphql_insufficient_storage,
  #   render_graphql_loop_detected, render_graphql_not_extended,
  #   render_graphql_network_authentication_required
  #
  # 1xx (informational) and 3xx (redirect) helpers are intentionally not
  # provided: they are transport-level and have no meaning in a GraphQL response.
  module ControllerHelpers
    # name => [numeric code, Rails status symbol, default message, takes data?]
    SUCCESS_HELPERS = {
      ok:                { code: 200, status: :ok,                            message: nil,                                       data: true  },
      created:           { code: 201, status: :created,                       message: "Created successfully",                    data: true  },
      accepted:          { code: 202, status: :accepted,                      message: "Request accepted and is being processed", data: true  },
      non_authoritative: { code: 203, status: :non_authoritative_information, message: "Non-authoritative information",           data: true  },
      no_content:        { code: 204, status: :no_content,                    message: "Deleted successfully",                    data: false },
      reset_content:     { code: 205, status: :reset_content,                 message: "Reset content",                           data: false },
      partial_content:   { code: 206, status: :partial_content,               message: "Partial content returned",                data: true  },
      multi_status:      { code: 207, status: :multi_status,                  message: "Multi-status response",                   data: true  },
      already_reported:  { code: 208, status: :already_reported,              message: "Already reported",                        data: true  },
      im_used:           { code: 226, status: :im_used,                       message: "IM used",                                 data: true  }
    }.freeze

    # name => [numeric code, Rails status symbol, default message]
    ERROR_HELPERS = {
      bad_request:                     { code: 400, status: :bad_request,                     message: "Bad request" },
      unauthorized:                    { code: 401, status: :unauthorized,                    message: "Unauthorized" },
      payment_required:                { code: 402, status: :payment_required,                message: "Payment required to access this resource" },
      forbidden:                       { code: 403, status: :forbidden,                       message: "You do not have permission to perform this action" },
      not_found:                       { code: 404, status: :not_found,                       message: "Resource not found" },
      method_not_allowed:              { code: 405, status: :method_not_allowed,              message: "HTTP method not allowed" },
      not_acceptable:                  { code: 406, status: :not_acceptable,                  message: "Requested format not acceptable" },
      proxy_auth_required:             { code: 407, status: :proxy_authentication_required,   message: "Proxy authentication required" },
      request_timeout:                 { code: 408, status: :request_timeout,                 message: "Request timed out" },
      conflict:                        { code: 409, status: :conflict,                        message: "Resource conflict" },
      gone:                            { code: 410, status: :gone,                            message: "Resource no longer available" },
      length_required:                 { code: 411, status: :length_required,                 message: "Content-Length header required" },
      precondition_failed:             { code: 412, status: :precondition_failed,             message: "Precondition failed" },
      payload_too_large:               { code: 413, status: :payload_too_large,               message: "Payload too large" },
      uri_too_long:                    { code: 414, status: :uri_too_long,                    message: "URI too long" },
      unsupported_media_type:          { code: 415, status: :unsupported_media_type,          message: "Unsupported media type" },
      range_not_satisfiable:           { code: 416, status: :range_not_satisfiable,           message: "Range not satisfiable" },
      expectation_failed:              { code: 417, status: :expectation_failed,              message: "Expectation failed" },
      im_a_teapot:                     { code: 418, status: :im_a_teapot,                     message: "I'm a teapot" },
      misdirected_request:             { code: 421, status: :misdirected_request,             message: "Misdirected request" },
      unprocessable:                   { code: 422, status: :unprocessable_content,           message: "Validation failed" },
      locked:                          { code: 423, status: :locked,                          message: "Resource is locked" },
      failed_dependency:               { code: 424, status: :failed_dependency,               message: "Failed dependency" },
      too_early:                       { code: 425, status: :too_early,                       message: "Too early" },
      upgrade_required:                { code: 426, status: :upgrade_required,                message: "Upgrade required" },
      precondition_required:           { code: 428, status: :precondition_required,           message: "Precondition required" },
      too_many_requests:               { code: 429, status: :too_many_requests,               message: "Too many requests. Please slow down." },
      request_header_fields_too_large: { code: 431, status: :request_header_fields_too_large, message: "Request header fields too large" },
      unavailable_for_legal_reasons:   { code: 451, status: :unavailable_for_legal_reasons,   message: "Unavailable for legal reasons" },
      server_error:                    { code: 500, status: :internal_server_error,           message: "An unexpected error occurred" },
      not_implemented:                 { code: 501, status: :not_implemented,                 message: "This feature is not yet implemented" },
      bad_gateway:                     { code: 502, status: :bad_gateway,                     message: "Bad gateway — upstream service error" },
      service_unavailable:             { code: 503, status: :service_unavailable,             message: "Service temporarily unavailable" },
      gateway_timeout:                 { code: 504, status: :gateway_timeout,                 message: "Gateway timeout — upstream service did not respond" },
      http_version_not_supported:      { code: 505, status: :http_version_not_supported,      message: "HTTP version not supported" },
      variant_also_negotiates:         { code: 506, status: :variant_also_negotiates,         message: "Variant also negotiates" },
      insufficient_storage:            { code: 507, status: :insufficient_storage,            message: "Insufficient storage" },
      loop_detected:                   { code: 508, status: :loop_detected,                   message: "Loop detected" },
      not_extended:                    { code: 510, status: :not_extended,                    message: "Not extended" },
      network_authentication_required: { code: 511, status: :network_authentication_required, message: "Network authentication required" }
    }.freeze

    SUCCESS_HELPERS.each do |name, spec|
      default_message = spec[:message]

      if spec[:data]
        # e.g. render_graphql_ok(data: @user, message: "User fetched", meta: {}, pagination: nil)
        define_method(:"render_graphql_#{name}") do |data: nil, message: default_message, meta: {}, pagination: nil|
          render_graphql_success(data: data, message: message, meta: meta, pagination: pagination,
                         code: spec[:code], status: spec[:status])
        end
      else
        # e.g. render_graphql_no_content(message: "Deleted", meta: {}, pagination: nil)
        define_method(:"render_graphql_#{name}") do |message: default_message, meta: {}, pagination: nil|
          render_graphql_success(data: nil, message: message, meta: meta, pagination: pagination,
                         code: spec[:code], status: spec[:status])
        end
      end
    end

    ERROR_HELPERS.each do |name, spec|
      default_message = spec[:message]

      # e.g. render_graphql_not_found(message: "User not found", errors: nil, meta: {})
      define_method(:"render_graphql_#{name}") do |message: default_message, errors: nil, meta: {}|
        render_graphql_error(message: message, errors: errors, meta: meta, code: spec[:code], status: spec[:status])
      end
    end

    private

    # =========================================================================
    # Core DSL — every helper delegates to these two
    # =========================================================================

    # Render a successful GraphQL response.
    #
    # @param data       [Object]          payload — AR model, collection, Hash, Array, nil
    # @param message    [String]          human-readable description (goes in extensions)
    # @param meta       [Hash]            extra fields merged into extensions
    # @param pagination [Hash, nil]       pagination hash built by the caller
    # @param code       [Integer, nil]    numeric HTTP code recorded in extensions
    # @param status     [Symbol, Integer] HTTP status (default: :ok / 200)
    def render_graphql_success(data: nil, message: nil, meta: {}, code: nil, pagination: nil, status: :ok)
      merged_meta = code ? meta.merge(code: code, status: status) : meta

      payload = ResponseBuilder.new(
        success:    true,
        data:       data,
        message:    message,
        meta:       merged_meta,
        pagination: pagination,
        request:    try(:request)
      ).build

      render json: payload, status: respondo_graphql_http_status(code, status)
    end

    # Render a failed GraphQL response: data is null, `errors` explains why.
    #
    # @param message [String]                      human-readable error description
    # @param errors  [Hash, ActiveModel::Errors]   field-level errors
    # @param code    [Integer, String, nil]        HTTP code (Integer) or machine-readable code (String)
    # @param meta    [Hash]                        extra fields merged into extensions
    # @param status  [Symbol, Integer]             HTTP status (default: :unprocessable_content / 422)
    def render_graphql_error(message: nil, errors: nil, code: nil, meta: {}, status: :unprocessable_content)
      merged_meta = code ? meta.merge(code: code, status: status) : meta

      payload = ResponseBuilder.new(
        success: false,
        data:    nil,
        message: message,
        meta:    merged_meta,
        errors:  extract_graphql_errors(errors),
        request: try(:request)
      ).build

      render json: payload, status: respondo_graphql_http_status(code, status)
    end

    # The HTTP status Rails should send.
    #   * config.always_ok  -> every response is HTTP 200.
    #   * otherwise a numeric code (every helper has one) is sent as-is. Rack has
    #     renamed several status symbols between versions (:payload_too_large,
    #     :unprocessable_entity, ...), so a number is the one form that works on
    #     every Rack/Rails version.
    #   * without a numeric code (a direct render_graphql_error call) the symbol is used.
    def respondo_graphql_http_status(code, status)
      return :ok if RespondoGraphql.config.always_ok

      code.is_a?(Integer) ? code : status
    end

    # Normalize errors into a plain Hash regardless of source type.
    def extract_graphql_errors(errors)
      return nil if errors.nil?
      return errors.to_hash if defined?(ActiveModel::Errors) && errors.is_a?(ActiveModel::Errors)
      return errors if errors.is_a?(Hash)
      return { base: errors } if errors.is_a?(Array)
      return { base: [errors] } if errors.is_a?(String)

      nil
    end
  end
end
