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
      describe "#render_#{name}" do
        it "renders data + extensions (no errors) with code #{spec[:code]} and status #{spec[:status]}" do
          controller.public_send(:"render_#{name}")
          expect(body.keys).to eq(%i[data extensions])
          expect(body[:extensions][:code]).to   eq(spec[:code])
          expect(body[:extensions][:status]).to eq(spec[:status])
          expect(status).to                     eq(spec[:code])
        end

        it "uses the right default message" do
          controller.public_send(:"render_#{name}")
          expected = spec[:message] || "Success"
          expect(body[:extensions][:message]).to eq(expected)
        end

        it "accepts a custom message and extra meta" do
          controller.public_send(:"render_#{name}", message: "Custom", meta: { trace: "abc" })
          expect(body[:extensions][:message]).to eq("Custom")
          expect(body[:extensions][:trace]).to   eq("abc")
        end

        it "accepts a pagination hash" do
          controller.public_send(:"render_#{name}", pagination: pagination_hash)
          expect(body[:extensions][:pagination]).to eq(pagination_hash)
        end

        if spec[:data]
          it "accepts data:" do
            controller.public_send(:"render_#{name}", data: { id: 1 })
            expect(body[:data]).to eq(id: 1)
          end
        else
          it "does not accept data: and always renders data as nil" do
            expect { controller.public_send(:"render_#{name}", data: { id: 1 }) }.to raise_error(ArgumentError)
            controller.public_send(:"render_#{name}")
            expect(body[:data]).to be_nil
          end
        end
      end
    end

    it "wraps Array data under the default :result key" do
      controller.render_ok(data: [{ id: 1 }, { id: 2 }])
      expect(body[:data]).to eq(result: [{ id: 1 }, { id: 2 }])
    end

    it "passes Hash data through" do
      controller.render_ok(data: { user: { id: 1 } })
      expect(body[:data]).to eq(user: { id: 1 })
    end
  end

  # =========================================================================
  # Error helpers
  # =========================================================================

  describe "error helpers" do
    described_class::ERROR_HELPERS.each do |name, spec|
      describe "#render_#{name}" do
        it "renders errors + null data with code #{spec[:code]} and status #{spec[:status]}" do
          controller.public_send(:"render_#{name}")
          expect(body.keys).to eq(%i[errors data extensions])
          expect(body[:data]).to be_nil
          expect(status).to eq(spec[:code])
        end

        it "puts the default message and codes in the summary error" do
          controller.public_send(:"render_#{name}")
          summary = body[:errors].first
          expect(summary[:message]).to                   eq(spec[:message])
          expect(summary[:extensions][:code]).to         eq(spec[:status].to_s.upcase)
          expect(summary[:extensions][:http][:status]).to eq(spec[:code])
        end

        it "accepts a custom message, field errors, and meta" do
          controller.public_send(:"render_#{name}", message: "Custom", errors: { name: ["is blank"] }, meta: { trace: "abc" })
          expect(body[:errors].map { |e| e[:message] }).to eq(["Custom", "name is blank"])
          expect(body[:extensions][:trace]).to eq("abc")
        end
      end
    end

    it "turns field errors into one entry per message, tagged with the field" do
      controller.render_unprocessable(message: "Validation failed", errors: { email: ["is invalid", "is taken"] })
      expect(body[:errors].size).to eq(3)
      expect(body[:errors][1][:extensions][:field]).to eq("email")
    end
  end

  # =========================================================================
  # HTTP status sent to Rails
  # =========================================================================

  describe "HTTP status" do
    it "sends the numeric code, immune to Rack renaming its status symbols" do
      controller.render_payload_too_large
      expect(status).to eq(413)
      expect(body[:extensions][:status]).to eq(:payload_too_large)
    end

    it "sends the numeric code for success helpers too" do
      controller.render_created
      expect(status).to eq(201)
    end

    it "falls back to the status symbol when a direct render_error call has no numeric code" do
      controller.send(:render_error, message: "x", code: "AUTH_EXPIRED", status: :unauthorized)
      expect(status).to eq(:unauthorized)
    end

    it "falls back to the default :unprocessable_content when nothing is given" do
      controller.send(:render_error, message: "x")
      expect(status).to eq(:unprocessable_content)
    end
  end

  # =========================================================================
  # Configuration effects
  # =========================================================================

  describe "config.always_ok" do
    before { RespondoGraphql.configure { |c| c.always_ok = true } }

    it "sends errors with HTTP 200 and keeps the error details" do
      controller.render_forbidden
      expect(status).to eq(:ok)
      expect(body[:errors][0][:extensions][:code]).to eq("FORBIDDEN")
    end

    it "sends successes with HTTP 200" do
      controller.render_created(data: { id: 1 })
      expect(status).to eq(:ok)
      expect(body[:extensions][:code]).to eq(201)
    end
  end

  describe "config.camelize_keys" do
    it "camelizes data and extensions keys" do
      RespondoGraphql.configure { |c| c.camelize_keys = true }
      controller.render_ok(data: { first_name: "A" }, pagination: { total_pages: 2 })
      expect(body[:data]).to eq(firstName: "A")
      expect(body[:extensions][:pagination]).to eq(totalPages: 2)
    end
  end

  describe "config.default_meta" do
    it "is merged into extensions" do
      RespondoGraphql.configure { |c| c.default_meta = { api_version: "v1" } }
      controller.render_ok
      expect(body[:extensions][:api_version]).to eq("v1")
    end
  end

  describe "request id" do
    it "is added to extensions when enabled and the controller has a request" do
      RespondoGraphql.configure { |c| c.include_request_id = true }
      request = Struct.new(:request_id).new("req-1")
      controller.define_singleton_method(:request) { request }
      controller.render_ok
      expect(body[:extensions][:request_id]).to eq("req-1")
    end
  end

  # =========================================================================
  # Public surface
  # =========================================================================

  describe "public surface" do
    it "keeps render_success and render_error private" do
      expect(controller.respond_to?(:render_success)).to be false
      expect(controller.respond_to?(:render_error)).to   be false
    end

    it "defines every helper as a public method" do
      names = described_class::SUCCESS_HELPERS.keys + described_class::ERROR_HELPERS.keys
      names.each { |name| expect(controller.respond_to?(:"render_#{name}")).to be(true), "missing render_#{name}" }
    end

    it "does not define 1xx or 3xx helpers (meaningless in GraphQL)" do
      %i[render_continue render_processing render_moved_permanently render_found render_not_modified].each do |name|
        expect(controller.respond_to?(name)).to be false
      end
    end

    it "uses the same helper names as the respondo JSON gem for the supported statuses" do
      %i[render_ok render_created render_no_content render_bad_request render_unauthorized
         render_forbidden render_not_found render_conflict render_unprocessable
         render_too_many_requests render_server_error render_service_unavailable].each do |name|
        expect(controller.respond_to?(name)).to be(true), "missing #{name}"
      end
    end
  end

  # =========================================================================
  # extract_errors branches
  # =========================================================================

  describe "extract_errors" do
    it "returns nil for nil" do
      expect(controller.send(:extract_errors, nil)).to be_nil
    end

    it "converts ActiveModel::Errors via to_hash" do
      stub_const("ActiveModel::Errors", Class.new)
      errors = ActiveModel::Errors.new
      allow(errors).to receive(:to_hash).and_return(name: ["can't be blank"])
      expect(controller.send(:extract_errors, errors)).to eq(name: ["can't be blank"])
    end

    it "passes a Hash through" do
      expect(controller.send(:extract_errors, { a: ["b"] })).to eq(a: ["b"])
    end

    it "wraps an Array under :base" do
      expect(controller.send(:extract_errors, %w[too short])).to eq(base: %w[too short])
    end

    it "wraps a String in an array under :base" do
      expect(controller.send(:extract_errors, "Invalid input")).to eq(base: ["Invalid input"])
    end

    it "returns nil for unrecognized types" do
      expect(controller.send(:extract_errors, 42)).to be_nil
    end
  end

  # =========================================================================
  # Coexisting with the respondo JSON gem
  # =========================================================================

  describe "next to a parent controller that already defines the same helpers" do
    it "lets a module included in the subclass win over the parent's helper" do
      json_module = Module.new { def render_ok(**) = "json" }
      parent = Class.new { include json_module }
      child  = Class.new(parent) do
        include RespondoGraphql::ControllerHelpers
        def render(**) = nil
        def try(*) = nil
      end

      expect(parent.new.render_ok).to eq("json")
      expect(child.new.render_ok).not_to eq("json")
    end
  end
end
