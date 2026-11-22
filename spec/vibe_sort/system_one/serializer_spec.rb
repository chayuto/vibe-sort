# frozen_string_literal: true

require "bigdecimal"
require "date"

RSpec.describe VibeSort::SystemOne::Serializer do
  def ser(value)
    described_class.call(value)
  end

  it "replaces non-finite floats with strings" do
    expect(ser([Float::NAN, Float::INFINITY, -Float::INFINITY, 1.5])).to eq(["NaN", "Infinity", "-Infinity", 1.5])
  end

  it "stringifies integers beyond 2**53 - 1 but keeps safe ones" do
    expect(ser([2**60, -(2**60), (2**53) - 1])).to eq([(2**60).to_s, (-(2**60)).to_s, (2**53) - 1])
  end

  it "stringifies BigDecimal" do
    expect(ser([BigDecimal("1.25"), BigDecimal("NaN"), BigDecimal("Infinity")])).to eq(["1.25", "NaN", "Infinity"])
  end

  it "replaces invalid UTF-8 and strips a leading BOM" do
    bad = "ok\xFFbyte".dup
    expect(ser(bad)).to eq("ok�byte")
    expect(ser("﻿hello")).to eq("hello")
    expect(ser("caf\xE9".dup.force_encoding("ISO-8859-1"))).to eq("café")
  end

  it "stringifies symbols and hash keys, and formats times" do
    expect(ser({ a: :b })).to eq("a" => "b")
    expect(ser(Date.new(2026, 11, 22))).to eq("2026-11-22")
    expect(ser(Time.utc(2026, 11, 22, 1, 2, 3))).to eq("2026-11-22T01:02:03Z")
  end

  it "serializes custom objects via to_h, falling back to to_s" do
    point = Struct.new(:x, :y).new(1, 2)
    exploding = Class.new do
      def to_h = raise("nope")
      def to_s = "exploding"
    end.new

    expect(ser(point)).to eq("x" => 1, "y" => 2)
    expect(ser(exploding)).to eq("exploding")
  end

  it "flattens structures deeper than MAX_DEPTH into strings" do
    deep = (1..70).reduce("leaf") { |inner, _| { "k" => inner } }
    out = ser(deep)

    depth = 0
    node = out
    while node.is_a?(Hash)
      node = node["k"]
      depth += 1
    end
    expect(depth).to eq(described_class::MAX_DEPTH)
    expect(node).to be_a(String)
  end

  it "replaces circular references instead of overflowing the stack" do
    hash = { "name" => "loop" }
    hash["self"] = hash
    array = [1]
    array << array

    expect(ser(hash)).to eq("name" => "loop", "self" => "[Circular]")
    expect(ser(array)).to eq([1, "[Circular]"])
  end

  it "does not treat repeated (non-circular) references as cycles" do
    shared = [1]

    expect(ser([shared, shared])).to eq([[1], [1]])
  end

  it "does not mutate its input" do
    original = { "a" => ["x\xFF".dup, Float::NAN] }
    snapshot = Marshal.load(Marshal.dump(original))

    ser(original)

    expect(original["a"][0].bytes).to eq(snapshot["a"][0].bytes)
    expect(original["a"][1]).to be_nan
  end
end
