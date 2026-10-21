# frozen_string_literal: true

require "spec_helper"

RSpec.describe RespondoGraphql::ResponseBuilder do
  def build(**opts)
    described_class.new(**opts).build
  end

  describe "successful responses" do
    it "returns data and extensions, and no errors key" do
      result = build(success: true, data: { id: 1 })
      expect(result.keys).to eq(%i[data extensions])
    end

    it "passes Hash data through untouched" do
      expect(build(success: true, data: { user: { id: 1 } })[:data]).to eq(user: { id: 1 })
    end

    it "keeps nil data as nil" do
      expect(build(success: true, data: nil)[:data]).to be_nil
    end

    it "wraps Array data under the default :result key (GraphQL data must be a map)" do
      expect(build(success: true, data: [1, 2])[:data]).to eq(result: [1, 2])
    end

    it "wraps scalar data under the default :result key" do
      expect(build(success: true, data: "ok")[:data]).to eq(result: "ok")
    end

    it "honours config.data_key (String or Symbol)" do
      RespondoGraphql.configure { |c| c.data_key = "items" }
      expect(build(success: true, data: [1])[:data]).to eq(items: [1])
    end

    it "puts the message first in extensions, then the meta block" do
      ext = build(success: true, message: "Fetched")[:extensions]
      expect(ext.keys.first(2)).to eq(%i[message timestamp])
      expect(ext[:message]).to eq("Fetched")
    end

    it "falls back to the default success message" do
      expect(build(success: true)[:extensions][:message]).to eq("Success")
    end

    it "includes pagination and caller meta in extensions" do
      ext = build(success: true, meta: { code: 200, status: :ok }, pagination: { current_page: 1 })[:extensions]
      expect(ext[:pagination]).to eq(current_page: 1)
      expect(ext[:code]).to eq(200)
    end

    it "serializes data through the configured custom serializer" do
      RespondoGraphql.configure { |c| c.serializer = ->(obj) { { wrapped: obj } } }
      expect(build(success: true, data: 5)[:data]).to eq(wrapped: 5)
    end
  end

  describe "error responses" do
    it "orders keys errors, data, extensions and sets data to nil" do
      result = build(success: false, message: "Nope")
      expect(result.keys).to eq(%i[errors data extensions])
      expect(result[:data]).to be_nil
    end

    it "starts with a summary entry carrying the message" do
      result = build(success: false, message: "Not found", meta: { code: 404, status: :not_found })
      expect(result[:errors]).to eq(
        [{ message: "Not found", extensions: { code: "NOT_FOUND", http: { status: 404 } } }]
      )
    end

    it "falls back to the default error message" do
      expect(build(success: false)[:errors][0][:message]).to eq("An error occurred")
    end

    it "mirrors the message in extensions" do
      expect(build(success: false, message: "Nope")[:extensions][:message]).to eq("Nope")
    end

    it "adds one entry per field message, tagged with the field" do
      result = build(
        success: false, message: "Validation failed",
        meta: { code: 422, status: :unprocessable_content },
        errors: { email: ["is invalid", "is taken"], name: ["can't be blank"] }
      )

      expect(result[:errors].size).to eq(4)
      expect(result[:errors][1]).to eq(
        message: "email is invalid",
        extensions: { code: "UNPROCESSABLE_CONTENT", http: { status: 422 }, field: "email" }
      )
      expect(result[:errors].map { |e| e[:message] }).to include("email is taken", "name can't be blank")
    end

    it "does not prefix :base errors with the field name" do
      result = build(success: false, errors: { base: ["Account locked"] })
      expect(result[:errors][1][:message]).to eq("Account locked")
      expect(result[:errors][1][:extensions][:field]).to eq("base")
    end

    it "accepts a single String message per field" do
      result = build(success: false, errors: { token: "has expired" })
      expect(result[:errors][1][:message]).to eq("token has expired")
    end

    it "ignores errors that are not a Hash" do
      expect(build(success: false, errors: nil)[:errors].size).to eq(1)
    end

    it "uses a String code as the machine-readable code as-is" do
      result = build(success: false, meta: { code: "AUTH_EXPIRED", status: :unauthorized })
      expect(result[:errors][0][:extensions]).to eq(code: "AUTH_EXPIRED")
    end

    it "ignores an empty String code and uses the status instead" do
      result = build(success: false, meta: { code: "", status: :forbidden })
      expect(result[:errors][0][:extensions]).to eq(code: "FORBIDDEN")
    end

    it "accepts a String status" do
      result = build(success: false, meta: { status: "gone" })
      expect(result[:errors][0][:extensions][:code]).to eq("GONE")
    end

    it "reports the numeric status when only status is an Integer" do
      result = build(success: false, meta: { status: 404 })
      expect(result[:errors][0][:extensions]).to eq(code: "ERROR", http: { status: 404 })
    end

    it "falls back to ERROR with no http status when nothing is known" do
      expect(build(success: false)[:errors][0][:extensions]).to eq(code: "ERROR")
    end
  end

  describe "key camelizing" do
    before { RespondoGraphql.configure { |c| c.camelize_keys = true } }

    it "camelizes data and extensions keys" do
      result = build(success: true, data: { first_name: "A" }, pagination: { total_pages: 2 })
      expect(result[:data]).to eq(firstName: "A")
      expect(result[:extensions][:pagination]).to eq(totalPages: 2)
    end

    it "leaves error codes and field names (values) untouched" do
      result = build(success: false, meta: { status: :not_found }, errors: { first_name: ["is blank"] })
      expect(result[:errors][1][:extensions][:code]).to eq("NOT_FOUND")
      expect(result[:errors][1][:extensions][:field]).to eq("first_name")
    end
  end

  describe "request id" do
    it "includes the request id in extensions when enabled" do
      RespondoGraphql.configure { |c| c.include_request_id = true }
      request = Struct.new(:request_id).new("abc-123")
      expect(build(success: true, request: request)[:extensions][:request_id]).to eq("abc-123")
    end
  end
end
