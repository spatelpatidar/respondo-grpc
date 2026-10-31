# frozen_string_literal: true

require "simplecov"
SimpleCov.start do
  add_filter "/spec/"
  add_filter "lib/respondo_grpc/version.rb"
  add_filter "lib/respondo/v1/response_pb.rb"
  track_files "lib/**/*.rb"
end

require "respondo_grpc"

RSpec.configure do |config|
  config.example_status_persistence_file_path = "spec/respondo_grpc_test.txt"
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.before(:each) do
    RespondoGrpc.reset!
  end
end
