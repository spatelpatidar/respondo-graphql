# frozen_string_literal: true

require_relative "lib/respondo_graphql/version"

Gem::Specification.new do |spec|
  spec.name          = "respondo-graphql"
  spec.version       = RespondoGraphql::VERSION
  spec.authors       = ["shailendra Kumar"]
  spec.email         = ["shailendrapatidar00@gmail.com"]

  spec.summary       = "Consistent GraphQL-spec responses for Rails controllers — data, errors, extensions."
  spec.description   = <<~DESC
    RespondoGraphql standardizes the GraphQL-style responses your Rails
    controllers send: data, errors and extensions, built from one set of
    expressive helpers (render_ok, render_not_found, render_unprocessable, ...).
    Field errors become spec-compliant errors[] entries, message and meta live in
    extensions, and HTTP statuses can optionally be pinned to 200.
    Standalone gem — it does not depend on the respondo (JSON) gem.
  DESC
  spec.homepage      = "https://github.com/spatelpatidar/respondo-graphql"
  spec.license       = "MIT"
  spec.required_ruby_version = ">= 3.0.0"

  spec.metadata = {
    "homepage_uri"          => spec.homepage,
    "source_code_uri"       => spec.homepage,
    "changelog_uri"         => "#{spec.homepage}/blob/main/CHANGELOG.md",
    "bug_tracker_uri"       => "#{spec.homepage}/issues",
    "rubygems_mfa_required" => "true"
  }

  spec.files = Dir["lib/**/*.rb", "README.md", "LICENSE.txt", "CHANGELOG.md", "respondo-graphql.gemspec"]
  spec.require_paths = ["lib"]

  spec.add_development_dependency "railties",      "~> 8.1.3"
  spec.add_development_dependency "rspec",         "~> 3.12"
  spec.add_development_dependency "rake",          "~> 13.0"
  spec.add_development_dependency "activesupport", "~> 8.1.3"
  spec.add_development_dependency "simplecov",     "~> 0.22"
end
