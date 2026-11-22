# frozen_string_literal: true

require "date"
require "time"

module VibeSort
  module SystemOne
    # Prepares arbitrary Ruby values for TypeSafe's strict JSON rules (no NaN or
    # Infinity, valid UTF-8, nesting depth <= 64) without mutating the originals.
    module Serializer
      # TypeSafe rejects nesting deeper than 64; leave headroom for the wrapper keys
      # vibe-sort adds around each value (state -> candidates -> i_0 -> ...).
      MAX_DEPTH = 50
      MAX_SAFE_INTEGER = (2**53) - 1
      BOM = "﻿"
      CIRCULAR = "[Circular]"

      module_function

      # @param value [Object] any Ruby value
      # @return [Object] a JSON-safe copy (Hash with String keys, Array, String, Integer, Float, true/false/nil)
      def call(value)
        serialize(value, 0, {})
      end

      def serialize(value, depth, stack)
        case value
        when nil, true, false then value
        when String then clean_string(value)
        when Symbol then clean_string(value.to_s)
        when Integer then integer(value)
        when Float then float(value)
        when Hash, Array then container(value, depth, stack)
        else scalar_or_object(value, depth, stack)
        end
      end

      def integer(value)
        value.abs > MAX_SAFE_INTEGER ? value.to_s : value
      end

      def float(value)
        return "NaN" if value.nan?
        return value.positive? ? "Infinity" : "-Infinity" if value.infinite?

        value
      end

      def container(value, depth, stack)
        id = value.object_id
        return CIRCULAR if stack.key?(id)
        return clean_string(value.inspect) if depth >= MAX_DEPTH

        stack[id] = true
        begin
          if value.is_a?(Hash)
            value.each_with_object({}) { |(k, v), out| out[clean_string(k.to_s)] = serialize(v, depth + 1, stack) }
          else
            value.map { |v| serialize(v, depth + 1, stack) }
          end
        ensure
          stack.delete(id)
        end
      end

      def scalar_or_object(value, depth, stack)
        return big_decimal(value) if big_decimal?(value)
        return clean_string(value.iso8601) if value.is_a?(Time) || value.is_a?(Date)
        return clean_string(value.to_s) if value.is_a?(Numeric) # Rational, Complex, ...

        if value.respond_to?(:to_h)
          hash = begin
            value.to_h
          rescue StandardError
            nil
          end
          return serialize(hash, depth, stack) if hash.is_a?(Hash)
        end
        clean_string(safe_to_s(value))
      end

      def big_decimal?(value)
        defined?(::BigDecimal) && value.is_a?(::BigDecimal)
      end

      def big_decimal(value)
        return "NaN" if value.nan?
        return value.positive? ? "Infinity" : "-Infinity" if value.infinite?

        value.to_s("F")
      end

      def safe_to_s(value)
        value.to_s
      rescue StandardError
        value.inspect
      end

      # Strip a leading BOM and replace invalid/undefined byte sequences.
      def clean_string(string)
        utf8 = to_utf8(string)
        utf8 = utf8.delete_prefix(BOM) if utf8.start_with?(BOM)
        utf8
      end

      def to_utf8(string)
        copy = if [Encoding::UTF_8, Encoding::BINARY].include?(string.encoding)
                 string.dup.force_encoding(Encoding::UTF_8)
               else
                 string.encode("UTF-8", invalid: :replace, undef: :replace)
               end
        copy.scrub
      rescue EncodingError
        string.dup.force_encoding(Encoding::BINARY).force_encoding(Encoding::UTF_8).scrub
      end
    end
  end
end
