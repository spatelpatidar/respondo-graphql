# frozen_string_literal: true

module RespondoGraphql
  # Includes RespondoGraphql::ControllerHelpers into ActionController::Base and
  # ActionController::API so no `include` is needed in ApplicationController.
  #
  # Skipped when config.auto_include is false, or when the respondo (JSON) gem
  # is also loaded — both gems define the same helper names, so the last one
  # included would silently win in every controller. In that case include
  # RespondoGraphql::ControllerHelpers in your GraphQL controller yourself; a
  # module included in a subclass takes precedence over its parent's helpers.
  class Railtie < Rails::Railtie
    initializer "respondo_graphql.include_controller_helpers" do
      ActiveSupport.on_load(:action_controller_base) do
        include RespondoGraphql::ControllerHelpers if RespondoGraphql.auto_include?
      end

      ActiveSupport.on_load(:action_controller_api) do
        include RespondoGraphql::ControllerHelpers if RespondoGraphql.auto_include?
      end
    end
  end
end
