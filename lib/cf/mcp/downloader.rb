# frozen_string_literal: true

require "net/http"
require "uri"
require "fileutils"
require "zip"

module CF
  module MCP
    class Downloader
      CUTE_FRAMEWORK_ZIP_URL = "https://github.com/RandyGaul/cute_framework/archive/refs/heads/master.zip"
      DEFAULT_DOWNLOAD_DIR = File.join(Dir.tmpdir, "cf-mcp")

      class DownloadError < StandardError; end

      def initialize(download_dir: DEFAULT_DOWNLOAD_DIR)
        @download_dir = download_dir
      end

      def download_and_extract
        FileUtils.mkdir_p(@download_dir)

        zip_path = File.join(@download_dir, "cute_framework.zip")
        include_path = File.join(@download_dir, "include")

        # Return existing path if already downloaded
        if File.directory?(include_path) && !Dir.empty?(include_path)
          return include_path
        end

        download_zip(zip_path)
        extract_include_directory(zip_path, include_path)

        include_path
      end

      private

      def download_zip(destination)
        uri = URI.parse(CUTE_FRAMEWORK_ZIP_URL)

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

      def extract_include_directory(zip_path, destination)
        FileUtils.rm_rf(destination)
        FileUtils.mkdir_p(destination)

        Zip::File.open(zip_path) do |zip_file|
          # The zip contains a top-level directory like "cute_framework-master/"
          # We want to extract only the "include/" subdirectory
          include_prefix = nil

          zip_file.each do |entry|
            # Find the include directory prefix (e.g., "cute_framework-master/include/")
            if include_prefix.nil? && entry.name.match?(%r{^[^/]+/include/})
              include_prefix = entry.name.match(%r{^([^/]+/include/)})[1]
            end
          end

          raise DownloadError, "Could not find include directory in zip" unless include_prefix

          zip_file.each do |entry|
            next unless entry.name.start_with?(include_prefix)

            # Calculate the relative path within include/
            relative_path = entry.name.sub(include_prefix, "")
            next if relative_path.empty?

            target_path = File.join(destination, relative_path)

            if entry.directory?
              FileUtils.mkdir_p(target_path)
            else
              FileUtils.mkdir_p(File.dirname(target_path))
              entry.extract(target_path)
            end
          end
        end
      end
    end
  end
end
