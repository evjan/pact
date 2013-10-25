require 'pact/symbolize_keys'

module Pact
  class ServiceConsumer
    include SymbolizeKeys

    attr_accessor :name
    def initialize options
      @name = options[:name]
    end

    def to_s
      name
    end

    def as_json
      {name: name}
    end

    def self.from_hash hash
      new(symbolize_keys(hash))
    end
  end
end