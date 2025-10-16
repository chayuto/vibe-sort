# frozen_string_literal: true

RSpec.describe VibeSort do
  describe "::VERSION" do
    it "is defined" do
      expect(described_class::VERSION).not_to be_nil
    end
  end

  describe VibeSort::Client do
    let(:api_key) { "test-key" }
    let(:client) { described_class.new(api_key: api_key) }

    context "when the input contains unsupported types" do
      it "returns an error without calling the API" do
        result = client.sort([1, :invalid, "hello"])

        expect(result[:success]).to be(false)
        expect(result[:sorted_array]).to eq([])
        expect(result[:error]).to eq("Input must be an array of numbers or strings")
      end
    end

    context "when the input array is empty" do
      it "returns an error" do
        result = client.sort([])

        expect(result[:success]).to be(false)
        expect(result[:error]).to eq("Input must be an array of numbers or strings")
      end
    end
  end
end
