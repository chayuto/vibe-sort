# frozen_string_literal: true

module VibeSort
  module SystemOne
    module Strategies
      # :score - Normalized Batch Score Sort.
      #
      # One request rates every item on a relative min-max rubric; items are then
      # sorted in Ruby by score (stable on input index). Optionally one more batched
      # request settles adjacent near-ties and low-confidence neighbours.
      #
      # Options: rubric (Array<String>, 2..10), tie_break, tie_epsilon, confidence_floor.
      class ScoreSort < Base
        MIN_LEVELS = 2
        MAX_LEVELS = 10
        TIE_BREAK_MIN_CONFIDENCE = 0.5

        def initialize(**kwargs)
          super
          @rubric = @options[:rubric] || default_rubric
          validate_rubric!(@rubric)
        end

        private

        # Scores are position-relative to an *ascending* arrangement; :desc is applied
        # by reversing the Ruby sort, so the rubric must not also be flipped.
        def default_goal
          "natural ascending order"
        end

        def default_rubric
          [
            "At the absolute bottom / very start of this array for: #{goal}",
            "Clearly below the middle of this array for: #{goal}",
            "Right around the middle / average of this array for: #{goal}",
            "Clearly above the middle of this array for: #{goal}",
            "At the absolute top / very end of this array for: #{goal}"
          ]
        end

        def validate_rubric!(rubric)
          valid = rubric.is_a?(Array) && rubric.size.between?(MIN_LEVELS, MAX_LEVELS) &&
                  rubric.all? { |level| level.is_a?(String) && !level.strip.empty? }
          return if valid

          raise ArgumentError, "rubric must be an Array of #{MIN_LEVELS}..#{MAX_LEVELS} non-empty descriptive strings"
        end

        def perform(entries)
          scores = rate(entries)
          sorted = entries.sort_by { |e| desc? ? [-scores[e.index], e.index] : [scores[e.index], e.index] }
          sorted = break_ties(sorted) if @options.fetch(:tie_break, true)
          sorted
        end

        def rate(entries)
          state = { "sorting_goal" => goal, "items" => entries.to_h { |e| ["i_#{e.index}", e.serialized] } }
          questions = entries.to_h do |e|
            ["s_#{e.index}", {
              "type" => "score",
              "instructions" => "Rate item `i_#{e.index}` (#{e.serialized.inspect}) relative to all `items` in `state` for: #{goal}",
              "criteria" => @rubric
            }]
          end
          answers = ask(state: state, questions: questions)
          entries.to_h { |e| [e.index, read_score(e, answer_for(answers, "s_#{e.index}", "score"))] }
        end

        def read_score(entry, answer)
          score = answer["score"].to_f
          confidence = answer["confidence"]&.to_f
          record(entry, score: score, confidence: confidence, probabilities: answer["probabilities"])
          @warnings << "Low confidence (#{confidence.round(2)}) scoring item #{entry.index}; its score may be bimodal" if confidence && confidence < floor
          score
        end

        def floor
          @options.fetch(:confidence_floor, 0.60)
        end

        def break_ties(sorted)
          pairs = ambiguous_pairs(sorted)
          return sorted if pairs.empty?

          state = { "sorting_goal" => goal, "direction" => direction_label }
          questions = pairs.to_h { |idx, left, right| ["pair_#{idx}", pair_question(left, right)] }
          answers = ask(state: state, questions: questions)
          apply_swaps(sorted, pairs, answers)
        end

        def ambiguous_pairs(sorted)
          epsilon = @options.fetch(:tie_epsilon, 0.15)
          sorted.each_cons(2).with_index.filter_map do |(left, right), idx|
            l = @metadata[left.index]
            r = @metadata[right.index]
            close = (l[:score] - r[:score]).abs < epsilon
            unsure = [l[:confidence], r[:confidence]].any? { |c| c && c < floor }
            [idx, left, right] if close || unsure
          end
        end

        def pair_question(left, right)
          {
            "type" => "choice",
            "instructions" => "Which item should come first in the sorted order for `sorting_goal` (#{direction_label})?",
            "criteria" => { "left" => left.serialized, "right" => right.serialized }
          }
        end

        def apply_swaps(sorted, pairs, answers)
          result = sorted.dup
          used = {}
          pairs.each do |idx, _left, _right|
            answer = answers["pair_#{idx}"]
            next unless answer.is_a?(Hash) && answer["choice"] == "right"
            next unless answer["confidence"].to_f >= TIE_BREAK_MIN_CONFIDENCE
            next if used[idx] || used[idx + 1]

            result[idx], result[idx + 1] = result[idx + 1], result[idx]
            used[idx] = used[idx + 1] = true
          end
          result
        end
      end
    end
  end
end
