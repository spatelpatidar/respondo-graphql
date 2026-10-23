# frozen_string_literal: true

require "spec_helper"

# Fake Rails-like controller so ControllerHelpers can be tested without Rails
class FakeController
  include RespondoGraphql::ControllerHelpers

  attr_reader :rendered_json, :rendered_status

  def render(json:, status:)
    @rendered_json   = json
    @rendered_status = status
  end

  # Simulate ActionController's #try
  def try(method_name)
    respond_to?(method_name) ? send(method_name) : nil
  end
end

RSpec.describe RespondoGraphql::ControllerHelpers do
  subject(:controller) { FakeController.new }

  def body   = controller.rendered_json
  def status = controller.rendered_status

  let(:pagination_hash) do
    { current_page: 1, per_page: 10, total_pages: 3, total_count: 25, next_page: 2, prev_page: nil }
  end

  # =========================================================================
  # Success helpers
  # =========================================================================

  describe "success helpers" do
    described_class::SUCCESS_HELPERS.each do |name, spec|
      describe "#render_graphql_#{name}" do
        it "renders data + extensions (no errors) with code #{spec[:code]} and status #{spec[:status]}" do
          controller.public_send(:"render_graphql_#{name}")
          expect(body.keys).to eq(%i[data extensions])
          expect(body[:extensions][:code]).to   eq(spec[:code])
          expect(body[:extensions][:status]).to eq(spec[:status])
          expect(status).to                     eq(spec[:code])
        end

        it "uses the right default message" do
          controller.public_send(:"render_graphql_#{name}")
          expected = spec[:message] || "Success"
          expect(body[:extensions][:message]).to eq(expected)
        end

        it "accepts a custom message and extra meta" do
          controller.public_send(:"render_graphql_#{name}", message: "Custom", meta: { trace: "abc" })
          expect(body[:extensions][:message]).to eq("Custom")
          expect(body[:extensions][:trace]).to   eq("abc")
        end

        it "accepts a pagination hash" do
          controller.public_send(:"render_graphql_#{name}", pagination: pagination_hash)
          expect(body[:extensions][:pagination]).to eq(pagination_hash)
        end

        if spec[:data]
          it "accepts data:" do
            controller.public_send(:"render_graphql_#{name}", data: { id: 1 })
            expect(body[:data]).to eq(id: 1)
          end
        else
          it "does not accept data: and always renders data as nil" do
            expect { controller.public_send(:"render_graphql_#{name}", data: { id: 1 }) }.to raise_error(ArgumentError)
            controller.public_send(:"render_graphql_#{name}")
            expect(body[:data]).to be_nil
          end
        end
      end
    end

    it "wraps Array data under the default :result key" do
      controller.render_graphql_ok(data: [{ id: 1 }, { id: 2 }])
      expect(body[:data]).to eq(result: [{ id: 1 }, { id: 2 }])
    end

    it "passes Hash data through" do
      controller.render_graphql_ok(data: { user: { id: 1 } })
      expect(body[:data]).to eq(user: { id: 1 })
    end
  end

  # =========================================================================
  # Error helpers
  # =========================================================================

  describe "error helpers" do
    described_class::ERROR_HELPERS.each do |name, spec|
      describe "#render_graphql_#{name}" do
        it "renders errors + null data with code #{spec[:code]} and status #{spec[:status]}" do
          controller.public_send(:"render_graphql_#{name}")
          expect(body.keys).to eq(%i[errors data extensions])
          expect(body[:data]).to be_nil
          expect(status).to eq(spec[:code])
        end

        it "puts the default message and codes in the summary error" do
          controller.public_send(:"render_graphql_#{name}")
          summary = body[:errors].first
          expect(summary[:message]).to                   eq(spec[:message])
          expect(summary[:extensions][:code]).to         eq(spec[:status].to_s.upcase)
          expect(summary[:extensions][:http][:status]).to eq(spec[:code])
        end

        it "accepts a custom message, field errors, and meta" do
          controller.public_send(:"render_graphql_#{name}", message: "Custom", errors: { name: ["is blank"] }, meta: { trace: "abc" })
          expect(body[:errors].map { |e| e[:message] }).to eq(["Custom", "name is blank"])
          expect(body[:extensions][:trace]).to eq("abc")
        end
      end
    end

    it "turns field errors into one entry per message, tagged with the field" do
      controller.render_graphql_unprocessable(message: "Validation failed", errors: { email: ["is invalid", "is taken"] })
      expect(body[:errors].size).to eq(3)
      expect(body[:errors][1][:extensions][:field]).to eq("email")
    end
  end

  # =========================================================================
  # HTTP status sent to Rails
  # =========================================================================

  describe "HTTP status" do
    it "sends the numeric code, immune to Rack renaming its status symbols" do
      controller.render_graphql_payload_too_large
      expect(status).to eq(413)
      expect(body[:extensions][:status]).to eq(:payload_too_large)
    end

    it "sends the numeric code for success helpers too" do
      controller.render_graphql_created
      expect(status).to eq(201)
    end

    it "falls back to the status symbol when a direct render_graphql_error call has no numeric code" do
      controller.send(:render_graphql_error, message: "x", code: "AUTH_EXPIRED", status: :unauthorized)
      expect(status).to eq(:unauthorized)
    end

    it "falls back to the default :unprocessable_content when nothing is given" do
      controller.send(:render_graphql_error, message: "x")
      expect(status).to eq(:unprocessable_content)
    end
  end

  # =========================================================================
  # Configuration effects
  # =========================================================================

  describe "config.always_ok" do
    before { RespondoGraphql.configure { |c| c.always_ok = true } }

    it "sends errors with HTTP 200 and keeps the error details" do
      controller.render_graphql_forbidden
      expect(status).to eq(:ok)
      expect(body[:errors][0][:extensions][:code]).to eq("FORBIDDEN")
    end

    it "sends successes with HTTP 200" do
      controller.render_graphql_created(data: { id: 1 })
      expect(status).to eq(:ok)
      expect(body[:extensions][:code]).to eq(201)
    end
  end

  describe "config.camelize_keys" do
    it "camelizes data and extensions keys" do
      RespondoGraphql.configure { |c| c.camelize_keys = true }
      controller.render_graphql_ok(data: { first_name: "A" }, pagination: { total_pages: 2 })
      expect(body[:data]).to eq(firstName: "A")
      expect(body[:extensions][:pagination]).to eq(totalPages: 2)
    end
  end

  describe "config.default_meta" do
    it "is merged into extensions" do
      RespondoGraphql.configure { |c| c.default_meta = { api_version: "v1" } }
      controller.render_graphql_ok
      expect(body[:extensions][:api_version]).to eq("v1")
    end
  end

  describe "request id" do
    it "is added to extensions when enabled and the controller has a request" do
      RespondoGraphql.configure { |c| c.include_request_id = true }
      request = Struct.new(:request_id).new("req-1")
      controller.define_singleton_method(:request) { request }
      controller.render_graphql_ok
      expect(body[:extensions][:request_id]).to eq("req-1")
    end
  end

  # =========================================================================
  # Public surface
  # =========================================================================

  describe "public surface" do
    it "keeps render_graphql_success and render_graphql_error private" do
      expect(controller.respond_to?(:render_graphql_success)).to be false
      expect(controller.respond_to?(:render_graphql_error)).to   be false
    end

    it "defines every helper as a public method" do
      names = described_class::SUCCESS_HELPERS.keys + described_class::ERROR_HELPERS.keys
      names.each { |name| expect(controller.respond_to?(:"render_graphql_#{name}")).to be(true), "missing render_graphql_#{name}" }
    end

    it "defines no unprefixed render_* helper, so nothing can shadow respondo's render_ok" do
      names = described_class.instance_methods(false) + described_class.private_instance_methods(false)
      unprefixed = names.map(&:to_s).grep(/\Arender_/).reject { |name| name.start_with?("render_graphql_") }
      expect(unprefixed).to eq([])
    end

    it "prefixes its private helpers too (render_graphql_success, extract_graphql_errors, ...)" do
      private_names = described_class.private_instance_methods(false).map(&:to_s)
      expect(private_names).to include("render_graphql_success", "render_graphql_error", "extract_graphql_errors")
      expect(private_names - %w[render_graphql_success render_graphql_error extract_graphql_errors respondo_graphql_http_status]).to eq([])
    end

    it "does not define 1xx or 3xx helpers (meaningless in GraphQL)" do
      %i[render_graphql_continue render_graphql_processing render_graphql_moved_permanently render_graphql_found render_graphql_not_modified].each do |name|
        expect(controller.respond_to?(name)).to be false
      end
    end
  end

  # =========================================================================
  # extract_graphql_errors branches
  # =========================================================================

  describe "extract_graphql_errors" do
    it "returns nil for nil" do
      expect(controller.send(:extract_graphql_errors, nil)).to be_nil
    end

    it "converts ActiveModel::Errors via to_hash" do
      stub_const("ActiveModel::Errors", Class.new)
      errors = ActiveModel::Errors.new
      allow(errors).to receive(:to_hash).and_return(name: ["can't be blank"])
      expect(controller.send(:extract_graphql_errors, errors)).to eq(name: ["can't be blank"])
    end

    it "passes a Hash through" do
      expect(controller.send(:extract_graphql_errors, { a: ["b"] })).to eq(a: ["b"])
    end

    it "wraps an Array under :base" do
      expect(controller.send(:extract_graphql_errors, %w[too short])).to eq(base: %w[too short])
    end

    it "wraps a String in an array under :base" do
      expect(controller.send(:extract_graphql_errors, "Invalid input")).to eq(base: ["Invalid input"])
    end

    it "returns nil for unrecognized types" do
      expect(controller.send(:extract_graphql_errors, 42)).to be_nil
    end
  end

  # =========================================================================
  # Living next to the respondo (JSON) gem
  # =========================================================================

  describe "in a controller that also has the respondo (JSON) helpers" do
    # Stand-in for Respondo::ControllerHelpers: same public AND private names the
    # real gem uses, each returning a marker instead of rendering.
    let(:json_module) do
      Module.new do
        def render_ok(**)        = "json:ok"
        def render_not_found(**) = "json:not_found"

        private

        def render_success(**) = "json:success"
        def render_error(**)   = "json:error"
        def extract_errors(_)  = "json:extract"
      end
    end

    def build_controller(*modules)
      Class.new do
        modules.each { |mod| include mod }
        attr_reader :rendered_json

        def render(json:, status:) = @rendered_json = json
        def try(*) = nil
      end.new
    end

    [%w[JSON-first], %w[GraphQL-first]].each do |(order)|
      it "keeps render_ok JSON and render_graphql_ok GraphQL when the modules are included #{order}" do
        modules = order == "JSON-first" ? [json_module, described_class] : [described_class, json_module]
        controller = build_controller(*modules)

        expect(controller.render_ok).to eq("json:ok")
        expect(controller.render_not_found).to eq("json:not_found")

        controller.render_graphql_ok(data: { id: 1 })
        expect(controller.rendered_json.keys).to eq(%i[data extensions])
        controller.render_graphql_not_found
        expect(controller.rendered_json.keys).to eq(%i[errors data extensions])
      end
    end

    it "does not let the JSON gem's private render_success / render_error take over GraphQL rendering" do
      controller = build_controller(json_module, described_class)
      controller.render_graphql_created(data: { id: 1 })
      expect(controller.rendered_json[:extensions][:code]).to eq(201)
    end

    it "works when the module is included in a subclass of a controller that has the JSON helpers" do
      json   = json_module                      # a `let` is not visible inside Class.new { }
      parent = Class.new { include json }
      child  = Class.new(parent) do
        include RespondoGraphql::ControllerHelpers
        attr_reader :rendered_json

        def render(json:, status:) = @rendered_json = json
        def try(*) = nil
      end.new

      expect(child.render_ok).to eq("json:ok")
      child.render_graphql_ok(data: { id: 1 })
      expect(child.rendered_json.keys).to eq(%i[data extensions])
    end
  end
