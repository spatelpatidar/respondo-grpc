# frozen_string_literal: true

module RespondoGrpc
  # Maps the HTTP-style codes used by every Respondo helper (404, 422, ...) onto
  # gRPC status codes. The numbers are the canonical ones from the gRPC spec
  # (GRPC::Core::StatusCodes), kept here so this file needs no gRPC dependency.
  #
  # The table follows the usual HTTP <-> gRPC correspondence (see the gRPC
  # status-code docs and Google's API design guide). Codes with no natural gRPC
  # twin are mapped to the closest meaning. Override any of them:
  #
  #   RespondoGrpc.configure { |c| c.status_map = { 409 => :aborted } }
  module StatusMap
    CODES = {
      ok:                  0,
      cancelled:           1,
      unknown:             2,
      invalid_argument:    3,
      deadline_exceeded:   4,
      not_found:           5,
      already_exists:      6,
      permission_denied:   7,
      resource_exhausted:  8,
      failed_precondition: 9,
      aborted:             10,
      out_of_range:        11,
      unimplemented:       12,
      internal:            13,
      unavailable:         14,
      data_loss:           15,
      unauthenticated:     16
    }.freeze

    HTTP_TO_GRPC = {
      400 => :invalid_argument,
      401 => :unauthenticated,
      402 => :failed_precondition,
      403 => :permission_denied,
      404 => :not_found,
      405 => :unimplemented,
      406 => :invalid_argument,
      407 => :unauthenticated,
      408 => :deadline_exceeded,
      409 => :already_exists,
      410 => :not_found,
      411 => :invalid_argument,
      412 => :failed_precondition,
      413 => :resource_exhausted,
      414 => :invalid_argument,
      415 => :invalid_argument,
      416 => :out_of_range,
      417 => :failed_precondition,
      418 => :unknown,
      421 => :failed_precondition,
      422 => :invalid_argument,
      423 => :failed_precondition,
      424 => :failed_precondition,
      425 => :failed_precondition,
      426 => :failed_precondition,
      428 => :failed_precondition,
      429 => :resource_exhausted,
      431 => :resource_exhausted,
      451 => :permission_denied,
      500 => :internal,
      501 => :unimplemented,
      502 => :unavailable,
      503 => :unavailable,
      504 => :deadline_exceeded,
      505 => :unimplemented,
      506 => :internal,
      507 => :resource_exhausted,
      508 => :internal,
      510 => :unimplemented,
      511 => :unauthenticated
    }.freeze

    module_function

    # @param http_code [Integer] e.g. 404
    # @return [Integer] gRPC status code, e.g. 5
    def grpc_code_for(http_code)
      name = RespondoGrpc.config.status_map[http_code] || HTTP_TO_GRPC[http_code] || fallback_for(http_code)
      resolve(name)
    end

    # @param value [Integer, Symbol, String] 5, :not_found or "NOT_FOUND"
    # @return [Integer]
    def resolve(value)
      return value if value.is_a?(Integer)

      CODES.fetch(value.to_s.downcase.to_sym) do
        raise ArgumentError, "Unknown gRPC status #{value.inspect}. Use one of: #{CODES.keys.join(', ')}"
      end
    end

    # Name for a gRPC status code, e.g. 5 -> :not_found
    def name_for(grpc_code)
      CODES.key(grpc_code)
    end

    def fallback_for(http_code)
      case http_code
      when 200..299 then :ok
      when 400..499 then :invalid_argument
      when 500..599 then :internal
      else :unknown
      end
    end
  end
end
