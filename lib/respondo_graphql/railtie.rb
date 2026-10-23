# frozen_string_literal: true

module RespondoGraphql
  # Includes this gem's helpers into ActionController::Base and ActionController::API,
  # so no `include` is needed in a controller.
  #
  #   * render_graphql_ok, render_graphql_not_found, ...  always.
  #   * render_ok, render_not_found, ...  (RespondoGraphql::ShortHelpers) only when the
  #     respondo (JSON) gem is NOT loaded. With respondo present those short names
  #     belong to respondo (JSON), so they are left alone; use render_graphql_* for
  #     GraphQL, or `include RespondoGraphql::ShortHelpers` in a controller that
  #     should answer `render_ok` in GraphQL.
  #
  # The check runs when ActionController loads, after Bundler has required every gem,
  # so the order of the gems in the Gemfile does not matter.
  class Railtie < Rails::Railtie
    initializer "respondo_graphql.include_controller_helpers" do
      ActiveSupport.on_load(:action_controller_base) do
        include RespondoGraphql::ControllerHelpers
        include RespondoGraphql::ShortHelpers unless RespondoGraphql.json_gem_loaded?
      end

      ActiveSupport.on_load(:action_controller_api) do
        include RespondoGraphql::ControllerHelpers
        include RespondoGraphql::ShortHelpers unless RespondoGraphql.json_gem_loaded?
      end
    end
  end
end
