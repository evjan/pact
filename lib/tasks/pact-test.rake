require './lib/pact/producer/pact_spec_runner'

namespace :pact do

	desc 'Runs pact tests against a sample application, testing failure and success.'
	task :tests do
		# Run these specs silently, otherwise expected failures will be written to stdout and look like unexpected failures.

		result = Pact::Producer::PactSpecRunner.run([{ uri: './spec/support/test_app_pass.json', support_file: './spec/support/pact_rake_support.rb' }], silent: true)
		fail 'Expected pact to pass' unless (result == 0)

		result = Pact::Producer::PactSpecRunner.run([{ uri: './spec/support/test_app_fail.json', support_file: './spec/support/pact_rake_support.rb' }], silent: true)
		fail 'Expected pact to fail' if (result == 0)
	end

end