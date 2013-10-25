require 'bundler/gem_helper'
module Bundler
  class GemHelper
    def install
      desc "Build #{name}-#{version}.gem into the pkg directory"
      task 'build' do
        build_gem
      end

      desc "Build and install #{name}-#{version}.gem into system gems"
      task 'install' do
        install_gem
      end

      GemHelper.instance = self
    end
  end
end
Bundler::GemHelper.install_tasks
require 'rspec/core/rake_task'

Dir.glob('lib/tasks/**/*.rake').each { |task| load task }
Dir.glob('tasks/**/*.rake').each { |task| load task }
RSpec::Core::RakeTask.new(:spec)

task :default => [:spec, 'pact:tests']

desc "Release to REA gems host"
task :publish => :build do
  gem_file = "pkg/pact-#{Pact::VERSION}.gem"
  require 'geminabox-client'
  Geminabox::Client.new('http://rea-rubygems').upload(gem_file)
end
