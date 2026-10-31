# frozen_string_literal: true

require "spec_helper"

RSpec.describe RespondoGrpc::ResponseBuilder do
  CallStub = Struct.new(:metadata) unless defined?(CallStub)

  def build(**opts)
    described_class.new(**opts).build
  end

  describe "successful responses" do
    it "returns success, message, data and meta" do
      expect(build(success: true, data: { id: 1 }).keys).to eq(%i[success message data meta])
    end

    it "marks the response as successful" do
      expect(build(success: true)[:success]).to eq(true)
    end

    it "falls back to the default success message" do
      expect(build(success: true)[:message]).to eq("Success")
    end

    it "keeps a given message" do
      expect(build(success: true, message: "Fetched")[:message]).to eq("Fetched")
    end

    it "serializes data" do
      expect(build(success: true, data: [{ id: 1 }])[:data]).to eq([{ id: 1 }])
    end

    it "keeps nil data as nil" do
      expect(build(success: true, data: nil)[:data]).to be_nil
    end

    it "keeps a protobuf message as a typed payload instead of flattening it" do
      message = Respondo::V1::Pagination.new(current_page: 1)
      result  = build(success: true, data: message)

      expect(result[:payload]).to equal(message)
      expect(result[:data]).to be_nil
    end
  end

  describe "error responses" do
    it "orders keys success, message, data, errors, meta" do
      result = build(success: false, message: "Nope", errors: { email: ["is invalid"] })

      expect(result.keys).to eq(%i[success message data errors meta])
      expect(result[:success]).to eq(false)
      expect(result[:data]).to be_nil
    end

    it "falls back to the default error message" do
      expect(build(success: false)[:message]).to eq("An error occurred")
    end

    it "omits errors when none are given" do
      expect(build(success: false, errors: {})).not_to include(:errors)
      expect(build(success: false, errors: nil)).not_to include(:errors)
    end

    it "keeps field-level errors" do
      expect(build(success: false, errors: { email: ["is invalid"] })[:errors]).to eq(email: ["is invalid"])
    end
  end

  describe "meta" do
    it "always has an ISO 8601 timestamp, first" do
      meta = build(success: true)[:meta]

      expect(meta.keys.first).to eq(:timestamp)
      expect(meta[:timestamp]).to match(/\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(Z|[+-]\d{2}:\d{2})\z/)
    end

    it "merges config.default_meta, then caller meta (caller wins)" do
      RespondoGrpc.configure { |c| c.default_meta = { api_version: "v1", region: "eu" } }
      meta = build(success: true, meta: { region: "us" })[:meta]

      expect(meta[:api_version]).to eq("v1")
      expect(meta[:region]).to eq("us")
    end

    it "includes pagination when given" do
      meta = build(success: true, pagination: { current_page: 1, per_page: 25 })[:meta]

      expect(meta[:pagination]).to eq(current_page: 1, per_page: 25)
    end

    it "omits empty pagination" do
      expect(build(success: true, pagination: {})[:meta]).not_to include(:pagination)
    end

    it "pins code, status, grpc_code and error_code to the end" do
      meta = build(success: false,
                   meta: { code: 404, status: "not_found", grpc_code: 5, error_code: "X", extra: 1 },
                   pagination: { current_page: 1 })[:meta]

      expect(meta.keys.last(4)).to eq(%i[code status grpc_code error_code])
    end
  end

  describe "request id" do
    let(:call) { CallStub.new({ "x-request-id" => "abc-123" }) }

    it "is left out by default" do
      expect(build(success: true, call: call)[:meta]).not_to include(:request_id)
    end

    it "is read from the call metadata when enabled, and comes first" do
      RespondoGrpc.configure { |c| c.include_request_id = true }
      meta = build(success: true, call: call)[:meta]

      expect(meta[:request_id]).to eq("abc-123")
      expect(meta.keys.first).to eq(:request_id)
    end

    it "honours config.request_id_key" do
      RespondoGrpc.configure do |c|
        c.include_request_id = true
        c.request_id_key     = "x-correlation-id"
      end
      call = CallStub.new({ "x-correlation-id" => "corr-9" })

      expect(build(success: true, call: call)[:meta][:request_id]).to eq("corr-9")
    end

    it "is skipped when there is no call or no such header" do
      RespondoGrpc.configure { |c| c.include_request_id = true }

      expect(build(success: true)[:meta]).not_to include(:request_id)
      expect(build(success: true, call: CallStub.new({}))[:meta]).not_to include(:request_id)
    end
  end
end
