# frozen_string_literal: true

require "test_helper"

class CF::MCP::ToolsTest < Minitest::Test
  def test_all_lists_every_tool
    expected = [
      CF::MCP::Tools::SearchTool,
      CF::MCP::Tools::ListCategory,
      CF::MCP::Tools::GetDetails,
      CF::MCP::Tools::FindRelated,
      CF::MCP::Tools::ParameterSearch,
      CF::MCP::Tools::MemberSearch,
      CF::MCP::Tools::ListTopics,
      CF::MCP::Tools::GetTopic
    ]

    assert_equal expected, CF::MCP::Tools.all
  end
end
