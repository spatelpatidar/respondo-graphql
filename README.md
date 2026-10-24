<div align="center">

# Respondo Graphql 🎯

**Consistent GraphQL-spec responses for Rails controllers — in one line.**

[![CI Suite](https://github.com/spatelpatidar/respondo-graphql/actions/workflows/ci.yml/badge.svg)](https://github.com/spatelpatidar/respondo-graphql/actions/workflows/ci.yml)
[![Gem Version](https://badge.fury.io/rb/respondo-graphql.svg)](https://rubygems.org/gems/respondo-graphql)
[![Downloads](https://img.shields.io/gem/dt/respondo-graphql.svg)](https://rubygems.org/gems/respondo-graphql)
[![License: Apache 2.0](https://img.shields.io/badge/License-Apache2.0-green.svg)](LICENSE)
[![Ruby](https://img.shields.io/badge/Ruby-2.7%2B-red)](https://www.ruby-lang.org/)

</div>

---

`respondo-graphql` is the GraphQL sibling of [`respondo`](https://github.com/spatelpatidar/respondo) (JSON). It is a **standalone gem**: it has no dependency on `respondo`, its own namespace (`RespondoGraphql`), its own config, and its own generator. Install either one, or both.

It gives your controllers one expressive helper per situation (`render_graphql_ok`, `render_graphql_not_found`, `render_graphql_unprocessable`, …) and always answers in the GraphQL response shape: `data`, `errors`, `extensions`.

## Install

```ruby
# Gemfile
gem "respondo-graphql"
```

```bash
bundle install
rails generate respondo_graphql:install
```

The Railtie includes the helpers into `ActionController::Base` and `ActionController::API` for you, so no `include` is needed: `render_graphql_ok`, `render_graphql_not_found`, … always, and the short `render_ok`, `render_not_found`, … too when the `respondo` JSON gem is **not** installed. (If it is installed, see [Using both gems](#using-both-gems).)

## Usage

```ruby
class GraphqlController < ApplicationController
  def show
    user = User.find_by(id: params[:id])
    return render_graphql_not_found(message: "User not found") unless user

    render_graphql_ok(data: { user: user }, message: "User fetched")
  end

  def create
    user = User.new(user_params)
    if user.save
      render_graphql_created(data: { user: user }, message: "Account created")
    else
      render_graphql_unprocessable(message: "Validation failed", errors: user.errors)
    end
  end
end
```

**Success** — `render_graphql_ok(data: { user: { id: 1 } }, message: "User fetched")`

```json
{
  "data": { "user": { "id": 1 } },
  "extensions": { "message": "User fetched", "timestamp": "2026-10-04T10:30:00Z", "code": 200, "status": "ok" }
}
```

**Failure** — `data` is `null`, and `errors[0]` is always a summary carrying your message. Field-level errors follow, one entry per message:

```json
{
  "errors": [
    { "message": "Validation failed",
      "extensions": { "code": "UNPROCESSABLE_CONTENT", "http": { "status": 422 } } },
    { "message": "email is invalid",
      "extensions": { "code": "UNPROCESSABLE_CONTENT", "http": { "status": 422 }, "field": "email" } }
  ],
  "data": null,
  "extensions": { "message": "Validation failed", "timestamp": "2026-10-04T10:30:00Z", "code": 422, "status": "unprocessable_content" }
}
```

| What you pass | Where it ends up |
|---|---|
| `data:` | `data` — always a map or `null` |
| `message:` | `extensions.message`, and `errors[0].message` on failure |
| `meta:` / `pagination:` | `extensions` |
| `errors: { field: [...] }` | one `errors[]` entry per message, tagged `extensions.field` |
| success vs. failure | presence of the `errors` array |

GraphQL requires `data` to be a map, so an Array or scalar payload is wrapped as `{ "result": [...] }` (rename it with `config.data_key`).

## Helpers

Same helpers, signatures and statuses as the `respondo` JSON gem, with a `graphql_` infix: `render_ok` (JSON) becomes `render_graphql_ok` (GraphQL). Nothing is shared between the two gems, so using both in one project is safe (see [Using both gems](#using-both-gems)).

| Group | Helpers | Arguments |
|---|---|---|
| 2xx with payload | `render_graphql_ok` `render_graphql_created` `render_graphql_accepted` `render_graphql_non_authoritative` `render_graphql_partial_content` `render_graphql_multi_status` `render_graphql_already_reported` `render_graphql_im_used` | `data:` `message:` `meta:` `pagination:` |
| 2xx no payload | `render_graphql_no_content` `render_graphql_reset_content` | `message:` `meta:` `pagination:` |
| 4xx / 5xx | `render_graphql_bad_request` `render_graphql_unauthorized` `render_graphql_forbidden` `render_graphql_not_found` `render_graphql_conflict` `render_graphql_unprocessable` `render_graphql_too_many_requests` `render_graphql_server_error` `render_graphql_service_unavailable` … (40 in total) | `message:` `errors:` `meta:` |

**204 and 205 have no body.** HTTP forbids a body on `204 No Content` and `205 Reset Content`, and Rails drops it, so `render_graphql_no_content` and `render_graphql_reset_content` reach the client with an empty body. Use `render_graphql_ok` when the client needs the message, or set `config.always_ok = true` (every response becomes HTTP 200, body included).

1xx (informational) and 3xx (redirect) helpers are deliberately left out: they are transport-level and have no meaning in a GraphQL response. The full list is in `RespondoGraphql::ControllerHelpers::SUCCESS_HELPERS` and `ERROR_HELPERS`.

## Configuration

```ruby
# config/initializers/respondo_graphql.rb  (written by the generator)
RespondoGraphql.configure do |config|
  config.default_success_message = "Success"
  config.default_error_message   = "An error occurred"
  config.include_request_id      = false   # adds request_id to extensions
  config.camelize_keys           = false   # created_at -> createdAt
  config.always_ok               = false   # see below
  config.data_key                = :result # wrapper for Array / scalar data
  config.default_meta            = { api_version: "v1" }
  config.serializer              = ->(obj) { MySerializer.new(obj).as_json }
end
```

**`always_ok`** — many GraphQL clients, Apollo among them, treat non-2xx responses as network failures. Set `config.always_ok = true` to send every response with HTTP 200 and let the `errors` array carry the failure. The default (`false`) keeps each helper's own status (404 for `render_graphql_not_found`, …).

## Using both gems

`respondo` (JSON) and `respondo-graphql` can live in the same project. With `respondo` installed, the Railtie of each gem includes its own helpers into every controller and the `render_graphql_*` names never overlap with `respondo`'s, so there is nothing to configure:

```ruby
class ReportsController < ApplicationController
  def show
    render_ok(data: @report)            # JSON    — respondo
  end
end

class GraphqlController < ApplicationController
  def execute
    render_graphql_ok(data: @result)    # GraphQL — respondo-graphql
  end
end
```

`render_ok` is always JSON and `render_graphql_ok` is always GraphQL, in whichever controller you are, because every method this gem defines (public and private) carries the `render_graphql_` prefix. Each gem keeps its own configuration: `Respondo.configure` does not affect GraphQL responses, and `RespondoGraphql.configure` does not affect JSON ones.

### Which name do I use?

| Your project | `render_graphql_ok` | `render_ok` |
|---|---|---|
| only `respondo-graphql` | works, GraphQL | works, GraphQL (the short names are included for you) |
| `respondo-graphql` **and** `respondo` | works, GraphQL | respondo's JSON, so use the `render_graphql_*` names for GraphQL |

The gem checks whether `respondo` is loaded when Rails boots. There is no setting for it. The prefixed names work in both cases, so code written with them never changes meaning.

To get `render_ok` as GraphQL in one controller of a project that also has `respondo`, include the short names there on purpose:

```ruby
class GraphqlController < ApplicationController
  include RespondoGraphql::ShortHelpers   # explicit, per controller

  def execute
    render_ok(data: @result)              # = render_graphql_ok
  end
end
```

- It is never included automatically next to `respondo`, so it cannot change what `render_ok` means in a controller you did not choose.
- If the `respondo` JSON helpers are visible in that controller, a warning is printed when the class loads, so the switch is never silent. Use `render_graphql_*` in any controller that also needs JSON.
- Include it **after** the controller already has the JSON helpers (the normal Rails case: `ApplicationController` inherits them from `ActionController::API`). If you include `ShortHelpers` in a class and *then* include `Respondo::ControllerHelpers` in that same class, the JSON helpers come first and `render_ok` is JSON again.
- It includes `ControllerHelpers` for you, and the `render_graphql_*` names keep working.

## When to use this vs. graphql-ruby

Your GraphQL schema already produces valid responses for queries and mutations. RespondoGraphql is for everything your controller answers *outside* the schema — authentication failures, rate limits, malformed requests, REST-style endpoints that speak GraphQL-shaped JSON — so those responses look the same as the rest.

## Development

```bash
git clone https://github.com/spatelpatidar/respondo-graphql
cd respondo-graphql
bundle install
bundle exec rspec
```

## License

Released under the [Apache License 2.0](LICENSE).
