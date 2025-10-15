# frozen_string_literal: true

module VibeSort
  # Custom error class for API-related errors
  class ApiError < StandardError
    attr_reader :response

    # Initialize a new ApiError
    #
    # @param message [String] Error message
    # @param response [Faraday::Response, nil] HTTP response object
    def initialize(message, response = nil)
      super(message)
      @response = response
    end
  end
end
