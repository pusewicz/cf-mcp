# frozen_string_literal: true

require "simplecov"

SimpleCov.start do
  add_filter "/test/"

  add_group "Models", "lib/cf/mcp/models"
  add_group "Tools", "lib/cf/mcp/tools"
  add_group "Core", "lib/cf/mcp"
end

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "cf/mcp"

require "minitest/autorun"
