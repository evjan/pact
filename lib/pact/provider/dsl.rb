module Pact

   module Provider
      module DSL

         #TODO: Move this into a module, out of configuration
         module Configuration
            def provider= provider
               @provider = provider
            end

            def provider
              if defined? @provider
                @provider
              else
                raise "Please configure your provider. See the Provider section in the README for examples."
              end
            end            
         end

         Pact::Configuration.send(:include, Configuration)

         def service_provider name, &block
            service_provider = ServiceProviderDSL.new(name, &block).create_service_provider
            Pact.configuration.provider = service_provider
            service_provider
         end

        class ServiceProviderConfig
           attr_accessor :name

           def initialize name, &app_block
             @name = name
             @app_block = app_block
           end

           def app
             @app_block.call
           end
         end

         class ServiceProviderDSL

           def initialize name, &block
             @name = name
             @app = nil
             instance_eval(&block)
           end

           def validate
             raise "Please provide a name for the Provider" unless @name && !@name.strip.empty?
             raise "Please configure an app for the Provider" unless @app_block
           end

           def name name
             @name = name
           end

           def app &block
             @app_block = block
           end

           def create_service_provider
             validate
             ServiceProviderConfig.new(@name, &@app_block)
           end
         end
      end
   end
end

Pact.send(:extend, Pact::Provider::DSL)