# frozen_string_literal: true

require "time"

module RespondoGrpc
  # Builds the standardized response as a plain Hash. ProtoMapper converts it
  # into the respondo.v1.Response protobuf message.
  #
  #   {
  #     success: Boolean,
  #     message: String,
  #     data:    Object | Array | nil,     # JSON-like payload
  #     payload: <protobuf message>,       # only when a protobuf message was passed as data
  #     errors:  { field: ["msg", ...] },  # only when present
  #     meta:    { request_id:, timestamp:, ...extra, pagination:, code:, status:, grpc_code:, error_code: }
  #   }
  #
  # A protobuf message passed as `data` is kept as-is (and later packed into a
  # google.protobuf.Any) instead of being flattened into a Hash, so clients can
  # unpack it into a real class.
  class ResponseBuilder
    # @param success    [Boolean]
    # @param data       [Object]    anything — serialized automatically
    # @param message    [String]
    # @param meta       [Hash]      caller-supplied extra meta (merged in)
    # @param errors     [Hash]      field-level errors, e.g. { email: ["is invalid"] }
    # @param pagination [Hash, nil] e.g. { current_page: 1, per_page: 25, total_pages: 4,
    #                               total_count: 100, next_page: 2, prev_page: nil }
    # @param call       [Object]    the gRPC call (for the request id in its metadata)
    def initialize(success:, data: nil, message: nil, meta: {}, errors: nil,
                   pagination: nil, call: nil)
      @success    = success
      @raw_data   = data
      @message    = message
      @extra_meta = meta || {}
      @errors     = errors
      @pagination = pagination
      @call       = call
    end

    # @return [Hash] the complete response payload
    def build
      payload = { success: @success, message: resolve_message }

      if typed_payload?(@raw_data)
        payload[:data]    = nil
        payload[:payload] = @raw_data
      else
        payload[:data] = Serializer.call(@raw_data)
      end

      payload[:errors] = @errors if @errors.is_a?(Hash) && !@errors.empty?
      payload[:meta]   = build_meta
      payload
    end

    private

    def resolve_message
      return @message if @message && !@message.empty?

      @success ? RespondoGrpc.config.default_success_message : RespondoGrpc.config.default_error_message
    end

    def typed_payload?(object)
      defined?(::Google::Protobuf::MessageExts) && object.is_a?(::Google::Protobuf::MessageExts)
    end

    def build_meta
      config = RespondoGrpc.config
      meta   = {}

      # 1. Request ID first (opt-in)
      id = request_id
      meta[:request_id] = id if config.include_request_id && id

      # 2. Timestamp second
      meta[:timestamp] = current_timestamp

      # 3. Global defaults (lowest priority), then caller-supplied meta
      meta.merge!(config.default_meta)
      meta.merge!(@extra_meta)

      # 4. Pagination — plain hash from the caller
      meta[:pagination] = @pagination if @pagination.is_a?(Hash) && !@pagination.empty?

      # 5. Re-pin the status fields to the very end
      %i[code status grpc_code error_code].each do |key|
        meta[key] = meta.delete(key) if meta.key?(key)
      end

      meta
    end

    # The id the client sent in its request metadata (x-request-id by default).
    def request_id
      return nil unless @call.respond_to?(:metadata)

      metadata = @call.metadata
      return nil unless metadata.respond_to?(:[])

      key = RespondoGrpc.config.request_id_key.to_s
      metadata[key] || metadata[key.to_sym]
    end

    def current_timestamp
      if Time.respond_to?(:current)
        Time.current.utc.iso8601
      else
        Time.now.utc.iso8601
      end
    end
  end
end
