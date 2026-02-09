# frozen_string_literal: true

require "test_helper"

class CF::MCP::GitHubClientTest < Minitest::Test
  def test_initialization_with_token
    token = "ghp_test_token"
    client = CF::MCP::GitHubClient.new(token: token)

    refute_nil client
  end

  def test_initialization_without_token
    client = CF::MCP::GitHubClient.new

    refute_nil client
  end

  def test_constants_are_defined
    assert_equal "https://api.github.com", CF::MCP::GitHubClient::GITHUB_API_BASE
    assert_equal "RandyGaul", CF::MCP::GitHubClient::REPO_OWNER
    assert_equal "cute_framework", CF::MCP::GitHubClient::REPO_NAME
    assert_equal "master", CF::MCP::GitHubClient::DEFAULT_BRANCH
  end
end
