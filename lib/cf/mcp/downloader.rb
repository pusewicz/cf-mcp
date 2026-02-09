# frozen_string_literal: true

require "net/http"
require "uri"
require "fileutils"
require "zip"

module CF
  module MCP
    class Downloader
      CUTE_FRAMEWORK_ZIP_URL = "https://github.com/RandyGaul/cute_framework/archive/refs/heads/master.zip"
      GITHUB_ARCHIVE_URL_TEMPLATE = "https://github.com/RandyGaul/cute_framework/archive/%{ref}.zip"
      SHA_METADATA_FILE = ".cf-mcp-sha"
      DEFAULT_DOWNLOAD_DIR = File.join(Dir.tmpdir, "cf-mcp-#{VERSION}")

      class DownloadError < StandardError; end

      def initialize(download_dir: DEFAULT_DOWNLOAD_DIR)
        @download_dir = download_dir
      end

      def download_and_extract
        FileUtils.mkdir_p(@download_dir)

        zip_path = File.join(@download_dir, "cute_framework.zip")
        base_path = File.join(@download_dir, "cute_framework")
        include_path = File.join(base_path, "include")
        sha_file = File.join(@download_dir, SHA_METADATA_FILE)

        # Check if cache is valid
        stored_sha = read_sha_metadata(sha_file)
        latest_sha = fetch_latest_sha

        if stored_sha && latest_sha && stored_sha == latest_sha
          if File.directory?(include_path) && !Dir.empty?(include_path)
            warn "Using cached Cute Framework headers (SHA: #{stored_sha})"
            return include_path
          end
        end

        # Determine download URL
        if latest_sha
          download_url = format(GITHUB_ARCHIVE_URL_TEMPLATE, ref: latest_sha)
          warn "Downloading Cute Framework at SHA #{latest_sha}..."
        else
          download_url = CUTE_FRAMEWORK_ZIP_URL
          warn "Downloading Cute Framework from master branch..."
        end

        download_zip(zip_path, download_url)
        extract_directories(zip_path, base_path)

        # Store metadata for future cache checks
        write_sha_metadata(sha_file, latest_sha) if latest_sha

        include_path
      end

      private

      def download_zip(destination, url = CUTE_FRAMEWORK_ZIP_URL)
        uri = URI.parse(url)

        Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
          request = Net::HTTP::Get.new(uri)
          response = http.request(request)

          # Handle redirects (GitHub redirects to codeload.github.com)
          if response.is_a?(Net::HTTPRedirection)
            redirect_uri = URI.parse(response["location"])
            Net::HTTP.start(redirect_uri.host, redirect_uri.port, use_ssl: true) do |redirect_http|
              redirect_request = Net::HTTP::Get.new(redirect_uri)
              response = redirect_http.request(redirect_request)
            end
          end

          unless response.is_a?(Net::HTTPSuccess)
            raise DownloadError, "Failed to download Cute Framework: #{response.code} #{response.message}"
          end

          File.binwrite(destination, response.body)
        end
      end

      def extract_directories(zip_path, base_path)
        FileUtils.rm_rf(base_path)
        FileUtils.mkdir_p(base_path)

        Zip::File.open(zip_path) do |zip_file|
          # The zip contains a top-level directory like "cute_framework-master/"
          # We want to extract "include/" and "docs/topics/" subdirectories
          top_level_prefix = nil

          zip_file.each do |entry|
            # Find the top-level directory prefix (e.g., "cute_framework-master/" or "cute_framework-abc1234/")
            if top_level_prefix.nil? && entry.name.match?(%r{^cute_framework-[^/]+/include/})
              top_level_prefix = entry.name.match(%r{^(cute_framework-[^/]+/)})[1]
              break
            end
          end

          raise DownloadError, "Could not find include directory in zip" unless top_level_prefix

          # Directories to extract
          extract_prefixes = [
            "#{top_level_prefix}include/",
            "#{top_level_prefix}docs/topics/"
          ]

          zip_file.each do |entry|
            extract_prefix = extract_prefixes.find { |p| entry.name.start_with?(p) }
            next unless extract_prefix

            # Calculate the relative path from the top-level directory
            relative_path = entry.name.sub(top_level_prefix, "")
            next if relative_path.empty?

            target_path = File.join(base_path, relative_path)

            if entry.directory?
              FileUtils.mkdir_p(target_path)
            else
              FileUtils.mkdir_p(File.dirname(target_path))
              entry.extract(relative_path, destination_directory: base_path)
            end
          end
        end
      end

      def fetch_latest_sha
        client = GitHubClient.new
        client.latest_commit_sha
      rescue => e
        warn "GitHub API error: #{e.message}"
        nil
      end

      def read_sha_metadata(file)
        return nil unless File.exist?(file)
        File.read(file).strip
      rescue => e
        warn "Error reading SHA metadata: #{e.message}"
        nil
      end

      def write_sha_metadata(file, sha)
        return unless sha
        File.write(file, sha)
      rescue => e
        warn "Error writing SHA metadata: #{e.message}"
      end
    end
  end
end
