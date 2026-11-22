# frozen_string_literal: true

module VibeSort
  module SystemOne
    module Strategies
      # :noul - Pairwise Comparator Merge Sort.
      #
      # Each comparison is one binary "should A come strictly before B?" question.
      # Model judgments can be non-transitive (A < B < C < A), so this uses a plain
      # top-down merge sort, which always terminates in <= ceil(N log2 N)
      # comparisons, rather than Array#sort. Pair answers are cached symmetrically.
      class NoulSort < Base
        BEFORE_THRESHOLD = 0.55
        AFTER_THRESHOLD = 0.45

        private

        def perform(entries)
          @cache = {}
          @comparisons = Hash.new(0)
          sorted = merge_sort(entries)
          sorted.each { |e| record(e, comparisons: @comparisons[e.index]) }
          sorted
        end

        def merge_sort(entries)
          return entries if entries.size <= 1

          mid = entries.size / 2
          merge(merge_sort(entries[0...mid]), merge_sort(entries[mid..]))
        end

        def merge(left, right)
          merged = []
          merged << (compare(left.first, right.first) <= 0 ? left.shift : right.shift) until left.empty? || right.empty?
          merged + left + right
        end

        # @return [Integer] -1 if left belongs before right, 1 if after, 0 for a tie
        def compare(left, right)
          cached = @cache[[left.index, right.index]]
          return cached if cached

          result = judge(left, right)
          @cache[[left.index, right.index]] = result
          @cache[[right.index, left.index]] = -result
          result
        end

        def judge(left, right)
          @comparisons[left.index] += 1
          @comparisons[right.index] += 1
          state = { "sorting_goal" => goal, "direction" => direction_label,
                    "item_a" => left.serialized, "item_b" => right.serialized }
          answer = answer_for(ask(state: state, questions: { "a_before_b" => question }), "a_before_b", "noul")
          probability = answer["noul"].to_f
          return -1 if probability > BEFORE_THRESHOLD
          return 1 if probability < AFTER_THRESHOLD

          0
        end

        def question
          {
            "type" => "noul",
            "instructions" => "When sorting by `sorting_goal` (#{direction_label}), should `item_a` come strictly before `item_b`?",
            "criteria" => {
              "true" => "`item_a` belongs earlier in the sorted order than `item_b`",
              "false" => "`item_b` belongs earlier than `item_a`, or they are tied"
            }
          }
        end
      end
    end
  end
end
