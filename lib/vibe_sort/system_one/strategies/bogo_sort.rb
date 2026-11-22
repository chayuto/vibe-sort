# frozen_string_literal: true

module VibeSort
  module SystemOne
    module Strategies
      # :bogo - Vibe Bogosort.
      #
      # Shuffle, then ask Jev whether the array "looks sorted". Stop when the
      # probability clears +threshold+; otherwise give up after +max_attempts+ and
      # return the most convincing shuffle (or raise, with strict: true).
      #
      # Options: max_attempts (Integer >= 1 or Float::INFINITY), threshold (0..1),
      # strict (Boolean), rng (Random, for deterministic specs).
      class BogoSort < Base
        def initialize(**kwargs)
          super
          @max_attempts = @options.fetch(:max_attempts, 25)
          @threshold = @options.fetch(:threshold, 0.90)
          validate!
        end

        private

        def validate!
          raise ArgumentError, "max_attempts must be an Integer >= 1 (or Float::INFINITY)" unless @max_attempts == Float::INFINITY || (@max_attempts.is_a?(Integer) && @max_attempts >= 1)
          return if @threshold.is_a?(Numeric) && @threshold.between?(0, 1)

          raise ArgumentError, "threshold must be a number between 0 and 1"
        end

        def perform(entries)
          rng = @options[:rng] || Random
          best = entries
          best_probability = -1.0
          attempts = 0

          while attempts < @max_attempts
            attempts += 1
            candidate = entries.shuffle(random: rng)
            probability = sortedness(candidate)
            if probability > best_probability
              best = candidate
              best_probability = probability
            end
            return finish(best, best_probability, attempts) if probability >= @threshold
          end

          give_up(best, best_probability, attempts)
        end

        def sortedness(candidate)
          state = { "sorting_goal" => goal, "direction" => direction_label, "array" => candidate.map(&:serialized) }
          answers = ask(state: state, questions: { "is_sorted" => question })
          answer_for(answers, "is_sorted", "noul")["noul"].to_f
        end

        def question
          {
            "type" => "noul",
            "instructions" => "Is `array` completely sorted from first element to last element according to " \
                              "`sorting_goal` (#{direction_label})?",
            "criteria" => {
              "true" => "Every element is in the correct sorted position with no out-of-order elements",
              "false" => "At least one element is out of order"
            }
          }
        end

        def finish(best, probability, attempts)
          best.each { |e| record(e, sortedness_probability: probability, attempts: attempts) }
          best
        end

        def give_up(best, probability, attempts)
          raise BogoExhaustedError.new(attempts: attempts, best_probability: probability) if @options[:strict]

          @warnings << "Vibe bogosort hit its #{attempts}-attempt cap; returning the best shuffle (sortedness probability #{probability.round(3)})"
          finish(best, probability, attempts)
        end
      end
    end
  end
end