end

RSpec.describe RespondoGraphql::ShortHelpers do
  let(:short_class) do
    Class.new do
      include RespondoGraphql::ShortHelpers
      attr_reader :rendered_json, :rendered_status
      def render(json:, status:)
        @rendered_json   = json
        @rendered_status = status
      end

      def try(_)
        nil
      end
    end
  end

  names = RespondoGraphql::ControllerHelpers::SUCCESS_HELPERS.keys + RespondoGraphql::ControllerHelpers::ERROR_HELPERS.keys

  it "defines exactly the 50 short names" do
    expect(described_class.instance_methods(false).map(&:to_s)).to match_array(names.map { |n| "render_#{n}" })
  end

  it "is not included by default" do
    expect(FakeController.new).not_to respond_to(:render_ok)
  end

  it "render_ok behaves like render_graphql_ok" do
    c = short_class.new
    c.render_ok(data: { a: 1 }, message: "hi")
    expect(c.rendered_status).to eq(200)
    expect(c.rendered_json[:data]).to eq(a: 1)
    expect(c.rendered_json).not_to have_key(:errors)
  end

  it "render_not_found behaves like render_graphql_not_found" do
    c = short_class.new
    c.render_not_found(message: "nope", errors: { id: ["bad"] })
    expect(c.rendered_status).to eq(404)
    expect(c.rendered_json[:data]).to be_nil
    expect(c.rendered_json[:errors]).to be_a(Array)
  end

  it "also gives the controller the prefixed helpers" do
    expect(short_class.new).to respond_to(:render_graphql_ok)
  end

  it "warns when the respondo JSON helpers are available in the same controller" do
    json = Module.new
    stub_const("Respondo::ControllerHelpers", json)
    expect { Class.new { include Respondo::ControllerHelpers; include RespondoGraphql::ShortHelpers } }
      .to output(/render_ok & co\. now answer in GraphQL/).to_stderr
  end

  it "stays silent when only this gem is present" do
    expect { Class.new { include RespondoGraphql::ShortHelpers } }.not_to output.to_stderr
  end
end
