require 'pact/consumer/mock_service_interaction_expectation'

module Pact
  module Consumer
    class MockServiceClient

      MOCK_SERVICE_ADMINISTRATON_HEADERS = {'X-Pact-Mock-Service' => 'true'}

      def initialize port
        @http = Net::HTTP.new('localhost', port)
      end

      def verify example_description
        response = http.request_get("/verify?example_description=#{URI.encode(example_description)}", MOCK_SERVICE_ADMINISTRATON_HEADERS)
        raise response.body unless response.is_a? Net::HTTPSuccess
      end

      def log msg
        http.request_get("/log?msg=#{URI.encode(msg)}", MOCK_SERVICE_ADMINISTRATON_HEADERS)
      end

      def wait_for_interactions wait_max_seconds, poll_interval
        wait_until_true(wait_max_seconds, poll_interval) do
          response = http.request_get("/number_of_missing_interactions", MOCK_SERVICE_ADMINISTRATON_HEADERS)
          response.body == '0'
        end
      end

      def clear_interactions example_description
        http.delete("/interactions?example_description=#{URI.encode(example_description)}", MOCK_SERVICE_ADMINISTRATON_HEADERS)
      end

      def add_expected_interaction interaction
        http.request_post('/interactions', MockServiceInteractionExpectation.new(interaction).to_json, MOCK_SERVICE_ADMINISTRATON_HEADERS)
      end

      def self.clear_interactions port, example_description
        Net::HTTP.new("localhost", port).delete("/interactions?example_description=#{URI.encode(example_description)}", MOCK_SERVICE_ADMINISTRATON_HEADERS)
      end

      private
      attr_reader :http

      #todo: in need a better home (where can we move it?)
      def wait_until_true timeout=3, interval=0.1
        time_limit = Time.now + timeout
        loop do
          result =  yield
          return if result || Time.now >= time_limit
          sleep interval
        end
      end

    end
  end
end