# frozen_string_literal: true
# Descriptor compiled from respondo/v1/response.proto with protoc 35.1; same layout as `protoc --ruby_out`.
# Regenerate with grpc_tools_ruby_protoc (see README), it produces an equivalent file.
# source: respondo/v1/response.proto

require 'google/protobuf'

require 'google/protobuf/any_pb'
require 'google/protobuf/struct_pb'

descriptor_data = "\n\x1arespondo/v1/response.proto\x12\x0brespondo.v1\x1a\x19google/protobuf/any.proto\x1a\x1cgoogle/protobuf/struct.proto\"\xf2\x01\n\x08Response\x12\x18\n\x07success\x18\x01 \x01(\x08R\x07success\x12\x18\n\x07message\x18\x02 \x01(\x09R\x07message\x12*\n\x04data\x18\x03 \x01(\x0b2\x16.google.protobuf.ValueR\x04data\x12.\n\x07payload\x18\x04 \x01(\x0b2\x14.google.protobuf.AnyR\x07payload\x12/\n\x06errors\x18\x05 \x03(\x0b2\x17.respondo.v1.FieldErrorR\x06errors\x12%\n\x04meta\x18\x06 \x01(\x0b2\x11.respondo.v1.MetaR\x04meta\">\n\nFieldError\x12\x14\n\x05field\x18\x01 \x01(\x09R\x05field\x12\x1a\n\x08messages\x18\x02 \x03(\x09R\x08messages\"\x93\x02\n\x04Meta\x12\x1d\n\nrequest_id\x18\x01 \x01(\x09R\x09requestId\x12\x1c\n\x09timestamp\x18\x02 \x01(\x09R\x09timestamp\x12\x12\n\x04code\x18\x03 \x01(\x05R\x04code\x12\x16\n\x06status\x18\x04 \x01(\x09R\x06status\x12\x1b\n\x09grpc_code\x18\x05 \x01(\x05R\x08grpcCode\x12\x1d\n\nerror_code\x18\x06 \x01(\x09R\x09errorCode\x127\n\npagination\x18\x07 \x01(\x0b2\x17.respondo.v1.PaginationR\npagination\x12-\n\x05extra\x18\x08 \x01(\x0b2\x17.google.protobuf.StructR\x05extra\"\xec\x01\n\nPagination\x12!\n\x0ccurrent_page\x18\x01 \x01(\x05R\x0bcurrentPage\x12\x19\n\x08per_page\x18\x02 \x01(\x05R\x07perPage\x12\x1f\n\x0btotal_pages\x18\x03 \x01(\x05R\ntotalPages\x12\x1f\n\x0btotal_count\x18\x04 \x01(\x05R\ntotalCount\x12 \n\x09next_page\x18\x05 \x01(\x05H\x00R\x08nextPage\x88\x01\x01\x12 \n\x09prev_page\x18\x06 \x01(\x05H\x01R\x08prevPage\x88\x01\x01B\x0c\n\n_next_pageB\x0c\n\n_prev_pageb\x06proto3".b

pool = Google::Protobuf::DescriptorPool.generated_pool
pool.add_serialized_file(descriptor_data)

module Respondo
  module V1
    Response = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("respondo.v1.Response").msgclass
    FieldError = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("respondo.v1.FieldError").msgclass
    Meta = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("respondo.v1.Meta").msgclass
    Pagination = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("respondo.v1.Pagination").msgclass
  end
end
