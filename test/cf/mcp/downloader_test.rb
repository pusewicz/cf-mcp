# frozen_string_literal: true

require "test_helper"
require "zip"
require "tmpdir"

class CF::MCP::DownloaderTest < Minitest::Test
  def setup
    @temp_dir = Dir.mktmpdir("cf-mcp-downloader-test")
    @downloader = CF::MCP::Downloader.new(download_dir: @temp_dir)
  end

  def teardown
    FileUtils.rm_rf(@temp_dir) if @temp_dir && File.directory?(@temp_dir)
  end

  def test_extract_directories_extracts_include_files
    zip_path = create_test_zip
    base_path = File.join(@temp_dir, "cute_framework")

    @downloader.send(:extract_directories, zip_path, base_path)

    # Verify include directory was created
    include_path = File.join(base_path, "include")
    assert File.directory?(include_path), "include directory should exist"

    # Verify header file was extracted with correct content
    header_path = File.join(include_path, "cute.h")
    assert File.file?(header_path), "cute.h should be extracted"
    assert_equal "// Cute Framework Header\n", File.read(header_path)
  end

  def test_extract_directories_extracts_docs_topics
    zip_path = create_test_zip
    base_path = File.join(@temp_dir, "cute_framework")

    @downloader.send(:extract_directories, zip_path, base_path)

    # Verify docs/topics directory was created
    topics_path = File.join(base_path, "docs", "topics")
    assert File.directory?(topics_path), "docs/topics directory should exist"

    # Verify topic file was extracted with correct content
    topic_path = File.join(topics_path, "getting_started.md")
    assert File.file?(topic_path), "getting_started.md should be extracted"
    assert_equal "# Getting Started\n", File.read(topic_path)
  end

  def test_extract_directories_ignores_other_files
    zip_path = create_test_zip
    base_path = File.join(@temp_dir, "cute_framework")

    @downloader.send(:extract_directories, zip_path, base_path)

    # Verify src directory was NOT extracted
    src_path = File.join(base_path, "src")
    refute File.directory?(src_path), "src directory should not be extracted"
  end

  def test_extract_directories_extracts_nested_include_files
    zip_path = create_test_zip_with_nested_includes
    base_path = File.join(@temp_dir, "cute_framework")

    @downloader.send(:extract_directories, zip_path, base_path)

    # Verify nested header file was extracted
    nested_header = File.join(base_path, "include", "cute", "math.h")
    assert File.file?(nested_header), "nested header cute/math.h should be extracted"
    assert_equal "// Math utilities\n", File.read(nested_header)
  end

  def test_extract_directories_raises_on_missing_include
    zip_path = create_zip_without_include
    base_path = File.join(@temp_dir, "cute_framework")

    assert_raises(CF::MCP::Downloader::DownloadError) do
      @downloader.send(:extract_directories, zip_path, base_path)
    end
  end

  def test_extract_directories_cleans_existing_base_path
    zip_path = create_test_zip
    base_path = File.join(@temp_dir, "cute_framework")

    # Create a pre-existing file that should be removed
    FileUtils.mkdir_p(base_path)
    stale_file = File.join(base_path, "stale.txt")
    File.write(stale_file, "should be removed")

    @downloader.send(:extract_directories, zip_path, base_path)

    refute File.exist?(stale_file), "stale file should be removed"
  end

  def test_extract_directories_with_sha_based_prefix
    # Create mock zip with SHA-based prefix
    zip_path = create_test_zip_with_sha("abc1234")
    base_path = File.join(@temp_dir, "cute_framework")

    @downloader.send(:extract_directories, zip_path, base_path)

    # Verify extraction works with SHA prefix
    include_path = File.join(base_path, "include")
    assert File.directory?(include_path)

    header_path = File.join(include_path, "cute.h")
    assert File.file?(header_path)
    assert_equal "// Cute Framework Header\n", File.read(header_path)
  end

  def test_read_sha_metadata_returns_stored_sha
    sha_file = File.join(@temp_dir, ".cf-mcp-sha")
    File.write(sha_file, "abc1234")

    sha = @downloader.send(:read_sha_metadata, sha_file)
    assert_equal "abc1234", sha
  end

  def test_read_sha_metadata_returns_nil_when_missing
    sha_file = File.join(@temp_dir, ".cf-mcp-sha")

    sha = @downloader.send(:read_sha_metadata, sha_file)
    assert_nil sha
  end

  def test_read_sha_metadata_handles_whitespace
    sha_file = File.join(@temp_dir, ".cf-mcp-sha")
    File.write(sha_file, "  abc1234\n  ")

    sha = @downloader.send(:read_sha_metadata, sha_file)
    assert_equal "abc1234", sha
  end

  def test_write_sha_metadata_stores_sha
    sha_file = File.join(@temp_dir, ".cf-mcp-sha")

    @downloader.send(:write_sha_metadata, sha_file, "abc1234")

    assert File.exist?(sha_file)
    assert_equal "abc1234", File.read(sha_file).strip
  end

  def test_write_sha_metadata_skips_nil_sha
    sha_file = File.join(@temp_dir, ".cf-mcp-sha")

    @downloader.send(:write_sha_metadata, sha_file, nil)

    refute File.exist?(sha_file)
  end

  private

  def create_test_zip
    zip_path = File.join(@temp_dir, "test.zip")

    Zip::File.open(zip_path, create: true) do |zipfile|
      # Add top-level directory structure like GitHub zip
      zipfile.mkdir("cute_framework-master")
      zipfile.mkdir("cute_framework-master/include")
      zipfile.mkdir("cute_framework-master/docs")
      zipfile.mkdir("cute_framework-master/docs/topics")
      zipfile.mkdir("cute_framework-master/src")

      # Add files
      zipfile.get_output_stream("cute_framework-master/include/cute.h") do |f|
        f.write("// Cute Framework Header\n")
      end

      zipfile.get_output_stream("cute_framework-master/docs/topics/getting_started.md") do |f|
        f.write("# Getting Started\n")
      end

      zipfile.get_output_stream("cute_framework-master/src/main.c") do |f|
        f.write("// Should not be extracted\n")
      end
    end

    zip_path
  end

  def create_test_zip_with_nested_includes
    zip_path = File.join(@temp_dir, "test_nested.zip")

    Zip::File.open(zip_path, create: true) do |zipfile|
      zipfile.mkdir("cute_framework-master")
      zipfile.mkdir("cute_framework-master/include")
      zipfile.mkdir("cute_framework-master/include/cute")

      zipfile.get_output_stream("cute_framework-master/include/cute.h") do |f|
        f.write("// Cute Framework Header\n")
      end

      zipfile.get_output_stream("cute_framework-master/include/cute/math.h") do |f|
        f.write("// Math utilities\n")
      end
    end

    zip_path
  end

  def create_zip_without_include
    zip_path = File.join(@temp_dir, "test_no_include.zip")

    Zip::File.open(zip_path, create: true) do |zipfile|
      zipfile.mkdir("cute_framework-master")
      zipfile.mkdir("cute_framework-master/src")

      zipfile.get_output_stream("cute_framework-master/src/main.c") do |f|
        f.write("// No include directory\n")
      end
    end

    zip_path
  end

  def create_test_zip_with_sha(sha)
    zip_path = File.join(@temp_dir, "test_sha.zip")

    Zip::File.open(zip_path, create: true) do |zipfile|
      zipfile.mkdir("cute_framework-#{sha}")
      zipfile.mkdir("cute_framework-#{sha}/include")

      zipfile.get_output_stream("cute_framework-#{sha}/include/cute.h") do |f|
        f.write("// Cute Framework Header\n")
      end
    end

    zip_path
  end
end
