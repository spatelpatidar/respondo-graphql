# frozen_string_literal: true

require "rake"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)
task default: :spec

# Build and publish by hand:
#   bundle exec rake spec
#   gem build respondo-graphql.gemspec
#   gem push respondo-graphql-<version>.gem
