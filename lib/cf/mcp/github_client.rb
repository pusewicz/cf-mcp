# frozen_string_literal: true

require "net/http"
require "json"
require "uri"

module CF
  module MCP
    class GitHubClient
      GITHUB_API_BASE = "https://api.github.com"
      REPO_OWNER = "RandyGaul"
      REPO_NAME = "cute_framework"
      DEFAULT_BRANCH = "master"

      def initialize(token: ENV["GITHUB_TOKEN"])
        @token = token
      end

      # Returns latest commit SHA (short 7-char format) or nil on failure
      def latest_commit_sha
        uri = URI.parse("#{GITHUB_API_BASE}/repos/#{REPO_OWNER}/#{REPO_NAME}/commits/#{DEFAULT_BRANCH}")

        request = Net::HTTP::Get.new(uri)
        request["Accept"] = "application/vnd.github+json"
        request["Authorization"] = "Bearer #{@token}" if @token
        request["User-Agent"] = "cf-mcp/#{CF::MCP::VERSION}"

        response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
          http.request(request)
        end

        return nil unless response.is_a?(Net::HTTPSuccess)

        data = JSON.parse(response.body)
        data.dig("sha")&.slice(0, 7) # Return short SHA
      rescue
        # Return nil on any error (network, JSON parse, etc.)
        nil
      end
    end
  end
end
