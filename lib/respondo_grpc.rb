# frozen_string_literal: true

require "google/protobuf"
require "google/protobuf/well_known_types"

require_relative "respondo_grpc/version"
require_relative "respondo_grpc/configuration"
require_relative "respondo_grpc/status_map"
require_relative "respondo_grpc/serializer"
require_relative "respondo_grpc/response_builder"
# The respondo.v1.Response message (compiled from proto/respondo/v1/response.proto).
require_relative "respondo/v1/response_pb"
require_relative "respondo_grpc/proto_mapper"
require_relative "respondo_grpc/service_helpers"
require_relative "respondo_grpc/short_helpers"
require_relative "respondo_grpc/client_helpers"

# RespondoGrpc — consistent response envelopes for gRPC services.
#
# @example Configure once in an initializer
#   RespondoGrpc.configure do |config|
#     config.include_request_id = true
#     config.default_meta       = { api_version: "v1" }
#     config.always_ok          = false   # failures finish with a real gRPC status
#   end
#
# @example Use in a gRPC service
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
# @example Short names (opt-in)
#   include RespondoGrpc::ShortHelpers   # render_ok, render_not_found, ...
module RespondoGrpc
  # Trailing-metadata key that carries the serialized respondo.v1.Response on a
  # failed call. Keys ending in "-bin" are binary-safe in gRPC.
  METADATA_KEY = "respondo-response-bin"

  class << self
    # @return [RespondoGrpc::Configuration]
    def config
      @config ||= Configuration.new
    end

    # @yield [RespondoGrpc::Configuration]
    def configure
      yield config
    end

    # Reset config (useful in tests)
    def reset!
      @config = Configuration.new
    end

    # Build the exception that finishes a call with `grpc_code`. Returns the
    # matching subclass (GRPC::NotFound, GRPC::InvalidArgument, ...).
    #
    # @param grpc_code [Integer]
    # @param details   [String]
    # @param metadata  [Hash]
    # @return [GRPC::BadStatus]
    def bad_status(grpc_code, details, metadata = {})
      require "grpc"
      ::GRPC::BadStatus.new_status_exception(grpc_code, details, metadata)
    end
  end
end
