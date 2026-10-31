# frozen_string_literal: true

module RespondoGrpc
  # Global configuration for RespondoGrpc.
  #
  # @example
  #   RespondoGrpc.configure do |config|
  #     config.default_success_message = "OK"
  #     config.include_request_id      = true
  #     config.always_ok               = false
  #     config.default_meta            = { api_version: "v1" }
  #   end
  class Configuration
    # Message used when none is supplied to a success helper
    attr_accessor :default_success_message

    # Message used when none is supplied to an error helper
    attr_accessor :default_error_message

    # When true, copies the request id from the call's metadata into every
    # response's meta block (see request_id_key). Needs `call:` on the helper.
    attr_accessor :include_request_id

    # Request metadata key the request id is read from (gRPC keys are lowercase).
    attr_accessor :request_id_key

    # Custom serializer callable — receives (object) and returns a Hash/Array.
    # Defaults to nil (built-in serialization strategy is used).
    # @example config.serializer = ->(obj) { MySerializer.new(obj).as_json }
    attr_accessor :serializer

    # Static key-value pairs merged into every response's `meta.extra` block.
    # @example config.default_meta = { api_version: "v1" }
    attr_accessor :default_meta

    # By default an error helper raises GRPC::BadStatus, so the call finishes
    # with a real gRPC status code (NOT_FOUND, INVALID_ARGUMENT, ...) and the
    # envelope rides in the trailing metadata. When true, error helpers return
    # the envelope as a normal reply and the call finishes with status OK;
    # clients then read `success` / `meta.grpc_code` from the message.
    attr_accessor :always_ok

    # Overrides for the HTTP-code -> gRPC-status table, e.g. { 409 => :aborted }.
    # Values are status names (see StatusMap::CODES) or integers.
    attr_accessor :status_map

    def initialize
      @default_success_message = "Success"
      @default_error_message   = "An error occurred"
      @include_request_id      = false
      @request_id_key          = "x-request-id"
      @serializer              = nil
      @default_meta            = {}
      @always_ok               = false
      @status_map              = {}
    end
  end
end
