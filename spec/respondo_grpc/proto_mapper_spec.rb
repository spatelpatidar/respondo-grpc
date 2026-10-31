# frozen_string_literal: true

require "spec_helper"

RSpec.describe RespondoGrpc::ProtoMapper do
  def proto_for(**opts)
    described_class.to_proto(RespondoGrpc::ResponseBuilder.new(**opts).build)
  end

  describe ".to_proto" do
    it "returns a respondo.v1.Response" do
      expect(proto_for(success: true)).to be_a(Respondo::V1::Response)
    end

    it "copies success and message" do
      response = proto_for(success: true, message: "Fetched")

      expect(response.success).to eq(true)
      expect(response.message).to eq("Fetched")
    end

    it "turns hash data into a google.protobuf.Value" do
      response = proto_for(success: true, data: { id: 1, name: "Ada", tags: %w[a b], active: true, none: nil })

      expect(response.has_data?).to eq(true)
      expect(described_class.to_h(response)[:data]).to eq(
        "id" => 1, "name" => "Ada", "tags" => %w[a b], "active" => true, "none" => nil
      )
    end

    it "accepts array and scalar data" do
      expect(described_class.to_h(proto_for(success: true, data: [1, 2]))[:data]).to eq([1, 2])
      expect(described_class.to_h(proto_for(success: true, data: "ok"))[:data]).to eq("ok")
    end

    it "keeps an explicit false as data (only nil means no data)" do
      response = proto_for(success: true, data: false)

      expect(response.has_data?).to eq(true)
      expect(described_class.to_h(response)[:data]).to eq(false)
    end

    it "leaves data unset for nil" do
      expect(proto_for(success: true, data: nil).has_data?).to eq(false)
    end

    it "normalizes Symbols and Times inside data" do
      time     = Time.utc(2026, 10, 26, 10, 0, 0)
      response = proto_for(success: true, data: { kind: :admin, at: time })

      expect(described_class.to_h(response)[:data]).to eq("kind" => "admin", "at" => "2026-10-26T10:00:00Z")
    end

    it "packs a protobuf message as a typed payload" do
      page     = Respondo::V1::Pagination.new(current_page: 3, per_page: 10)
      response = proto_for(success: true, data: page)

      expect(response.has_payload?).to eq(true)
      expect(response.has_data?).to eq(false)
      expect(response.payload.unpack(Respondo::V1::Pagination).current_page).to eq(3)
    end

    it "maps field-level errors" do
      response = proto_for(success: false, errors: { email: ["is invalid", "is taken"], name: ["is blank"] })
      errors   = response.errors.map { |e| [e.field, e.messages.to_a] }

      expect(errors).to eq([["email", ["is invalid", "is taken"]], ["name", ["is blank"]]])
    end

    it "maps meta fields" do
      response = proto_for(success: false, meta: { code: 404, status: "not_found", grpc_code: 5, error_code: "GONE" })
      meta     = response.meta

      expect(meta.code).to eq(404)
      expect(meta.status).to eq("not_found")
      expect(meta.grpc_code).to eq(5)
      expect(meta.error_code).to eq("GONE")
      expect(meta.timestamp).not_to be_empty
    end

    it "maps pagination, leaving next/prev unset when nil" do
      response = proto_for(success: true, pagination: { current_page: 2, per_page: 10, total_pages: 3,
                                                        total_count: 25, next_page: 3, prev_page: nil })
      page = response.meta.pagination

      expect(page.current_page).to eq(2)
      expect(page.total_count).to eq(25)
      expect(page.has_next_page?).to eq(true)
      expect(page.next_page).to eq(3)
      expect(page.has_prev_page?).to eq(false)
    end

    it "puts default_meta and extra caller meta under meta.extra" do
      RespondoGrpc.configure { |c| c.default_meta = { api_version: "v1" } }
      response = proto_for(success: true, meta: { region: :eu })

      expect(response.meta.extra.to_h).to eq("api_version" => "v1", "region" => "eu")
    end
  end

  describe ".to_h" do
    it "mirrors the builder hash" do
      response = proto_for(success: false, message: "Validation failed",
                           errors: { email: ["is invalid"] },
                           meta: { code: 422, status: "unprocessable_content", grpc_code: 3 })
      result = described_class.to_h(response)

      expect(result[:success]).to eq(false)
      expect(result[:message]).to eq("Validation failed")
      expect(result[:errors]).to eq(email: ["is invalid"])
      expect(result[:meta]).to include(code: 422, status: "unprocessable_content", grpc_code: 3)
      expect(result).not_to include(:data)
    end

    it "decodes pagination with only the set optional fields" do
      response = proto_for(success: true, pagination: { current_page: 1, per_page: 2, total_pages: 1,
                                                        total_count: 2, next_page: nil, prev_page: nil })
      page = described_class.to_h(response)[:meta][:pagination]

      expect(page).to eq(current_page: 1, per_page: 2, total_pages: 1, total_count: 2)
    end
  end

  describe ".encode / .decode" do
    it "round-trips through the wire format" do
      response = proto_for(success: true, message: "Hi", data: { id: 1 })
      decoded  = described_class.decode(described_class.encode(response))

      expect(decoded).to eq(response)
    end
  end
end
