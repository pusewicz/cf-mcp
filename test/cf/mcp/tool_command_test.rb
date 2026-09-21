# frozen_string_literal: true

require_relative "tools/tools_test_helper"

class CF::MCP::ToolCommandTest < Minitest::Test
  include ToolsTestHelper

  def setup
    setup_test_index
  end

  def test_required_arguments_are_positional
    status, out, = run_command("sprite")

    assert_equal 0, status
    assert_includes out, "cf_make_sprite"
  end

  def test_optional_arguments_are_flags
    _, out, = run_command("sprite", "--type", "struct")

    assert_includes out, "CF_Sprite"
    refute_includes out, "cf_make_sprite"
  end

  def test_flags_may_precede_positional_arguments
    _, out, = run_command("--type", "struct", "sprite")

    assert_includes out, "CF_Sprite"
    refute_includes out, "cf_make_sprite"
  end

  def test_integer_flags_are_coerced
    _, out, = run_command("sprite", "--limit", "1")

    assert_includes out, "limit reached"
  end

  def test_enum_flags_reject_unknown_values
    error = assert_raises(OptionParser::InvalidArgument) { run_command("sprite", "--type", "bogus") }

    assert_includes error.message, "--type bogus"
  end

  def test_a_missing_positional_argument_is_an_error
    error = assert_raises(OptionParser::MissingArgument) { run_command }

    assert_includes error.message, "QUERY"
  end

  def test_extra_positional_arguments_are_an_error
    error = assert_raises(OptionParser::NeedlessArgument) { run_command("sprite", "extra") }

    assert_includes error.message, "extra"
  end

  def test_help_is_built_from_the_tool_schema
    status, out, = run_command("--help")

    assert_equal 0, status
    assert_includes out, "Usage: cf-mcp search QUERY [options]"
    assert_includes out, CF::MCP::Tools::SearchTool.description
    assert_includes out, "Search query (searches in name, description, and remarks)"
    assert_includes out, "--type TYPE"
    assert_includes out, "function|struct|enum|topic"
  end

  def test_a_tool_error_is_reported_on_stderr_with_status_1
    failing = Class.new(::MCP::Tool) do
      tool_name "failing"
      description "Always fails"
      input_schema(type: "object", properties: {})

      def self.call(server_context: {})
        ::MCP::Tool::Response.new([{type: "text", text: "Error: boom"}], error: true)
      end
    end

    status, out, err = run_command(tool: failing)

    assert_equal 1, status
    assert_empty out
    assert_includes err, "Error: boom"
  end

  private

  def run_command(*args, tool: CF::MCP::Tools::SearchTool)
    status = nil
    out, err = capture_io { status = CF::MCP::ToolCommand.new(tool).run(args) }
    [status, out, err]
  end
end
