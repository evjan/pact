# Pact

Define a pact between service consumers and providers.


Pact provides an RSpec DSL for service consumers to define the request they will make to a service service provider and the
response they expect back. This expectation is used in the consumers specs to provide a mock service provider, and is also
played back in the service provider specs to ensure the service provider actually does provide the response the consumer expects.

This allows you to test both sides of an integration point using fast unit tests.

This gem is inspired by the concept of "Consumer driven contracts". See http://martinfowler.com/articles/consumerDrivenContracts.html for more information.

## Features
* A services is mocked using an actual process running on a specified port, so javascript clients can be tested as easily as backend clients.
* "Provider states" (similar to fixtures) allow the same request to be made with a different expected response.
* Consumers specify only the fields they are interested in, allowing a provider to return more fields without breaking the pact. This allows a provider to have a different pact with a different consumer, and know which fields each cares about in a given response.
* Expected interactions are verified to have actually occurred.
* A rake verification task allows a pact at any URI to be checked against a given service provider codebase.
* Different versions of a consumer/provider pair can be easily tested against each other, allowing confidence when deploying new versions of each.

## Installation

Put it in your Gemfile. You know how.

## Usage

### Service Consumer project

#### Configuration

```ruby
Pact.configure do | config |
  config.pact_dir = "???" # Optional, default is ./spec/pacts
  config.log_dir = "???" # Optional, default is ./log
  config.logger = "??" # Optional, defaults to a file logger to the configured log_dir.
  config.logger.level = Logger::DEBUG #By default this is INFO, bump this up to debug for more detailed logs
  # Optional.
  # The default pactfile_write_mode is "defined?(Rake) ? :overwrite : :update"
  # This allows it to create a clean file when running rake, but only update the executed interactions when running a specific test using "rspec spec/...".
  # This is the recommended setting.
  config.pactfile_write_mode = :ovewrite / :update
end
```

#### Create a Consumer (Driven) Contract

```ruby
require 'pact/consumer/rspec'

class SomeServiceClient
  include HTTParty
  # Load your base_uri from a stub-able source
  base_uri App.configuration.some_service_base_uri

  def get_something
    JSON.parse(self.class.get("/something").body)
  end
end

Pact.service_consumer "My Consumer" do
  has_pact_with "My Provider" do
    mock_service :my_service_provider do
      port 1234
    end
  end
end

# The following block creates a service on localhost:1234 which will respond to your application's queries
# over HTTP as if it were the real "My Provider" app. It also creats a mock service provider object
# which you will use to set up your expectations. The method name to access the mock service provider
# will be what ever name you give as the service argument - in this case "my_service_provider"


# Use the :pact => true describe metadata to include all the pact generation functionality in your spec.

describe "a pact with My Provider", :pact => true do

  before do
    # Configure your client to point to the stub service on localhost using the port you have specified
    Application.configuration.stub(:some_service_base_uri).and_return('localhost:1234')
  end

  it "returns something when requested" do
    my_service_provider.
      given("something exists").
        upon_receiving("a request for something").
          with({ method: :get, path: '/something' }).
            will_respond_with({
              status: 200,
              headers: { 'Content-Type' => 'application/json' },
              body: {something: 'A thing!', something_else: 'Woot!'}
            })
    # Use your service's client to make the request, rather than hand crafting a HTTP request,
    # so that you can be sure that the request that you expect to
    # be constructed is actually constructed by your client.
    # Do a quick sanity test to ensure client passes back the response properly.
    expect(SomeServiceClient.get_something).to eql({something: 'A thing!'})
  end
end

```

Running the consumer spec will generate a pact file in the configured pact dir (spec/pacts by default).
Logs will be output to the configured log dir that can be useful when diagnosing problems.

To run your consumer app as a process during your test (eg for a Capybara test):

```ruby
Pact.service_consumer "My Consumer" do
  app my_consumer_rack_app
  port 4321
end
```

### Service Provider project

#### Configure your service provider

Create a `pact_helper.rb` in your service provider project. The file must be called pact_helper.rb, however there is some flexibility in where it can be stored. The recommended place is `specs/service_providers/pact_helper.rb`.

