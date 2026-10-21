# frozen_string_literal: true

require_relative "respondo_graphql/version"
require_relative "respondo_graphql/configuration"
require_relative "respondo_graphql/serializer"
require_relative "respondo_graphql/response_builder"
require_relative "respondo_graphql/controller_helpers"

# RespondoGraphql — consistent GraphQL-spec responses for Rails controllers.
#
# @example Configure once in an initializer
#   # config/initializers/respondo_graphql.rb
#   RespondoGraphql.configure do |config|
#     config.camelize_keys = true
#     config.always_ok     = true   # HTTP 200 for every response
#   end
#
# @example Use in a controller
#   class GraphqlController < ApplicationController
#     def show
#       render_ok(data: { user: User.find(params[:id]) }, message: "User fetched")
#     end
#   end
#
# @example Include manually (outside Rails, or next to the respondo JSON gem)
#   class GraphqlController < ApplicationController
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

    # Whether the Railtie should include the helpers into the base controllers.
    # False when the user turned it off, or when the respondo (JSON) gem is
    # loaded too (both define the same helper names).
    def auto_include?
      config.auto_include && !defined?(::Respondo::ControllerHelpers) ? true : false
    end
  end
end

# Auto-integrate with Rails if present
require_relative "respondo_graphql/railtie" if defined?(Rails::Railtie)
