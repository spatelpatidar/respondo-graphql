# Changelog

## [0.2.0] — Prefixed helpers, short names only without respondo (breaking vs. 0.1.0)

### Changed (breaking)
- **Every helper is now `render_graphql_*`** (`render_ok` -> `render_graphql_ok`,
  `render_not_found` -> `render_graphql_not_found`, … all 50). In 0.1.0 the names were
  identical to the `respondo` (JSON) gem's, so a project using both could get the
  wrong format depending on where a module was included. With the prefix,
  `render_ok` is always JSON and `render_graphql_ok` is always GraphQL.
- Private methods are prefixed too (`render_graphql_success`, `render_graphql_error`,
  `extract_graphql_errors`), because `respondo` defines private `render_success`,
  `render_error` and `extract_errors` that would otherwise collide.
- The Railtie always includes the `render_graphql_*` helpers into `ActionController::Base` /
  `::API`. The short names (`render_ok`, …) are included as well when the `respondo` (JSON)
  gem is **not** loaded; with `respondo` present they are left to respondo (JSON).

### Removed (breaking)
- `config.auto_include` and `RespondoGraphql.auto_include?`. The option existed only to
  avoid the name collision, and it was easy to misread. Delete any
  `config.auto_include = ...` line from your initializer (the generator only ever wrote
  it as a comment).

### Added
- `RespondoGraphql::ShortHelpers`: the short names (`render_ok`, `render_not_found`, … all
  50), each delegating to its `render_graphql_*` twin. Included for you when `respondo`
  is not installed; with `respondo` installed, include it explicitly in the controllers
  where you want `render_ok` to be GraphQL (it warns when `respondo`'s JSON helpers are
  also visible there).
- `RespondoGraphql.json_gem_loaded?`.

### Migrating from 0.1.0
- Without `respondo`: nothing to do, `render_ok` and `render_graphql_ok` both work.
- With `respondo`: rename `render_` to `render_graphql_` in your GraphQL controllers (or
  `include RespondoGraphql::ShortHelpers` in them to keep the short names there).

Arguments and output are unchanged. Do not put `ShortHelpers` in a controller that also
needs `render_ok` to be JSON.

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
