# frozen_string_literal: true

require "simplecov"
SimpleCov.start do
  add_filter "/spec/"
  add_filter "lib/respondo_graphql/version.rb"
  add_filter "lib/respondo_graphql/railtie.rb"
  add_filter "lib/respondo-graphql.rb"
  track_files "lib/**/*.rb"
end

require "respondo_graphql"

RSpec.configure do |config|
  config.example_status_persistence_file_path = "spec/respondo_graphql_test.txt"
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.before(:each) do
    RespondoGraphql.reset!
  end
end
