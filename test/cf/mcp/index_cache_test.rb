# frozen_string_literal: true

require "test_helper"
require "tmpdir"
require "fileutils"
require "open3"

class CF::MCP::IndexCacheTest < Minitest::Test
  FIXTURE = File.expand_path("../../fixtures/sample_header.h", __dir__)

  def setup
    @tmp = Dir.mktmpdir("cf-mcp-index-cache-test")
    @root = build_checkout("cute_framework")
    @cache = CF::MCP::IndexCache.new(dir: File.join(@tmp, "cache"))
  end

  def teardown
    FileUtils.rm_rf(@tmp)
    CF::MCP::Index.instance.reset!
    CF::MCP::Index.instance.add(CF::MCP::Models::FunctionDoc.new(name: "test_func", category: "test", brief: "Test"))
  end

  def test_builds_and_stores_when_there_is_no_cache
    index = nil
    _, err = capture_io { index = @cache.index(source) { |source| builder_for(source) } }

    assert index.find("test_function")
    assert File.exist?(@cache.path_for(source))
    assert_equal @cache.path_for(source), @cache.path
    assert_includes err, "not found, rebuilding"
  end

  def test_loads_from_the_cache_without_building
    prime_cache
    CF::MCP::Index.instance.reset!

    _, err = capture_io { @cache.index(source) { flunk "built despite a fresh cache" } }

    assert CF::MCP::Index.instance.find("test_function")
    assert_empty err
  end

  def test_loaded_index_rebuilds_its_lookups
    built = prime_cache
    stats = built.stats
    CF::MCP::Index.instance.reset!

    loaded = @cache.index { flunk "built despite a fresh cache" }

    assert_equal stats, loaded.stats
    assert_equal built.categories, loaded.categories
    assert_equal ["audio"], loaded.topics_for("cf_play").map(&:name)
  end

  def test_rebuilds_when_a_header_changes
    prime_cache
    header = File.join(@root, "include", "sample_header.h")
    File.write(header, File.read(header) + "\n/**\n * @function brand_new_function\n * @category test\n * @brief New.\n */\nvoid brand_new_function(void);\n")

    index = nil
    _, err = capture_io { index = @cache.index { |source| builder_for(source) } }

    assert index.find("brand_new_function")
    assert_includes err, "stale, rebuilding"
  end

  def test_rebuilds_when_a_topic_changes
    prime_cache
    File.write(File.join(@root, "docs", "topics", "video.md"), "# Video\n\nDraw frames.\n")

    index = nil
    capture_io { index = @cache.index { |source| builder_for(source) } }

    assert index.find("video")
  end

  def test_rebuilds_instead_of_raising_on_a_corrupt_cache
    FileUtils.mkdir_p(File.dirname(@cache.path_for(source)))
    File.binwrite(@cache.path_for(source), "not a marshal dump")

    index = nil
    capture_io { index = @cache.index(source) { |source| builder_for(source) } }

    assert index.find("test_function")
  end

  def test_rebuilds_when_the_cache_was_written_by_another_gem_version
    prime_cache
    stale = CF::MCP::IndexCache::Payload.new(**payload_on_disk.to_h, gem_version: "0.0.0")
    File.binwrite(@cache.path_for(source), Marshal.dump(stale))

    builds = builds_during { |build| capture_io { @cache.index(&build) } }

    assert_equal 1, builds.size
  end

  def test_rebuilds_for_a_different_source
    other = build_other_checkout
    prime_cache

    index = nil
    capture_io { index = @cache.index(source(other)) { |source| builder_for(source) } }

    assert index.find("other_function")
    refute index.find("test_function")
  end

  def test_keeps_a_cache_per_source
    other = build_other_checkout
    prime_cache
    capture_io { @cache.index(source(other)) { |source| builder_for(source) } }
    CF::MCP::Index.instance.reset!

    _, err = capture_io { @cache.index(source) { flunk "rebuilt a source that was already cached" } }

    assert CF::MCP::Index.instance.find("test_function")
    refute CF::MCP::Index.instance.find("other_function")
    assert_empty err
  end

  def test_uses_the_last_source_when_none_is_given
    other = build_other_checkout
    prime_cache
    capture_io { @cache.index(source(other)) { |source| builder_for(source) } }
    CF::MCP::Index.instance.reset!

    index = @cache.index { flunk "rebuilt a fresh cache" }

    assert index.find("other_function")
    refute index.find("test_function")
  end

  def test_builds_from_the_default_source_when_none_was_ever_used
    builds = []

    capture_io do
      @cache.index do |source|
        builds << source
        builder_for(self.source)
      end
    end

    assert_equal [CF::MCP::IndexCache::DEFAULT_SOURCE], builds
  end

  def test_rebuilds_from_the_recorded_source_when_none_is_given
    prime_cache
    FileUtils.touch(File.join(@root, "include", "sample_header.h"), mtime: Time.now + 60)

    builds = builds_during { |build| capture_io { @cache.index(&build) } }

    assert_equal [source], builds
  end

  def test_keeps_the_cache_when_the_headers_are_gone
    prime_cache
    FileUtils.rm_rf(@root)
    CF::MCP::Index.instance.reset!

    index = @cache.index { flunk "rebuilt from a vanished checkout" }

    assert index.find("test_function")
  end

  # Stands in for a header deleted between listing the directory and reading it.
  def test_a_header_that_vanishes_while_checking_does_not_fail_the_lookup
    prime_cache
    File.symlink(File.join(@tmp, "missing.h"), File.join(@root, "include", "vanished.h"))
    CF::MCP::Index.instance.reset!

    index = @cache.index { flunk "rebuilt over a header that is not there" }

    assert index.find("test_function")
  end

  def test_refresh_rebuilds_even_when_the_cache_is_fresh
    prime_cache

    builds = builds_during { |build| @cache.refresh(&build) }

    assert_equal 1, builds.size
  end

  def test_refresh_reuses_the_recorded_source
    prime_cache

    builds = builds_during { |build| @cache.refresh(&build) }

    assert_equal [source], builds
  end

  def test_revision_survives_a_cache_hit
    init_git_repo(@root)
    capture_io { @cache.refresh(source) { |source| builder_for(source) } }
    revision = @cache.revision

    assert_match(/\A[0-9a-f]{7,40}\z/, revision)

    reloaded = CF::MCP::IndexCache.new(dir: File.dirname(@cache.path_for(source)))
    reloaded.index { flunk "built despite a fresh cache" }

    assert_equal revision, reloaded.revision
  end

  def test_refuses_to_cache_a_missing_headers_directory
    missing = File.join(@tmp, "missing")

    error = assert_raises(CF::MCP::Error) { @cache.refresh(source(missing)) { |source| builder_for(source) } }

    assert_includes error.message, missing
    refute File.exist?(@cache.path_for(source(missing)))
  end

  def test_default_dir_honours_the_cache_dir_variable
    with_env("CF_MCP_CACHE_DIR" => "/tmp/somewhere") do
      assert_equal "/tmp/somewhere", CF::MCP::IndexCache.default_dir
    end
  end

  def test_default_dir_falls_back_to_xdg_cache_home
    with_env("CF_MCP_CACHE_DIR" => nil, "XDG_CACHE_HOME" => "/tmp/xdg") do
      assert_equal "/tmp/xdg/cf-mcp", CF::MCP::IndexCache.default_dir
    end
  end

  private

  def prime_cache
    index = nil
    capture_io { index = @cache.index(source) { |source| builder_for(source) } }
    index
  end

  def source(root = @root)
    {root: root, download: false}
  end

  def builder_for(source)
    CF::MCP::IndexBuilder.new(**source)
  end

  # Yields a block to hand to the cache; returns the sources it was asked to build.
  def builds_during
    sources = []
    yield proc { |source|
      sources << source
      builder_for(source)
    }
    sources
  end

  # A checkout whose only documented item is other_function.
  def build_other_checkout
    other = build_checkout("other_framework")
    File.write(File.join(other, "include", "sample_header.h"), "/**\n * @function other_function\n * @category other\n */\n")
    other
  end

  def build_checkout(name)
    root = File.join(@tmp, name)
    FileUtils.mkdir_p(File.join(root, "include"))
    FileUtils.mkdir_p(File.join(root, "docs", "topics"))
    FileUtils.cp(FIXTURE, File.join(root, "include"))
    File.write(File.join(root, "docs", "topics", "audio.md"), <<~MD)
      # Audio

      Play sounds with [cf_play](../audio/cf_play.md).
    MD
    root
  end

  def payload_on_disk
    Marshal.load(File.binread(@cache.path_for(source)))
  end

  def init_git_repo(dir)
    Open3.capture3("git", "-C", dir, "init", "-q")
    Open3.capture3("git", "-C", dir, "config", "user.email", "test@example.com")
    Open3.capture3("git", "-C", dir, "config", "user.name", "Test")
    Open3.capture3("git", "-C", dir, "add", ".")
    Open3.capture3("git", "-C", dir, "commit", "-q", "-m", "initial commit")
  end

  def with_env(vars)
    saved = vars.keys.to_h { |key| [key, ENV[key]] }
    vars.each { |key, value| ENV[key] = value }
    yield
  ensure
    saved.each { |key, value| ENV[key] = value }
  end
end
