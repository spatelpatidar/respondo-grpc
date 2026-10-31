# frozen_string_literal: true

require_relative "lib/respondo_grpc/version"

Gem::Specification.new do |spec|
  spec.name          = "respondo-grpc"
  spec.version       = RespondoGrpc::VERSION
  spec.authors       = ["shailendra Kumar"]
  spec.email         = ["shailendrapatidar00@gmail.com"]

  spec.summary       = "Consistent response envelopes for gRPC services — data, errors, meta, real status codes."
  spec.description   = <<~DESC
    RespondoGrpc standardizes the responses your gRPC services send. Every rpc can
    return one protobuf envelope (respondo.v1.Response: success, message, data,
    errors, meta), built from the same expressive helpers as its siblings
    (render_grpc_ok, render_grpc_not_found, render_grpc_unprocessable, ...).
    Failures finish the call with the matching gRPC status code (NOT_FOUND,
    INVALID_ARGUMENT, ...) and carry the envelope in the trailing metadata, so
    clients get both a proper status and structured field errors. Protobuf messages
    travel as typed payloads, hashes and ActiveRecord records as JSON-like data.
    Standalone gem — it does not depend on respondo (JSON) or respondo-graphql.
  DESC
  spec.homepage      = "https://github.com/spatelpatidar/respondo-grpc"
  spec.license       = "Apache-2.0"
  spec.required_ruby_version = ">= 2.7.0"

  spec.metadata = {
    "homepage_uri"          => spec.homepage,
    "source_code_uri"       => spec.homepage,
    "changelog_uri"         => "#{spec.homepage}/blob/main/CHANGELOG.md",
    "bug_tracker_uri"       => "#{spec.homepage}/issues",
    "rubygems_mfa_required" => "true"
  }

  spec.files = Dir["lib/**/*.rb", "proto/**/*.proto", "README.md", "LICENSE", "CHANGELOG.md", "respondo-grpc.gemspec"]
  spec.require_paths = ["lib"]

  spec.add_dependency "google-protobuf", ">= 3.25"
  spec.add_dependency "grpc",            ">= 1.60"

  spec.add_development_dependency "grpc-tools",  ">= 1.60"
  spec.add_development_dependency "rspec",       "~> 3.12"
  spec.add_development_dependency "rake",        "~> 13.0"
  spec.add_development_dependency "simplecov",   "~> 0.22"
end
