# frozen_string_literal: true

module RespondoGrpc
  # Mixed into a gRPC service class to answer every rpc with the respondo.v1.Response
  # envelope, using expressive, status-aware helpers.
  #
  #   class UserService < Example::Users::V1::UserService::Service
  #     include RespondoGrpc::ServiceHelpers
  #
  #     def get_user(request, call)
  #       user = User.find_by(id: request.id)
  #       return render_grpc_not_found(message: "User not found", call: call) unless user
  #
  #       render_grpc_ok(data: user, message: "User fetched", call: call)
  #     end
  #   end
  #
  # Success helpers RETURN the Response message — make the call the last
  # expression of the rpc method.
  #
  # Error helpers RAISE GRPC::BadStatus with the mapped gRPC status code (NOT_FOUND,
  # INVALID_ARGUMENT, ...) and the envelope in the trailing metadata, unless
  # config.always_ok is true, in which case they return the envelope as a normal
  # reply. Writing `return render_grpc_not_found(...)` works in both modes.
  #
  # Every helper is prefixed (render_grpc_*) so this module can sit next to the
  # respondo (JSON) and respondo-graphql helpers without name clashes.
  #
  # Success helpers (2xx) — accept data:, message:, meta:, pagination:, call:
  #   render_grpc_ok, render_grpc_created, render_grpc_accepted, render_grpc_non_authoritative,
  #   render_grpc_partial_content, render_grpc_multi_status, render_grpc_already_reported,
  #   render_grpc_im_used
  #
  # Success helpers (2xx) without a payload — accept message:, meta:, pagination:, call:
  #   render_grpc_no_content, render_grpc_reset_content
  #
  # Error helpers (4xx / 5xx) — accept message:, errors:, meta:, call:
  #   render_grpc_bad_request, render_grpc_unauthorized, render_grpc_payment_required,
  #   render_grpc_forbidden, render_grpc_not_found, render_grpc_method_not_allowed,
  #   render_grpc_not_acceptable, render_grpc_proxy_auth_required, render_grpc_request_timeout,
  #   render_grpc_conflict, render_grpc_gone, render_grpc_length_required,
  #   render_grpc_precondition_failed, render_grpc_payload_too_large, render_grpc_uri_too_long,
  #   render_grpc_unsupported_media_type, render_grpc_range_not_satisfiable,
  #   render_grpc_expectation_failed, render_grpc_im_a_teapot, render_grpc_misdirected_request,
  #   render_grpc_unprocessable, render_grpc_locked, render_grpc_failed_dependency,
  #   render_grpc_too_early, render_grpc_upgrade_required, render_grpc_precondition_required,
  #   render_grpc_too_many_requests, render_grpc_request_header_fields_too_large,
  #   render_grpc_unavailable_for_legal_reasons, render_grpc_server_error,
  #   render_grpc_not_implemented, render_grpc_bad_gateway, render_grpc_service_unavailable,
  #   render_grpc_gateway_timeout, render_grpc_http_version_not_supported,
  #   render_grpc_variant_also_negotiates, render_grpc_insufficient_storage,
  #   render_grpc_loop_detected, render_grpc_not_extended,
  #   render_grpc_network_authentication_required
  #
  # 1xx (informational) and 3xx (redirect) helpers are intentionally not
  # provided: they are HTTP transport concepts with no meaning in gRPC.
  module ServiceHelpers
    # name => { code: HTTP-style code, status: status name, message: default message, data: takes data? }
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

    # name => { code: HTTP-style code, status: status name, message: default message }
    ERROR_HELPERS = {
      bad_request:                     { code: 400, status: :bad_request,                     message: "Bad request" },
      unauthorized:                    { code: 401, status: :unauthorized,                    message: "Unauthorized" },
      payment_required:                { code: 402, status: :payment_required,                message: "Payment required to access this resource" },
      forbidden:                       { code: 403, status: :forbidden,                       message: "You do not have permission to perform this action" },
      not_found:                       { code: 404, status: :not_found,                       message: "Resource not found" },
      method_not_allowed:              { code: 405, status: :method_not_allowed,              message: "Method not allowed" },
      not_acceptable:                  { code: 406, status: :not_acceptable,                  message: "Requested format not acceptable" },
      proxy_auth_required:             { code: 407, status: :proxy_authentication_required,   message: "Proxy authentication required" },
      request_timeout:                 { code: 408, status: :request_timeout,                 message: "Request timed out" },
      conflict:                        { code: 409, status: :conflict,                        message: "Resource conflict" },
      gone:                            { code: 410, status: :gone,                            message: "Resource no longer available" },
      length_required:                 { code: 411, status: :length_required,                 message: "Content length required" },
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
      http_version_not_supported:      { code: 505, status: :http_version_not_supported,      message: "Version not supported" },
      variant_also_negotiates:         { code: 506, status: :variant_also_negotiates,         message: "Variant also negotiates" },
      insufficient_storage:            { code: 507, status: :insufficient_storage,            message: "Insufficient storage" },
      loop_detected:                   { code: 508, status: :loop_detected,                   message: "Loop detected" },
      not_extended:                    { code: 510, status: :not_extended,                    message: "Not extended" },
      network_authentication_required: { code: 511, status: :network_authentication_required, message: "Network authentication required" }
    }.freeze

    # status name => HTTP-style code, so render_grpc_error(status: :not_found) resolves to 404
    HTTP_CODE_BY_STATUS = ERROR_HELPERS.each_value.with_object({}) do |spec, memo|
      memo[spec[:status]] = spec[:code]
    end.freeze

    SUCCESS_HELPERS.each do |name, spec|
      default_message = spec[:message]

      if spec[:data]
        # e.g. render_grpc_ok(data: @user, message: "User fetched", meta: {}, pagination: nil, call: call)
        define_method(:"render_grpc_#{name}") do |data: nil, message: default_message, meta: {}, pagination: nil, call: nil|
          render_grpc_success(data: data, message: message, meta: meta, pagination: pagination,
                              code: spec[:code], status: spec[:status], call: call)
        end
      else
        # e.g. render_grpc_no_content(message: "Deleted", meta: {}, pagination: nil, call: call)
        define_method(:"render_grpc_#{name}") do |message: default_message, meta: {}, pagination: nil, call: nil|
          render_grpc_success(data: nil, message: message, meta: meta, pagination: pagination,
                              code: spec[:code], status: spec[:status], call: call)
        end
      end
    end

    ERROR_HELPERS.each do |name, spec|
      default_message = spec[:message]

      # e.g. render_grpc_not_found(message: "User not found", errors: nil, meta: {}, call: call)
      define_method(:"render_grpc_#{name}") do |message: default_message, errors: nil, meta: {}, call: nil|
        render_grpc_error(message: message, errors: errors, meta: meta,
                          code: spec[:code], status: spec[:status], call: call)
      end
    end

    private

    # =========================================================================
    # Core DSL — every helper delegates to these two
    # =========================================================================

    # Build a successful envelope.
    #
    # @param data       [Object]          payload — AR model, collection, Hash, Array, protobuf message, nil
    # @param message    [String]          human-readable description
    # @param meta       [Hash]            extra fields merged into meta
    # @param pagination [Hash, nil]       pagination hash built by the caller
    # @param code       [Integer, nil]    HTTP-style code recorded in meta (200, 201, ...)
    # @param status     [Symbol]          status name recorded in meta
    # @param call       [Object]          the rpc's call argument (for the request id)
    # @return [Respondo::V1::Response]
    def render_grpc_success(data: nil, message: nil, meta: {}, code: nil, pagination: nil, status: :ok, call: nil)
      merged_meta = code ? meta.merge(code: code, status: status.to_s) : meta

      hash = ResponseBuilder.new(
        success:    true,
        data:       data,
        message:    message,
        meta:       merged_meta,
        pagination: pagination,
        call:       call
      ).build

      ProtoMapper.to_proto(hash)
    end

    # Build a failed envelope and finish the call with the mapped gRPC status.
    #
    # @param message [String]                      human-readable error description
    # @param errors  [Hash, ActiveModel::Errors]   field-level errors
    # @param code    [Integer, String, nil]        HTTP-style code (Integer) or machine-readable code (String)
    # @param meta    [Hash]                        extra fields merged into meta
    # @param status  [Symbol, Integer]             status name (default :unprocessable_content) or HTTP-style code
    # @param call    [Object]                      the rpc's call argument (for the request id)
    # @raise [GRPC::BadStatus] unless config.always_ok, in which case the envelope is returned
    # @return [Respondo::V1::Response]
    def render_grpc_error(message: nil, errors: nil, code: nil, meta: {}, status: :unprocessable_content, call: nil)
      http_code = respondo_grpc_http_code(code, status)
      grpc_code = StatusMap.grpc_code_for(http_code)

      status_meta = { code: http_code, status: status.to_s, grpc_code: grpc_code }
      status_meta[:error_code] = code if code.is_a?(String) && !code.empty?

      hash = ResponseBuilder.new(
        success: false,
        data:    nil,
        message: message,
        meta:    meta.merge(status_meta),
        errors:  extract_grpc_errors(errors),
        call:    call
      ).build

      response = ProtoMapper.to_proto(hash)
      return response if RespondoGrpc.config.always_ok

      raise RespondoGrpc.bad_status(grpc_code, hash[:message], RespondoGrpc::METADATA_KEY => ProtoMapper.encode(response))
    end

    # An Integer code wins, then an Integer status, then the status name's
    # HTTP-style code; 500 when nothing matches.
    def respondo_grpc_http_code(code, status)
      return code   if code.is_a?(Integer)
      return status if status.is_a?(Integer)

      HTTP_CODE_BY_STATUS.fetch(status.to_sym, 500)
    end

    # Normalize errors into a plain Hash regardless of source type.
    def extract_grpc_errors(errors)
      return nil if errors.nil?
      return errors.to_hash if defined?(ActiveModel::Errors) && errors.is_a?(ActiveModel::Errors)
      return errors if errors.is_a?(Hash)
      return { base: errors } if errors.is_a?(Array)
      return { base: [errors] } if errors.is_a?(String)

      nil
    end
  end
end
