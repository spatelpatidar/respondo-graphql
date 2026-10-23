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
    expect(config).not_to respond_to(:auto_include)
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

  describe "RespondoGraphql.json_gem_loaded?" do
    it "is false when the respondo (JSON) gem is not loaded" do
      hide_const("Respondo") if defined?(::Respondo)
      expect(RespondoGraphql.json_gem_loaded?).to eq(false)
    end

    it "is true when Respondo::ControllerHelpers is defined" do
      stub_const("Respondo::ControllerHelpers", Module.new)
      expect(RespondoGraphql.json_gem_loaded?).to eq(true)
    end
  end

  it "accepts a custom serializer callable" do
    serializer = ->(obj) { { custom: obj } }
    RespondoGraphql.configure { |c| c.serializer = serializer }
    expect(RespondoGraphql.config.serializer).to eq(serializer)
  end
end
