# Changelog

## [0.1.0] — Initial release

First release of `respondo-graphql`, the GraphQL sibling of the `respondo` JSON
gem. It is a standalone gem — no dependency on `respondo`.

### Added
- GraphQL-spec response envelope: `errors` (failures only), `data`, `extensions`.
- 50 status-aware controller helpers with the same names and signatures as
  `respondo`: ten 2xx helpers and forty 4xx/5xx helpers (`render_ok`,
  `render_not_found`, `render_unprocessable`, …). 1xx and 3xx are omitted on
  purpose — they have no meaning in a GraphQL response.
- Field-level errors become one `errors[]` entry per message, tagged
  `extensions.field`; `errors[0]` is always a summary carrying the message.
- Configuration: `default_success_message`, `default_error_message`,
  `include_request_id`, `camelize_keys`, `serializer`, `default_meta`,
  `data_key`, `always_ok`, `auto_include`.
- `always_ok` sends every response with HTTP 200 (Apollo-style clients).
- `data_key` wraps Array / scalar payloads, since GraphQL `data` must be a map.
- Railtie that includes the helpers into `ActionController::Base` / `::API`.
  It skips auto-include when the `respondo` JSON gem is loaded (both define the
  same helper names); include `RespondoGraphql::ControllerHelpers` in the
  GraphQL controller instead, where it takes precedence over the parent's helpers.
- `rails generate respondo_graphql:install` — interactive setup that writes
  `config/initializers/respondo_graphql.rb`.
