# frozen_string_literal: true

module RespondoGraphql
  # Global configuration for RespondoGraphql.
  #
  # @example
  #   RespondoGraphql.configure do |config|
  #     config.default_success_message = "OK"
  #     config.include_request_id      = true
  #     config.camelize_keys           = true
  #     config.always_ok               = true
  #   end
  class Configuration
    # Message used when none is supplied to a success helper
    attr_accessor :default_success_message

    # Message used when none is supplied to an error helper
    attr_accessor :default_error_message

    # When true, includes request.request_id in every extensions block (Rails only)
    attr_accessor :include_request_id

    # When true, all response keys are camelized (e.g. created_at -> createdAt)
    attr_accessor :camelize_keys

    # Custom serializer callable — receives (object) and returns a Hash/Array.
    # Defaults to nil (built-in serialization strategy is used).
    # @example config.serializer = ->(obj) { MySerializer.new(obj).as_json }
    attr_accessor :serializer

    # Static key-value pairs merged into every response's `extensions` block.
    # @example config.default_meta = { api_version: "v1" }
    attr_accessor :default_meta

    # GraphQL requires `data` to be a map, so a payload that is an Array or a
    # scalar is wrapped as { <data_key> => payload }. Hash payloads pass through.
    attr_accessor :data_key

    # When true every response is sent with HTTP 200, whatever the helper's
    # status, and failures are reported through the `errors` array. Many GraphQL
    # clients (e.g. Apollo) treat non-2xx responses as network failures.
    # Defaults to false so helper status codes keep meaning what they say.
    attr_accessor :always_ok

    def initialize
      @default_success_message = "Success"
      @default_error_message   = "An error occurred"
      @include_request_id      = false
      @camelize_keys           = false
      @serializer              = nil
      @default_meta            = {}
      @data_key                = :result
      @always_ok               = false
    end
  end
end
