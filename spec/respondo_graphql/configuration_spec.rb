# frozen_string_literal: true

require "spec_helper"

RSpec.describe RespondoGraphql::Configuration do
  it "has sensible defaults" do
    config = described_class.new
    expect(config.default_success_message).to eq("Success")
    expect(config.default_error_message).to   eq("An error occurred")
    expect(config.include_request_id).to      eq(false)
    expect(config.camelize_keys).to           eq(false)
    expect(config.serializer).to              be_nil
    expect(config.default_meta).to            eq({})
    expect(config.data_key).to                eq(:result)
    expect(config.always_ok).to               eq(false)
    expect(config.auto_include).to            eq(true)
  end

  it "is mutable" do
    RespondoGraphql.configure do |c|
      c.default_success_message = "OK"
      c.camelize_keys           = true
      c.always_ok               = true
    end

    expect(RespondoGraphql.config.default_success_message).to eq("OK")
    expect(RespondoGraphql.config.camelize_keys).to           eq(true)
    expect(RespondoGraphql.config.always_ok).to               eq(true)
  end

  it "resets cleanly" do
    RespondoGraphql.configure { |c| c.default_success_message = "Changed" }
    RespondoGraphql.reset!
    expect(RespondoGraphql.config.default_success_message).to eq("Success")
  end

  it "accepts a custom serializer callable" do
    serializer = ->(obj) { { custom: obj } }
    RespondoGraphql.configure { |c| c.serializer = serializer }
    expect(RespondoGraphql.config.serializer).to eq(serializer)
  end

  describe "RespondoGraphql.auto_include?" do
    it "is true by default" do
      expect(RespondoGraphql.auto_include?).to eq(true)
    end

    it "is false when config.auto_include is false" do
      RespondoGraphql.configure { |c| c.auto_include = false }
      expect(RespondoGraphql.auto_include?).to eq(false)
    end

    it "is false when the respondo (JSON) gem is loaded, to avoid helper-name clashes" do
      stub_const("Respondo::ControllerHelpers", Module.new)
      expect(RespondoGraphql.auto_include?).to eq(false)
    end
  end
end
