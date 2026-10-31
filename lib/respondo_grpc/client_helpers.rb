# frozen_string_literal: true

module RespondoGrpc
  # Client-side helpers: read a respondo.v1.Response, or the one a failed call
  # carries in its trailing metadata.
  #
  #   begin
  #     response = stub.get_user(Example::Users::V1::GetUserRequest.new(id: 42))
  #     result   = RespondoGrpc::ClientHelpers.to_h(response)
  #     result[:data]            # plain Ruby, for hash-style payloads
  #     response.payload.unpack(Example::Users::V1::User)   # typed payloads
  #   rescue GRPC::BadStatus => e
  #     failure = RespondoGrpc::ClientHelpers.error_hash(e)
  #     failure[:message]        # => "User not found"
  #     failure[:errors]         # => { email: ["is invalid"] }
  #     failure[:meta][:grpc_code]
  #   end
  module ClientHelpers
    module_function

    # @param response [Respondo::V1::Response]
    # @return [Hash] { success:, message:, data:, payload:, errors:, meta: }
    def to_h(response)
      ProtoMapper.to_h(response)
    end

    # The envelope a failed call carried, or nil when the server did not send one
    # (a plain gRPC error, a transport failure, ...).
    #
    # @param bad_status [GRPC::BadStatus]
    # @return [Respondo::V1::Response, nil]
    def error_response(bad_status)
      metadata = bad_status.respond_to?(:metadata) ? bad_status.metadata : nil
      bytes    = metadata && metadata[RespondoGrpc::METADATA_KEY]
      return nil if bytes.nil? || bytes.empty?

      ProtoMapper.decode(bytes)
    rescue ::Google::Protobuf::ParseError
      nil
    end

    # Same as error_response, as a Hash. Falls back to the status details when
    # there is no envelope, so there is always something to show.
    #
    # @param bad_status [GRPC::BadStatus]
    # @return [Hash]
    def error_hash(bad_status)
      response = error_response(bad_status)
      return ProtoMapper.to_h(response) if response

      { success: false, message: bad_status.details.to_s, meta: { grpc_code: bad_status.code } }
    end
  end
end
