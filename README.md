<div align="center">

# Respondo Graphql 🎯

**Consistent GraphQL-spec responses for Rails controllers — in one line.**

</div>

---

`respondo-graphql` is the GraphQL sibling of [`respondo`](https://github.com/spatelpatidar/respondo) (JSON). It is a **standalone gem**: it has no dependency on `respondo`, its own namespace (`RespondoGraphql`), its own config, and its own generator. Install either one, or both.

It gives your controllers one expressive helper per situation (`render_ok`, `render_not_found`, `render_unprocessable`, …) and always answers in the GraphQL response shape: `data`, `errors`, `extensions`.

## Install

```ruby
# Gemfile
gem "respondo-graphql"
```

```bash
bundle install
rails generate respondo_graphql:install
```

The Railtie includes the helpers into `ActionController::Base` and `ActionController::API` for you. (If the `respondo` JSON gem is installed too, see [Using both gems](#using-both-gems).)

## Usage

```ruby
class GraphqlController < ApplicationController
  def show
    user = User.find_by(id: params[:id])
    return render_not_found(message: "User not found") unless user

    render_ok(data: { user: user }, message: "User fetched")
  end

  def create
    user = User.new(user_params)
    if user.save
      render_created(data: { user: user }, message: "Account created")
    else
      render_unprocessable(message: "Validation failed", errors: user.errors)
    end
  end
end
```

**Success** — `render_ok(data: { user: { id: 1 } }, message: "User fetched")`

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

Same names and signatures as the `respondo` JSON gem.

| Group | Helpers | Arguments |
|---|---|---|
| 2xx with payload | `render_ok` `render_created` `render_accepted` `render_non_authoritative` `render_partial_content` `render_multi_status` `render_already_reported` `render_im_used` | `data:` `message:` `meta:` `pagination:` |
| 2xx no payload | `render_no_content` `render_reset_content` | `message:` `meta:` `pagination:` |
| 4xx / 5xx | `render_bad_request` `render_unauthorized` `render_forbidden` `render_not_found` `render_conflict` `render_unprocessable` `render_too_many_requests` `render_server_error` `render_service_unavailable` … (40 in total) | `message:` `errors:` `meta:` |

**204 and 205 have no body.** HTTP forbids a body on `204 No Content` and `205 Reset Content`, and Rails drops it, so `render_no_content` and `render_reset_content` reach the client with an empty body. Use `render_ok` when the client needs the message, or set `config.always_ok = true` (every response becomes HTTP 200, body included).

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
  config.auto_include            = true    # see "Using both gems"
end
```

**`always_ok`** — many GraphQL clients, Apollo among them, treat non-2xx responses as network failures. Set `config.always_ok = true` to send every response with HTTP 200 and let the `errors` array carry the failure. The default (`false`) keeps each helper's own status (404 for `render_not_found`, …).

## Using both gems

`respondo` and `respondo-graphql` define the same helper names (`render_ok`, …), so they must not both be auto-included into every controller — whichever loaded last would silently win. When the Railtie sees that `respondo` is loaded, it **skips auto-include**. Keep `respondo` for your REST controllers and include the GraphQL helpers where you want them:

```ruby
class GraphqlController < ApplicationController
  include RespondoGraphql::ControllerHelpers   # wins over respondo's helpers in this controller
end
```

You can also turn auto-include off yourself with `config.auto_include = false`.

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
