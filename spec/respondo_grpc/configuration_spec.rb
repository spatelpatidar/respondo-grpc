# frozen_string_literal: true

require "spec_helper"

RSpec.describe RespondoGrpc::Configuration do
  subject(:config) { described_class.new }

  it "has sensible defaults" do
    expect(config.default_success_message).to eq("Success")
    expect(config.default_error_message).to eq("An error occurred")
    expect(config.include_request_id).to eq(false)
    expect(config.request_id_key).to eq("x-request-id")
    expect(config.serializer).to be_nil
    expect(config.default_meta).to eq({})
    expect(config.always_ok).to eq(false)
    expect(config.status_map).to eq({})
  end

  describe "RespondoGrpc.configure" do
    it "yields the shared configuration" do
      RespondoGrpc.configure do |c|
        c.default_success_message = "OK"
        c.always_ok               = true
      end

      expect(RespondoGrpc.config.default_success_message).to eq("OK")
      expect(RespondoGrpc.config.always_ok).to eq(true)
    end

    it "is restored to defaults by reset!" do
      RespondoGrpc.configure { |c| c.always_ok = true }
      RespondoGrpc.reset!

      expect(RespondoGrpc.config.always_ok).to eq(false)
    end
  end
end
