# frozen_string_literal: true

require "spec_helper"

RSpec.describe RespondoGrpc::StatusMap do
  it "uses the canonical gRPC status numbers" do
    expect(described_class::CODES).to include(ok: 0, not_found: 5, invalid_argument: 3,
                                              unauthenticated: 16, unavailable: 14, internal: 13)
  end

  describe ".grpc_code_for" do
    {
      400 => 3, 401 => 16, 403 => 7, 404 => 5, 409 => 6, 412 => 9, 422 => 3,
      429 => 8, 500 => 13, 501 => 12, 503 => 14, 504 => 4
    }.each do |http, grpc|
      it "maps HTTP #{http} to gRPC #{grpc}" do
        expect(described_class.grpc_code_for(http)).to eq(grpc)
      end
    end

    it "maps every 4xx / 5xx helper code onto a defined gRPC status" do
      codes  = RespondoGrpc::ServiceHelpers::ERROR_HELPERS.values.map { |spec| spec[:code] }
      mapped = codes.map { |code| described_class.grpc_code_for(code) }

      expect(mapped.all? { |grpc| (1..16).cover?(grpc) }).to eq(true)
    end

    it "falls back by class for codes without an entry" do
      expect(described_class.grpc_code_for(299)).to eq(0)
      expect(described_class.grpc_code_for(499)).to eq(3)
      expect(described_class.grpc_code_for(599)).to eq(13)
      expect(described_class.grpc_code_for(302)).to eq(2)
    end

    it "honours config.status_map overrides (name or number)" do
      RespondoGrpc.configure { |c| c.status_map = { 409 => :aborted, 404 => 12 } }

      expect(described_class.grpc_code_for(409)).to eq(10)
      expect(described_class.grpc_code_for(404)).to eq(12)
    end
  end

  describe ".resolve" do
    it "accepts names in any case and integers" do
      expect(described_class.resolve(:not_found)).to eq(5)
      expect(described_class.resolve("NOT_FOUND")).to eq(5)
      expect(described_class.resolve(7)).to eq(7)
    end

    it "rejects unknown names" do
      expect { described_class.resolve(:nope) }.to raise_error(ArgumentError, /Unknown gRPC status/)
    end
  end

  describe ".name_for" do
    it "reverses a code" do
      expect(described_class.name_for(5)).to eq(:not_found)
    end
  end
end
