require 'pact/matchers'
require 'pact/consumer/mock_service/rack_request_helper'

module Pact
  module Consumer

    class InteractionReplay
      include Pact::Matchers
      include RackRequestHelper

      def initialize name, logger, interaction_list
        @name = name
        @logger = logger
        @interaction_list = interaction_list
      end

      def match? env
        true # default handler
      end

      def respond env
        find_response request_as_hash_from(env)
      end

      private

      def find_response request_hash
        actual_request = Request::Actual.from_hash(request_hash)
        @logger.info "#{@name} received request #{actual_request.method_and_path}"
        @logger.ap actual_request.as_json
        candidate_interactions = @interaction_list.find_candidate_interactions actual_request
        matching_interactions = find_matching_interactions actual_request, from: candidate_interactions

        case matching_interactions.size
        when 0 then handle_unrecognised_request actual_request, candidate_interactions
        when 1 then handle_matched_interaction matching_interactions.first
        else
          handle_more_than_one_matching_interaction actual_request, matching_interactions
        end
      end

      def find_matching_interactions actual_request, opts
        candidate_interactions = opts.fetch(:from)
        candidate_interactions.select do | candidate_interaction |
          candidate_interaction.request.matches? actual_request
        end        
      end 

      def handle_matched_interaction interaction
        @interaction_list.register_matched interaction
        response = response_from(interaction.response)
        @logger.info "Found matching response on #{@name}:"
        @logger.ap interaction.response
        response        
      end

      def multiple_interactions_found_response actual_request, matching_interactions
        response = {
          message: "Multiple interaction found for #{actual_request.method_and_path}", 
          matching_interactions:  matching_interactions.collect{ | interaction | request_summary_for(interaction) }
        }
        [500, {'Content-Type' => 'application/json'}, [response.to_json]]
      end

      def handle_more_than_one_matching_interaction actual_request, matching_interactions
        @logger.error "Multiple interactions found on #{@name}:"
        @logger.ap matching_interactions.collect(&:as_json)
        multiple_interactions_found_response actual_request, matching_interactions
      end

      def interaction_diffs actual_request, candidate_interactions
        candidate_interactions.collect do | candidate_interaction |
          diff = candidate_interaction.request.difference(actual_request)
          diff_summary_for candidate_interaction, diff
        end        
      end

      def diff_summary_for interaction, diff
        summary = {:description => interaction.description}
        summary[:provider_state] = interaction.provider_state if interaction.provider_state
        summary.merge(diff)
      end

      def request_summary_for interaction
        summary = {:description => interaction.description}
        summary[:provider_state] if interaction.provider_state
        summary[:request] = interaction.request
        summary
      end

      def unrecognised_request_response actual_request, interaction_diffs
        response = {
          message: "No interaction found for #{actual_request.method_and_path}", 
          interaction_diffs:  interaction_diffs
        }
        [500, {'Content-Type' => 'application/json'}, [response.to_json]]
      end

      def log_unrecognised_request_and_interaction_diff actual_request, interaction_diffs, candidate_interactions
        @logger.error "No interaction found on #{@name} for #{actual_request.method_and_path}"
        @logger.error 'Interaction diffs for that route:'
        @logger.ap(interaction_diffs, :error)        
      end

      def handle_unrecognised_request actual_request, candidate_interactions
        @interaction_list.register_unexpected_request actual_request
        interaction_diffs = interaction_diffs(actual_request, candidate_interactions)
        log_unrecognised_request_and_interaction_diff actual_request, interaction_diffs, candidate_interactions
        unrecognised_request_response actual_request, interaction_diffs
      end

      def response_from response
        [response['status'], (response['headers'] || {}).to_hash, [render_body(response['body'])]]
      end

      def render_body body
        return '' unless body
        body.kind_of?(String) ? body.force_encoding('utf-8') : body.to_json
      end

      def logger_info_ap msg
        @logger.info msg
      end
    end
  end
end