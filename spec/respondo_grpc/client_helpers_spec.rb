# frozen_string_literal: true

require "spec_helper"
require "grpc"

RSpec.describe RespondoGrpc::ClientHelpers do
  let(:service) { Class.new { include RespondoGrpc::ServiceHelpers }.new }

  def failure
    yield
    nil
  rescue GRPC::BadStatus => e
    e
  end

  describe ".to_h" do
    it "decodes a reply" do
      response = service.render_grpc_ok(data: { id: 1 }, message: "Fetched")
      result   = described_class.to_h(response)

      expect(result[:success]).to eq(true)
      expect(result[:data]).to eq("id" => 1)
      expect(result[:meta][:code]).to eq(200)
    end
  end

  describe ".error_response / .error_hash" do
    it "read the envelope from a failed call" do
      error = failure do
        service.render_grpc_unprocessable(message: "Validation failed", errors: { email: ["is invalid"] })
      end

      expect(described_class.error_response(error)).to be_a(Respondo::V1::Response)

      hash = described_class.error_hash(error)
      expect(hash[:success]).to eq(false)
      expect(hash[:message]).to eq("Validation failed")
      expect(hash[:errors]).to eq(email: ["is invalid"])
      expect(hash[:meta][:grpc_code]).to eq(3)
    end

    it "return nil / a minimal hash when the server sent no envelope" do
      plain = GRPC::NotFound.new("plain failure")

      expect(described_class.error_response(plain)).to be_nil
      expect(described_class.error_hash(plain)).to eq(
        success: false, message: "plain failure", meta: { grpc_code: GRPC::Core::StatusCodes::NOT_FOUND }
      )
    end

    it "ignore garbage in the metadata key" do
      bad = GRPC::Internal.new("oops", RespondoGrpc::METADATA_KEY => "\xFF\xFF\xFF".b)

      expect(described_class.error_response(bad)).to be_nil
    end
  end
end
