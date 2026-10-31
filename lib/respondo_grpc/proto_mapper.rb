# frozen_string_literal: true

require "time"

module RespondoGrpc
  # Converts between the Hash built by ResponseBuilder and the
  # respondo.v1.Response protobuf message — in both directions.
  module ProtoMapper
    PAGINATION_KEYS = %i[current_page per_page total_pages total_count next_page prev_page].freeze

    module_function

    # @param hash [Hash] output of ResponseBuilder#build
    # @return [Respondo::V1::Response]
    def to_proto(hash)
      response = ::Respondo::V1::Response.new(success: hash[:success] ? true : false,
                                              message: hash[:message].to_s)

      if hash[:payload]
        response.payload = ::Google::Protobuf::Any.pack(hash[:payload])
      elsif !hash[:data].nil?
        response.data = ::Google::Protobuf::Value.from_ruby(jsonable(hash[:data]))
      end

      (hash[:errors] || {}).each do |field, messages|
        response.errors << ::Respondo::V1::FieldError.new(field: field.to_s,
                                                          messages: Array(messages).map(&:to_s))
      end

      response.meta = meta_to_proto(hash[:meta] || {})
      response
    end

    # @param response [Respondo::V1::Response]
    # @return [Hash] { success:, message:, data:, payload:, errors:, meta: }
    #   `data` comes back as plain Ruby (String keys; every number is a Float,
    #   because google.protobuf.Value has a single number type). `payload` stays a
    #   Google::Protobuf::Any — call `.unpack(MyMessage)` on it.
    def to_h(response)
      hash = { success: response.success, message: response.message }
      hash[:data]    = response.data.to_ruby(true) if response.has_data?
      hash[:payload] = response.payload if response.has_payload?

      errors = response.errors.each_with_object({}) do |error, memo|
        memo[error.field.to_sym] = error.messages.to_a
      end
      hash[:errors] = errors unless errors.empty?
      hash[:meta]   = meta_to_h(response.meta) if response.has_meta?
      hash
    end

    # Wire bytes of the message — what goes into the trailing metadata.
    def encode(response)
      ::Respondo::V1::Response.encode(response)
    end

    def decode(bytes)
      ::Respondo::V1::Response.decode(bytes)
    end

    def meta_to_proto(meta)
      meta  = meta.dup
      attrs = {}

      attrs[:request_id] = meta.delete(:request_id).to_s if meta.key?(:request_id)
      attrs[:timestamp]  = meta.delete(:timestamp).to_s  if meta.key?(:timestamp)
      attrs[:code]       = meta.delete(:code).to_i       if meta.key?(:code)
      attrs[:status]     = meta.delete(:status).to_s     if meta.key?(:status)
      attrs[:grpc_code]  = meta.delete(:grpc_code).to_i  if meta.key?(:grpc_code)
      attrs[:error_code] = meta.delete(:error_code).to_s if meta.key?(:error_code)

      pagination = meta.delete(:pagination)
      attrs[:pagination] = pagination_to_proto(pagination) if pagination.is_a?(Hash)

      proto = ::Respondo::V1::Meta.new(**attrs)
      proto.extra = ::Google::Protobuf::Struct.from_hash(jsonable(meta)) unless meta.empty?
      proto
    end

    def meta_to_h(meta)
      hash = {}
      hash[:request_id] = meta.request_id unless meta.request_id.empty?
      hash[:timestamp]  = meta.timestamp  unless meta.timestamp.empty?
      hash[:code]       = meta.code       unless meta.code.zero?
      hash[:status]     = meta.status     unless meta.status.empty?
      hash[:grpc_code]  = meta.grpc_code  unless meta.grpc_code.zero?
      hash[:error_code] = meta.error_code unless meta.error_code.empty?
      hash[:pagination] = pagination_to_h(meta.pagination) if meta.has_pagination?
      hash[:extra]      = meta.extra.to_h if meta.has_extra?
      hash
    end

    def pagination_to_proto(pagination)
      values = PAGINATION_KEYS.each_with_object({}) do |key, memo|
        value = pagination[key] || pagination[key.to_s]
        memo[key] = value.to_i unless value.nil?
      end
      ::Respondo::V1::Pagination.new(**values)
    end

    def pagination_to_h(pagination)
      hash = {
        current_page: pagination.current_page,
        per_page:     pagination.per_page,
        total_pages:  pagination.total_pages,
        total_count:  pagination.total_count
      }
      hash[:next_page] = pagination.next_page if pagination.has_next_page?
      hash[:prev_page] = pagination.prev_page if pagination.has_prev_page?
      hash
    end

    # google.protobuf.Value accepts only nil, true/false, Numeric, String, Array
    # and Hash (String keys). Normalize anything else that can show up in a
    # payload: Symbols, Times, Dates, BigDecimals, ...
    def jsonable(object)
      case object
      when nil, true, false, String, Integer, Float then object
      when Hash   then object.each_with_object({}) { |(key, value), memo| memo[key.to_s] = jsonable(value) }
      when Array  then object.map { |item| jsonable(item) }
      when Symbol then object.to_s
      when Time   then object.utc.iso8601
      else
        if object.respond_to?(:iso8601) then object.iso8601
        elsif defined?(::BigDecimal) && object.is_a?(::BigDecimal) then object.to_f
        elsif object.respond_to?(:to_h) then jsonable(object.to_h)
        else object.to_s
        end
      end
    end
  end
end
