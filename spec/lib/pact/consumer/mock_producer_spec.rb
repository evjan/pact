require 'spec_helper'
require 'fileutils'
require 'pathname'

module Pact
	module Consumer
		describe MockProducer do

		   describe "initialize" do
			   before do
			      Pact.clear_configuration
			      Pact.configuration.stub(:pact_dir).and_return(File.expand_path(tmp_pact_dir))
			      FileUtils.rm_rf tmp_pact_dir
			      FileUtils.mkdir_p tmp_pact_dir
			      FileUtils.cp './spec/support/a_consumer-a_producer.json', "#{tmp_pact_dir}/a_consumer-a_producer.json"
			   end

			   let(:tmp_pact_dir) {"./tmp/pacts"}

			   let(:consumer_name) { 'a consumer' }
			   let(:producer_name) { 'a producer' }
			   let(:mock_producer) { 
			      Pact::Consumer::MockProducer.new(
			         :pactfile_write_mode => pactfile_write_mode,
			         :consumer_name => consumer_name,
			         :producer_name => producer_name,
			         :port => 1234)}

			   context "when overwriting pact" do
			      let(:pactfile_write_mode) {:overwrite}
			      it "it overwrites the existing pact file" do
			         expect(mock_producer.consumer_contract.interactions).to eq []
			      end
			   end

			   context "when updating pact" do
			      let(:pactfile_write_mode) {:update}
			      it "updates the existing pact file" do
			         expect(mock_producer.consumer_contract.interactions.size).to eq 2
			      end
			   end		   	
		   end			

			describe "update_pactfile" do
				let(:pacts_dir) { Pathname.new("./tmp/pactfiles") }
				let(:expected_pact_path) { pacts_dir + "test_consumer-test_service.json" }
				let(:expected_pact_string) { 'the_json' }

				before do
					Pact.configuration.stub(:pact_dir).and_return(Pathname.new("./tmp/pactfiles"))
					FileUtils.rm_rf pacts_dir
					FileUtils.mkdir_p pacts_dir
					mock_producer = MockProducer.new(:consumer_name => 'test_consumer', :producer_name => 'test_service')
					JSON.should_receive(:pretty_generate).with(instance_of(Pact::ConsumerContract)).and_return(expected_pact_string)
					mock_producer.instance_variable_set('@interactions', { "some description" => double("interaction", as_json: "something") })
					mock_producer.update_pactfile
				end

			  it "should write to a file specified by the consumer and producer name" do
			  	File.exist?(expected_pact_path).should be_true
			  end

			  it "should write the interactions to the file" do
			  	File.read(expected_pact_path).should eql expected_pact_string
			  end
			end

			describe "handle_interaction_fully_defined" do

				subject { 
					Pact::Consumer::MockProducer.new({:consumer_name => 'blah', :producer_name => 'blah', :port => 2222})
				}

				let(:interaction_hash) {
					{
		            description: 'Test request',
		            request: {
		              method: 'post',
		              path: '/foo',
		              body: Term.new(generate: 'waffle', matcher: /ffl/),
		              headers: { 'Content-Type' => 'application/json' },
		              query: "",
		            },
		            response: {
		              baz: 'qux',
		              wiffle: 'wiffle'
		            }
	          	}
				}

				let(:interaction_json) { JSON.dump(interaction_hash) }

				let(:interaction) { Pact::Consumer::Interaction.from_hash(JSON.parse(interaction_json)) }

				before do
					stub_request(:post, 'localhost:2222/interactions')
				end

	        	it "posts the interaction with generated response to the mock service" do
	          	subject.handle_interaction_fully_defined interaction
	          	WebMock.should have_requested(:post, 'localhost:2222/interactions').with(body: interaction_json)
	        	end

	        	it "updates the Producer's Pactfile" do
	        		subject.consumer_contract.should_receive(:update_pactfile)
	        		subject.handle_interaction_fully_defined interaction
	        	end
			end
		end
	end
end