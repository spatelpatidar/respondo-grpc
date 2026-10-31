# frozen_string_literal: true

require "spec_helper"
require "grpc"

RSpec.describe RespondoGrpc::ServiceHelpers do
  let(:service_class) do
    Class.new do
      include RespondoGrpc::ServiceHelpers
    end
  end
  let(:service) { service_class.new }

  # Runs the block, returns the GRPC::BadStatus it raised.
  def failure
    yield
    nil
  rescue GRPC::BadStatus => e
    e
  end

  def envelope_of(bad_status)
    Respondo::V1::Response.decode(bad_status.metadata[RespondoGrpc::METADATA_KEY])
  end

  describe "success helpers" do
    it "render_grpc_ok returns the envelope, with the 200 / ok meta" do
      response = service.render_grpc_ok(data: { id: 1 }, message: "Fetched")

      expect(response).to be_a(Respondo::V1::Response)
      expect(response.success).to eq(true)
      expect(response.message).to eq("Fetched")
      expect(response.meta.code).to eq(200)
      expect(response.meta.status).to eq("ok")
      expect(RespondoGrpc::ProtoMapper.to_h(response)[:data]).to eq("id" => 1)
    end

    it "render_grpc_created uses 201 and its default message" do
      response = service.render_grpc_created(data: { id: 2 })

      expect(response.meta.code).to eq(201)
      expect(response.message).to eq("Created successfully")
    end

    it "render_grpc_no_content carries no data" do
      response = service.render_grpc_no_content

      expect(response.meta.code).to eq(204)
      expect(response.has_data?).to eq(false)
      expect(response.message).to eq("Deleted successfully")
    end

    it "passes pagination and extra meta through" do
      response = service.render_grpc_ok(data: [1], meta: { region: "eu" },
                                        pagination: { current_page: 1, per_page: 1, total_pages: 1, total_count: 1 })

      expect(response.meta.pagination.total_count).to eq(1)
      expect(response.meta.extra.to_h).to eq("region" => "eu")
    end

    it "sends a protobuf message as a typed payload" do
      page     = Respondo::V1::Pagination.new(current_page: 9)
      response = service.render_grpc_ok(data: page)

      expect(response.payload.unpack(Respondo::V1::Pagination).current_page).to eq(9)
    end

    it "copies the request id from the call when enabled" do
      RespondoGrpc.configure { |c| c.include_request_id = true }
      call = Struct.new(:metadata).new({ "x-request-id" => "req-1" })

      expect(service.render_grpc_ok(call: call).meta.request_id).to eq("req-1")
    end
  end

  describe "error helpers" do
    it "raise GRPC::BadStatus with the mapped status code and the message as details" do
      error = failure { service.render_grpc_not_found(message: "User not found") }

      expect(error).to be_a(GRPC::BadStatus)
      expect(error.code).to eq(GRPC::Core::StatusCodes::NOT_FOUND)
      expect(error.details).to eq("User not found")
    end

    it "carry the full envelope in the trailing metadata" do
      error    = failure { service.render_grpc_not_found(message: "User not found") }
      envelope = envelope_of(error)

      expect(envelope.success).to eq(false)
      expect(envelope.message).to eq("User not found")
      expect(envelope.meta.code).to eq(404)
      expect(envelope.meta.status).to eq("not_found")
      expect(envelope.meta.grpc_code).to eq(5)
    end

    it "map validation errors to INVALID_ARGUMENT and keep the field errors" do
      error = failure do
        service.render_grpc_unprocessable(message: "Validation failed", errors: { email: ["is invalid"] })
      end

      expect(error.code).to eq(GRPC::Core::StatusCodes::INVALID_ARGUMENT)
      expect(envelope_of(error).errors.first.field).to eq("email")
      expect(envelope_of(error).errors.first.messages.to_a).to eq(["is invalid"])
    end

    it "wrap an Array or String of errors under base" do
      error = failure { service.render_grpc_bad_request(errors: "Bad input") }

      expect(envelope_of(error).errors.first.field).to eq("base")
      expect(envelope_of(error).errors.first.messages.to_a).to eq(["Bad input"])
    end

    it "use the helper's default message when none is given" do
      error = failure { service.render_grpc_forbidden }

      expect(error.code).to eq(GRPC::Core::StatusCodes::PERMISSION_DENIED)
      expect(error.details).to eq("You do not have permission to perform this action")
    end

    it "honour config.status_map" do
      RespondoGrpc.configure { |c| c.status_map = { 409 => :aborted } }

      expect(failure { service.render_grpc_conflict }.code).to eq(GRPC::Core::StatusCodes::ABORTED)
    end

    it "cover the 5xx range" do
      expect(failure { service.render_grpc_server_error }.code).to eq(GRPC::Core::StatusCodes::INTERNAL)
      expect(failure { service.render_grpc_service_unavailable }.code).to eq(GRPC::Core::StatusCodes::UNAVAILABLE)
    end

    it "render_grpc_error with a String code sets error_code and uses the status name" do
      error = failure do
        service.send(:render_grpc_error, message: "Token expired", code: "AUTH_EXPIRED", status: :unauthorized)
      end
      meta = envelope_of(error).meta

      expect(error.code).to eq(GRPC::Core::StatusCodes::UNAUTHENTICATED)
      expect(meta.error_code).to eq("AUTH_EXPIRED")
      expect(meta.code).to eq(401)
    end

    it "render_grpc_error defaults to a 422 / INVALID_ARGUMENT failure" do
      error = failure { service.send(:render_grpc_error, message: "Nope") }

      expect(error.code).to eq(GRPC::Core::StatusCodes::INVALID_ARGUMENT)
      expect(envelope_of(error).meta.code).to eq(422)
    end
  end

  describe "config.always_ok" do
    before { RespondoGrpc.configure { |c| c.always_ok = true } }

    it "returns the failed envelope instead of raising" do
      response = service.render_grpc_not_found(message: "User not found")

      expect(response).to be_a(Respondo::V1::Response)
      expect(response.success).to eq(false)
      expect(response.message).to eq("User not found")
      expect(response.meta.grpc_code).to eq(5)
    end

    it "still returns success envelopes" do
      expect(service.render_grpc_ok.success).to eq(true)
    end
  end

  describe "helper table" do
    it "defines a render_grpc_* method for every success and error helper" do
      names = RespondoGrpc::ServiceHelpers::SUCCESS_HELPERS.keys + RespondoGrpc::ServiceHelpers::ERROR_HELPERS.keys

      expect(names.map { |name| service.respond_to?(:"render_grpc_#{name}") }.uniq).to eq([true])
    end

    it "does not define 1xx or 3xx helpers" do
      expect(service.respond_to?(:render_grpc_continue)).to eq(false)
      expect(service.respond_to?(:render_grpc_found)).to eq(false)
    end

    it "keeps the core methods private" do
      expect(service.respond_to?(:render_grpc_success)).to eq(false)
      expect(service.respond_to?(:render_grpc_error)).to eq(false)
    end
  end

  describe RespondoGrpc::ShortHelpers do
    let(:short_class) do
      Class.new do
        include RespondoGrpc::ShortHelpers
      end
    end
    let(:short) { short_class.new }

    it "includes the prefixed helpers" do
      expect(short_class.ancestors).to include(RespondoGrpc::ServiceHelpers)
    end

    it "render_ok answers like render_grpc_ok" do
      response = short.render_ok(data: { id: 1 }, message: "Fetched")

      expect(response.message).to eq("Fetched")
      expect(response.meta.code).to eq(200)
    end

    it "render_not_found raises like render_grpc_not_found" do
      error = failure { short.render_not_found(message: "Missing") }

      expect(error.code).to eq(GRPC::Core::StatusCodes::NOT_FOUND)
    end
  end
end
