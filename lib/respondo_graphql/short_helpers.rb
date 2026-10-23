# frozen_string_literal: true

module RespondoGraphql
  # Short names: `render_ok`, `render_not_found`, ... Each one simply calls its
  # render_graphql_* twin.
  #
  # The Railtie includes this module for you when the respondo (JSON) gem is NOT
  # installed, so `render_ok` just works. When respondo IS installed it is not included
  # (those names are respondo's JSON helpers). You can still opt in per controller:
  #
  #   class GraphqlController < ApplicationController
  #     include RespondoGraphql::ShortHelpers
  #
  #     def execute
  #       render_ok(data: result)   # same as render_graphql_ok(data: result)
  #     end
  #   end
  #
  # In that controller the short names then mean GraphQL, and a warning is printed
  # when the JSON helpers are visible there, so the switch is never silent.
  module ShortHelpers
    def self.included(base)
      base.include(ControllerHelpers)
      return unless defined?(::Respondo::ControllerHelpers) && base.ancestors.include?(::Respondo::ControllerHelpers)

      warn "[respondo-graphql] #{base} includes RespondoGraphql::ShortHelpers while respondo's JSON helpers " \
           "are available: render_ok & co. now answer in GraphQL in this controller. " \
           "Use render_graphql_* everywhere if it also needs JSON."
    end

    (ControllerHelpers::SUCCESS_HELPERS.keys + ControllerHelpers::ERROR_HELPERS.keys).each do |name|
      define_method(:"render_#{name}") do |**options|
        public_send(:"render_graphql_#{name}", **options)
      end
    end
  end
end
