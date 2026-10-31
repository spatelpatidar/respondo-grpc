# frozen_string_literal: true

module RespondoGrpc
  # Responsible for converting any Ruby object into a plain Hash / Array / primitive.
  # (ProtoMapper later turns the result into a google.protobuf.Value.)
  #
  # Priority order:
  #   1. Custom serializer from RespondoGrpc.config (if set)
  #   2. ActiveRecord::Relation
  #   3. Arrays — each element is serialized recursively
  #   4. ActiveRecord::Base
  #   5. ActiveModel::Errors
  #   6. Exceptions
  #   7. Hashes — values are serialized recursively
  #   8. Objects responding to #as_json or #to_h
  #   9. Primitives — returned as-is
  module Serializer
    module_function

    # @param object [Object] anything — AR model, collection, error, hash, array, primitive
    # @return [Hash, Array, String, Numeric, nil]
    def call(object)
      return nil if object.nil?

      # 1. Custom serializer wins
      return RespondoGrpc.config.serializer.call(object) if RespondoGrpc.config.serializer

      # 2. ActiveRecord::Relation (lazy collection)
      return object.map { |record| serialize_record(record) } if ar_relation?(object)

      # 3. Array — recurse
      return object.map { |item| call(item) } if object.is_a?(Array)

      # 4. ActiveRecord model instance
      return serialize_record(object) if ar_model?(object)

      # 5. ActiveModel::Errors object
      return serialize_errors(object) if active_model_errors?(object)

      # 6. Exception / StandardError
      return { message: object.message } if object.is_a?(Exception)

      # 7. Hash — recursively serialize values
      return object.transform_values { |value| call(value) } if object.is_a?(Hash)

      # 8. Responds to #as_json (ActiveSupport), then #to_h
      return object.as_json if object.respond_to?(:as_json)
      return object.to_h if object.respond_to?(:to_h)

      # 9. Primitive — return as-is
      object
    end

    def ar_relation?(object)
      defined?(ActiveRecord::Relation) && object.is_a?(ActiveRecord::Relation)
    end

    def ar_model?(object)
      defined?(ActiveRecord::Base) && object.is_a?(ActiveRecord::Base)
    end

    def active_model_errors?(object)
      defined?(ActiveModel::Errors) && object.is_a?(ActiveModel::Errors)
    end

    def serialize_record(record)
      if record.respond_to?(:as_json)
        record.as_json
      elsif record.respond_to?(:to_h)
        record.to_h
      else
        record
      end
    end

    def serialize_errors(errors)
      if errors.respond_to?(:to_hash)
        errors.to_hash
      elsif errors.respond_to?(:messages)
        errors.messages
      else
        {}
      end
    end
  end
end
