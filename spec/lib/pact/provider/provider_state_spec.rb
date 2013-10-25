require 'spec_helper'
require 'pact/provider/provider_state'

module Pact
  module Provider

    describe 'global ProviderState' do

      MESSAGES = []

      Pact.provider_state :no_alligators do
        set_up do
          MESSAGES << 'set_up'
        end
        tear_down do
          MESSAGES << 'tear_down'
        end
      end

      Pact.provider_state 'some alligators' do
      end

      before do
        MESSAGES.clear
      end

      subject { ProviderState.get('no_alligators') }

      describe 'set_up' do
        it 'should call the block passed to set_up' do
          subject.set_up
          MESSAGES.should eq ['set_up']
        end
      end

      describe 'tear_down' do
        it 'should call the block passed to set_up' do
          subject.tear_down
          MESSAGES.should eq ['tear_down']
        end
      end

      describe '.get' do
        context 'when the name is a matching symbol' do
          it 'will return the ProviderState' do
            ProviderState.get('no_alligators').should_not be_nil
          end
        end
        context 'when the name is a matching string' do
          it 'will return the ProviderState' do
            ProviderState.get('some alligators').should_not be_nil
          end
        end
      end
    end


    describe 'namespaced ProviderStates' do

      NAMESPACED_MESSAGES = []

      Pact.with_consumer 'a consumer' do
        provider_state 'the weather is sunny' do
          set_up do
            NAMESPACED_MESSAGES << 'sunny!'
          end
        end
      end

      Pact.provider_state 'the weather is cloudy' do
        set_up do
          NAMESPACED_MESSAGES << 'cloudy :('
        end
      end

      before do
        NAMESPACED_MESSAGES.clear
      end

      describe '.get' do
        context 'for a consumer' do
          it 'has a namespaced name' do
            ProviderState.get('the weather is sunny', :for => 'a consumer').should_not be_nil
          end

          it 'falls back to a global state of the same name if one is not found for the specified consumer' do
            ProviderState.get('the weather is cloudy', :for => 'a consumer').should_not be_nil
          end
        end

      end

      describe 'set_up' do
        context 'for a consumer' do
          it 'runs its own setup' do
            ProviderState.get('the weather is sunny', :for => 'a consumer').set_up
            NAMESPACED_MESSAGES.should eq ['sunny!']
          end
        end
      end
    end
  end
end
