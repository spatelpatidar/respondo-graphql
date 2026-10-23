# frozen_string_literal: true

require_relative "respondo_graphql/version"
require_relative "respondo_graphql/configuration"
require_relative "respondo_graphql/serializer"
require_relative "respondo_graphql/response_builder"
require_relative "respondo_graphql/controller_helpers"
require_relative "respondo_graphql/short_helpers"

# RespondoGraphql — consistent GraphQL-spec responses for Rails controllers.
#
# @example Configure once in an initializer
#   # config/initializers/respondo_graphql.rb
#   RespondoGraphql.configure do |config|
#     config.camelize_keys = true
#     config.always_ok     = true   # HTTP 200 for every response
#   end
#
# @example Use in a controller (helpers are always render_graphql_*)
#   class GraphqlController < ApplicationController
#     def show
#       render_graphql_ok(data: { user: User.find(params[:id]) }, message: "User fetched")
#     end
#   end
#
# @example Without the respondo (JSON) gem: both names work, no include needed
#   render_ok(data: user)            # GraphQL
#   render_graphql_ok(data: user)    # GraphQL (same thing)
#
# @example Next to the respondo (JSON) gem: use the prefix for GraphQL
#   render_ok(data: user)            # JSON    (respondo)
#   render_graphql_ok(data: user)    # GraphQL (respondo-graphql)
#
# @example Include manually (outside Rails)
#   class GraphqlController
#     include RespondoGraphql::ControllerHelpers
#   end
module RespondoGraphql
  class << self
    # @return [RespondoGraphql::Configuration]
    def config
      @config ||= Configuration.new
    end

    # @yield [RespondoGraphql::Configuration]
    def configure
      yield config
    end

    # Reset config (useful in tests)
    def reset!
      @config = Configuration.new
    end

    # True when the respondo (JSON) gem is loaded. Its helpers use the same short
    # names (render_ok, ...), so only then are the short names left out and
    # render_graphql_* is the way to call this gem.
    def json_gem_loaded?
      defined?(::Respondo::ControllerHelpers) ? true : false
    end
  end
end

# Auto-integrate with Rails if present
require_relative "respondo_graphql/railtie" if defined?(Rails::Railtie)
