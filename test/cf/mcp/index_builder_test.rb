# frozen_string_literal: true

require "test_helper"
require "tmpdir"
require "fileutils"
require "open3"

class CF::MCP::IndexBuilderTest < Minitest::Test
  def test_revision_is_nil_when_root_is_not_a_git_repo
    Dir.mktmpdir do |dir|
      builder = CF::MCP::IndexBuilder.new(root: dir)
      assert_nil builder.revision
    end
  end

  def test_revision_is_nil_when_root_path_does_not_exist
    builder = CF::MCP::IndexBuilder.new(root: "/nonexistent/cf-mcp-test-path")
    assert_nil builder.revision
  end

  def test_revision_detects_git_sha_for_local_checkout
    Dir.mktmpdir do |dir|
      init_git_repo(dir)

      builder = CF::MCP::IndexBuilder.new(root: dir)

      assert_match(/\A[0-9a-f]{7,40}\z/, builder.revision)
    end
  end

  def test_revision_detects_git_sha_from_subdirectory_of_checkout
    Dir.mktmpdir do |dir|
      init_git_repo(dir)
      include_dir = File.join(dir, "include")
      FileUtils.mkdir_p(include_dir)

      builder = CF::MCP::IndexBuilder.new(root: include_dir)

      assert_match(/\A[0-9a-f]{7,40}\z/, builder.revision)
    end
  end

  def test_revision_uses_downloader_sha_when_downloading
    fake_downloader = Object.new
    fake_downloader.define_singleton_method(:download_and_extract) { "/tmp/cf-mcp-fake/include" }
    fake_downloader.define_singleton_method(:sha) { "abc1234" }
    CF::MCP::Downloader.define_singleton_method(:new) { fake_downloader }

    builder = CF::MCP::IndexBuilder.new(download: true)
    assert_equal "abc1234", builder.revision
  ensure
    CF::MCP::Downloader.singleton_class.send(:remove_method, :new)
  end

  private

  def init_git_repo(dir)
    Open3.capture3("git", "-C", dir, "init", "-q")
    Open3.capture3("git", "-C", dir, "config", "user.email", "test@example.com")
    Open3.capture3("git", "-C", dir, "config", "user.name", "Test")
    File.write(File.join(dir, "README.md"), "test")
    Open3.capture3("git", "-C", dir, "add", "README.md")
    Open3.capture3("git", "-C", dir, "commit", "-q", "-m", "initial commit")
  end
end
