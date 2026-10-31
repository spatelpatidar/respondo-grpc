# frozen_string_literal: true

require "spec_helper"

RSpec.describe RespondoGrpc::Serializer do
  def serialize(object)
    described_class.call(object)
  end

  it "returns nil for nil" do
    expect(serialize(nil)).to be_nil
  end

  it "passes primitives through" do
    expect(serialize("a")).to eq("a")
    expect(serialize(3)).to eq(3)
    expect(serialize(true)).to eq(true)
  end

  it "serializes Hash values recursively" do
    expect(serialize(a: { b: [1, { c: nil }] })).to eq(a: { b: [1, { c: nil }] })
  end

  it "serializes Array items recursively" do
    expect(serialize([{ a: 1 }, 2])).to eq([{ a: 1 }, 2])
  end

  it "turns an exception into its message" do
    expect(serialize(StandardError.new("boom"))).to eq(message: "boom")
  end

  it "uses #to_h for Structs" do
    point = Struct.new(:x, :y).new(1, 2)

    expect(serialize(point)).to eq(x: 1, y: 2)
  end

  it "prefers #as_json when the object has one" do
    klass = Class.new do
      def as_json(*)
        { "id" => 7 }
      end
    end

    expect(serialize(klass.new)).to eq("id" => 7)
  end

  it "uses the configured custom serializer first" do
    RespondoGrpc.configure { |c| c.serializer = ->(obj) { { wrapped: obj } } }

    expect(serialize(5)).to eq(wrapped: 5)
  end
end