```ruby
require 'my_app' # Require the boot files for your app
require 'provider_states_for_my_consumer' # See next section on setting up provider states

Pact.service_provider "My Provider" do
  app { MyApp.new }

  honours_pact_with 'My Consumer' do
    # This example points to a local file, however, on a real project with a continuous
    # integration box, you could publish your pacts as artifacts,
    # and point this to the pact published by the last successful build.
    pact_uri '../path-to-your-consumer-project/specs/pacts/my_consumer-my_provider.json'
  end
end

```

#### Set up the service provider states

Having different service provider states allows you to test the same request with different expected responses.

For example, some code that creates the pact in a consumer project might look like this:

```ruby
my_service.
   given("a thing exists").
     upon_receiving("a request for a thing").
        with({method: 'get', path: '/thing'}).
          will_respond_with({status: 200, :body => {thing: "yay!"} })

my_service.
  given("a thing does not exist").
   upon_receiving("a request for a thing").
      with({method: 'get', path: '/thing'}).
        will_respond_with({status: 404, :body => {error: "There is no thing :("} })
```

To define service provider states that create the right data for "a thing exists" and "a thing does not exist", write the following in the service provider project.


```ruby
# The consumer name here must match the name of the consumer configured in your consumer project
# for it to correctly find these provider states.
# Make sure the provider states are included in or required by your pact_helper.rb file.

Pact.provider_states_for 'My Consumer' do
  provider_state "a thing exists" do
    set_up do
      # Create a thing here using your factory of choice
    end

    tear_down do
      # Any tear down steps to clean up your code (or use RSpec.after(:each))
    end
  end

  provider_state "a thing does not exist" do
    set_up do
      # Well, probably not much to do here, but you get the picture.
    end
  end
end

```

If a state should be used for all consumers, the top level Pact.with_consumer can be skipped, and a global Pact.provider_state can be defined on its own.

#### Verify that the service provider honours the pact

```ruby
  #In your Rakefile
  require 'pact/tasks'
```

```
  $ rake -T
  rake pact:verify               # Verifies the pact files configured in the pact_helper.rb against this service provider.
  rake pact:verify:at[pact_uri]  # Verifies the pact at the given URI against this service provider.
  $ rake pact:verify
```

#### Verification using arbitrary pact files

```
# Local URI
$ rake pact:verify:at[../path-to-your-consumer-project/specs/pacts/my_consumer-my_provider.json]

# Remote URI
$ rake pact:verify:at[http://build-box/MyConsumerBuild/latestSuccessful/artifacts/my_consumer-my_provider.json]
```

To make a shortcut task for pact at an arbitrary URI, add the following to your Rakefile.

```ruby
# This creates a rake task that can be executed by running
# $rake pact:verify:dev
Pact::VerificationTask.new(:dev) do | pact |
  pact.uri '../path-to-your-consumer-project/specs/pacts/my_consumer-my_provider.json'
end
```

The pact.uri may be a local file system path or a remote URL.


### Running a standalone mock server
A pact service can be run locally and is really useful for debugging purposes.

    $ bundle exec pact service -p <port-num>

The service prints messages it recieves to stdout which can be really useful
when diagnosing issues with pacts.

## TODO

Short term:
- Rename Pact to ConsumerContract (Done)
- Simplify set up for consumer (Done)
  - Move server spawning into to the "at" method (Done)
  - automatically register before and after hooks in consumer (Done)
- Provide before and after hooks and a place to define the app for Pact configuration in service provider (remove Rspc from interface of Pact setup) (Done)
  - Set_up for state
  - Tear_down for state
  - Before hook for all
  - After hook for all
- Make service provider state lookup try consumer defined state first, then fall back to global one (Done)
- Put service provider and consumer name into pact file (Done)
- Remove consumer name from the rake task, as it should now be able to be determined from the pact file. (Done)
- Provide more flexible matching (eg the keys should match, and the classes of the values should match, but the values of each key do not need to be equal). This is to make the pact verification less brittle.

Long term:
- Decouple Rspec from Pact and make rspec-pact gem for easy integration


## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
