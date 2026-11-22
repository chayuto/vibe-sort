# frozen_string_literal: true

module VibeSort
  module SystemOne
    module Strategies
      # :choice - Draft Pick Selection Sort.
      #
      # Repeatedly asks Jev to pick which remaining item comes NEXT, so N items take
      # N-1 calls. Items live in +state+ and the question's +criteria+ values are
      # null, which keeps the per-option token cost low. Arrays above the 255-option
      # limit are narrowed with tournament chunking before each pick.
      #
      # Options: shuffle_options (Boolean), rng (Random, for deterministic specs).
      class ChoiceSort < Base
        MAX_OPTIONS = 255
        TAIL_SIZE = 5
        CHUNKS_PER_REQUEST = 8

        private

        def perform(entries)
          remaining = entries.to_h { |e| [key(e), e] }
          sorted = []

          while remaining.size > 1
            winner_key, answer = pick_next(remaining, sorted)
            entry = remaining.delete(winner_key)
            record(entry, pick_round: sorted.size + 1, confidence: answer["confidence"],
                          probability: answer.dig("probabilities", winner_key))
            sorted << entry
          end
          sorted << remaining.values.first
        end

        def key(entry)
          "i_#{entry.index}"
        end

        def pick_next(remaining, sorted)
          tail = sorted.last(TAIL_SIZE).map(&:serialized)
          if remaining.size <= MAX_OPTIONS
            ask_for_winner(remaining, tail)
          else
            tournament(remaining, tail)
          end
        end

        # One choice question over <= 255 candidates held in state (null criteria).
        def ask_for_winner(remaining, tail)
          keys = shuffled(remaining.keys)
          state = base_state(tail).merge("candidates" => keys.to_h { |k| [k, remaining[k].serialized] })
          questions = { "pick_next" => choice_question(keys.to_h { |k| [k, nil] }) }
          extract_winner(ask(state: state, questions: questions)["pick_next"], keys)
        end

        # Above 255 candidates: fan out one question per chunk of <= 255 (descriptions
        # live in the criteria so each question only carries its own chunk), then run
        # a final choice over the chunk winners.
        def tournament(remaining, tail)
          winners = shuffled(remaining.keys).each_slice(MAX_OPTIONS).each_slice(CHUNKS_PER_REQUEST).flat_map do |batch|
            chunk_winners(batch, remaining, tail)
          end
          return winners.first if winners.size == 1

          final = winners.to_h { |k| [k, remaining[k].serialized] }
          answer = ask(state: base_state(tail), questions: { "pick_next" => choice_question(final) })["pick_next"]
          extract_winner(answer, winners)
        end

        def chunk_winners(batch, remaining, tail)
          questions = batch.each_with_index.to_h do |keys, i|
            ["chunk_#{i}", choice_question(keys.to_h { |k| [k, remaining[k].serialized] })]
          end
          answers = ask(state: base_state(tail), questions: questions)
          batch.each_with_index.map { |keys, i| extract_winner(answers["chunk_#{i}"], keys).first }
        end

        def base_state(tail)
          { "sorting_goal" => goal, "direction" => direction_label, "already_selected_tail" => tail }
        end

        def choice_question(criteria)
          {
            "type" => "choice",
            "instructions" => "Select the single candidate key that should come NEXT in the sorted order " \
                              "for `sorting_goal` (#{direction_label}).",
            "criteria" => criteria
          }
        end

        # @return [Array(String, Hash)] the winning key and its answer. Falls back to
        #   the most probable valid key if the model names an unknown one.
        def extract_winner(answer, valid_keys)
          raise ApiError, "System One response is missing a choice answer" unless answer.is_a?(Hash)

          chosen = answer["choice"]
          return [chosen, answer] if valid_keys.include?(chosen)

          probabilities = answer["probabilities"].is_a?(Hash) ? answer["probabilities"] : {}
          fallback = probabilities.slice(*valid_keys).max_by { |_, p| p.to_f }&.first
          @warnings << "Jev picked an unknown candidate (#{chosen.inspect}); used #{fallback ? "its most probable valid option" : "the first option"}"
          [fallback || valid_keys.first, answer]
        end

        def shuffled(keys)
          return keys unless @options.fetch(:shuffle_options, true)

          keys.shuffle(random: @options[:rng] || Random)
        end
      end
    end
  end
end
