# frozen_string_literal: true

require "test_helper"
require "tmpdir"
require "fileutils"
require "open3"
require "rackup"

class CF::MCP::CLITest < Minitest::Test
  FIXTURE = File.expand_path("../../fixtures/sample_header.h", __dir__)

  def setup
    @tmp = File.realpath(Dir.mktmpdir("cf-mcp-cli-test"))
    @root = File.join(@tmp, "cute_framework")
    FileUtils.mkdir_p(File.join(@root, "include"))
    FileUtils.cp(FIXTURE, File.join(@root, "include"))
    @saved_cache_dir = ENV["CF_MCP_CACHE_DIR"]
    ENV["CF_MCP_CACHE_DIR"] = File.join(@tmp, "cache")
  end

  def teardown
    ENV["CF_MCP_CACHE_DIR"] = @saved_cache_dir
    FileUtils.rm_rf(@tmp)
    CF::MCP::Index.instance.reset!
    CF::MCP::Index.instance.add(CF::MCP::Models::FunctionDoc.new(name: "test_func", category: "test", brief: "Test"))
  end

  def test_help_lists_the_commands
    status, out, = run_cli("--help")

    assert_equal 0, status
    %w[stdio http index].each { |command| assert_includes out, command }
  end

  def test_help_command_prints_usage
    status, out, = run_cli("help")

    assert_equal 0, status
    assert_includes out, "Usage: cf-mcp"
  end

  def test_no_arguments_prints_usage
    status, out, = run_cli

    assert_equal 0, status
    assert_includes out, "Usage: cf-mcp"
  end

  def test_version
    status, out, = run_cli("--version")

    assert_equal 0, status
    assert_equal "cf-mcp #{CF::MCP::VERSION}\n", out
  end

  def test_unknown_command_fails
    status, _, err = run_cli("bogus")

    assert_equal 1, status
    assert_includes err, "Unknown command 'bogus'"
  end

  def test_unknown_option_fails
    status, _, err = run_cli("--bogus")

    assert_equal 1, status
    assert_includes err, "invalid option: --bogus"
  end

  def test_unexpected_arguments_fail
    status, _, err = run_cli("index", "extra", "--root", @root)

    assert_equal 1, status
    assert_includes err, "Unexpected arguments: extra"
  end

  def test_index_builds_the_cache
    status, out, = run_cli("index", "--root", @root)

    assert_equal 0, status
    assert_includes out, "Indexed 4 items (2 functions, 1 structs, 1 enums, 0 topics)"
    assert_equal 1, Dir.glob(File.join(ENV.fetch("CF_MCP_CACHE_DIR"), "index-*.bin")).size
  end

  def test_index_accepts_options_before_the_command
    status, out, = run_cli("--root", @root, "index")

    assert_equal 0, status
    assert_includes out, "Indexed 4 items"
  end

  def test_index_fails_for_a_missing_headers_directory
    status, _, err = run_cli("index", "--root", File.join(@tmp, "missing"))

    assert_equal 1, status
    assert_includes err, "Headers directory not found"
  end

  def test_index_picks_up_new_headers_when_run_again
    index_headers
    File.write(File.join(@root, "include", "extra.h"), "/**\n * @function extra_function\n * @category test\n */\n")

    status, out, = run_cli("index")

    assert_equal 0, status
    assert_includes out, "Indexed 5 items"
  end

  def test_help_lists_the_tool_commands
    _, out, = run_cli("--help")

    assert_includes out, "search"
  end

  def test_search_reads_the_cached_index
    index_headers

    status, out, err = run_cli("search", "test_function")

    assert_equal 0, status
    assert_includes out, "test_function"
    assert_empty err
  end

  def test_search_builds_the_index_when_there_is_no_cache
    status, out, err = run_cli("--root", @root, "search", "test_function")

    assert_equal 0, status
    assert_includes out, "test_function"
    assert_includes err, "rebuilding"
  end

  def test_tool_flags_follow_the_command
    index_headers

    status, out, = run_cli("search", "function", "--type", "function", "--limit", "1")

    assert_equal 0, status
    assert_includes out, "limit reached"
  end

  def test_tool_commands_accept_the_root_after_their_arguments
    status, out, = run_cli("search", "test_function", "--root", @root)

    assert_equal 0, status
    assert_includes out, "test_function"
  end

  def test_tool_commands_accept_the_root_between_their_flags
    status, out, = run_cli("search", "--type", "function", "--root=#{@root}", "test_function")

    assert_equal 0, status
    assert_includes out, "test_function"
  end

  def test_tool_commands_accept_download_after_their_arguments
    status, out, = stub_downloader { run_cli("search", "test_function", "--download") }

    assert_equal 0, status
    assert_includes out, "test_function"
  end

  def test_each_root_keeps_its_own_index
    other = build_other_checkout
    index_headers
    run_cli("index", "--root", other)

    _, out, err = run_cli("--root", @root, "search", "test_function")

    assert_includes out, "test_function"
    assert_empty err

    _, out, err = run_cli("--root", other, "search", "other_function")

    assert_includes out, "**other_function**"
    assert_empty err
  end

  def test_tool_commands_use_the_root_they_are_given
    other = build_other_checkout
    index_headers

    _, out, = run_cli("--root", other, "search", "other_function")
    assert_includes out, "**other_function**"

    _, out, = run_cli("--root", other, "search", "test_function")
    assert_includes out, "No results found"
  end

  def test_tool_commands_without_a_root_use_the_last_one_given
    other = build_other_checkout
    index_headers
    run_cli("index", "--root", other)

    _, out, = run_cli("search", "other_function")

    assert_includes out, "**other_function**"
  end

  def test_a_relative_root_names_the_same_index_as_its_full_path
    Dir.chdir(@tmp) { run_cli("index", "--root", "cute_framework") }

    _, out, err = run_cli("--root", @root, "search", "test_function")

    assert_includes out, "test_function"
    assert_empty err
  end

  def test_the_headers_path_variable_selects_the_index
    other = build_other_checkout
    index_headers

    _, out, = with_env("CF_HEADERS_PATH" => File.join(other, "include")) { run_cli("search", "other_function") }

    assert_includes out, "**other_function**"
  end

  def test_tool_commands_need_a_value_for_the_root
    status, _, err = run_cli("search", "test_function", "--root")

    assert_equal 1, status
    assert_includes err, "missing argument: --root"
  end

  def test_tool_help
    index_headers

    status, out, = run_cli("search", "--help")

    assert_equal 0, status
    assert_includes out, "Usage: cf-mcp search QUERY [options]"
  end

  def test_tool_argument_errors_fail
    index_headers

    status, _, err = run_cli("search", "function", "--type", "bogus")

    assert_equal 1, status
    assert_includes err, "invalid argument: --type bogus"
  end

  def test_categories_are_available_to_a_fresh_process
    index_headers
    exe = File.expand_path("../../../exe/cf-mcp", __dir__)
    lib = File.expand_path("../../../lib", __dir__)

    out, err, status = Open3.capture3(RbConfig.ruby, "-I", lib, exe, "search", "test_function", "--category", "test")

    assert status.success?, err
    assert_includes out, "test_function"
  end

  def test_get_details_prints_the_documentation
    index_headers

    status, out, = run_cli("get_details", "test_function")

    assert_equal 0, status
    assert_includes out, "# test_function"
    assert_includes out, "const char* input"
  end

  def test_command_names_accept_hyphens
    index_headers

    status, out, = run_cli("get-details", "TestStruct")

    assert_equal 0, status
    assert_includes out, "# TestStruct"
  end

  def test_find_related_lists_related_items
    index_headers

    status, out, = run_cli("find_related", "TestStruct")

    assert_equal 0, status
    assert_includes out, "# Related items for TestStruct"
    assert_includes out, "`test_function`"
  end

  def test_get_topic_prints_the_guide
    add_topic("audio", "# Audio\n\nPlay sounds with the mixer.\n")
    index_headers

    status, out, = run_cli("get_topic", "audio")

    assert_equal 0, status
    assert_includes out, "# audio"
    assert_includes out, "Play sounds with the mixer."
  end

  def test_member_search_finds_structs_by_member
    index_headers

    status, out, = run_cli("member_search", "int value", "--limit", "5")

    assert_equal 0, status
    assert_includes out, "**TestStruct**"
    assert_includes out, "`int value`"
  end

  def test_parameter_search_finds_functions_by_type
    index_headers

    status, out, = run_cli("parameter_search", "TestStruct", "--direction", "output")

    assert_equal 0, status
    assert_includes out, "## Returns (1)"
    assert_includes out, "**test_function**"
    refute_includes out, "## Takes as input"
  end

  def test_list_category_lists_the_categories
    index_headers

    status, out, = run_cli("list_category")

    assert_equal 0, status
    assert_includes out, "Available categories"
    assert_includes out, "**test**"
  end

  def test_list_category_lists_the_items_in_a_category
    index_headers

    status, out, = run_cli("list_category", "test", "--type", "function")

    assert_equal 0, status
    assert_includes out, "**test_function**"
    refute_includes out, "**TestStruct**"
  end

  def test_list_topics_lists_the_guides_in_reading_order
    add_topic("audio", "# Audio\n\nSound.\n")
    add_topic("drawing", "# Drawing\n\nShapes.\n")
    add_topic("index", "1. [Drawing](./drawing.md)\n2. [Audio](./audio.md)\n")
    index_headers

    status, out, = run_cli("list_topics", "--ordered")

    assert_equal 0, status
    assert_operator out.index("**drawing**"), :<, out.index("**audio**")
  end

  def test_every_tool_has_a_command
    assert_equal CF::MCP::Tools.all.map(&:tool_name).sort, CF::MCP::CLI::TOOL_COMMANDS.sort
  end

  def test_http_accepts_options_after_the_command
    started = stub_rackup_start do
      run_cli("http", "--root", @root, "--port", "4567", "--host", "127.0.0.1")
    end

    assert_equal 4567, started.fetch(:Port)
    assert_equal "127.0.0.1", started.fetch(:Host)
  end

  private

  def run_cli(*args)
    status = nil
    out, err = capture_io { status = CF::MCP::CLI.new(args).run }
    [status, out, err]
  end

  def index_headers
    run_cli("index", "--root", @root)
  end

  # A checkout whose only documented item is other_function.
  def build_other_checkout
    other = File.join(@tmp, "other_framework")
    FileUtils.mkdir_p(File.join(other, "include"))
    File.write(File.join(other, "include", "other.h"), "/**\n * @function other_function\n * @category other\n */\n")
    other
  end

  def with_env(vars)
    saved = vars.keys.to_h { |key| [key, ENV[key]] }
    vars.each { |key, value| ENV[key] = value }
    yield
  ensure
    saved.each { |key, value| ENV[key] = value }
  end

  def add_topic(name, content)
    FileUtils.mkdir_p(File.join(@root, "docs", "topics"))
    File.write(File.join(@root, "docs", "topics", "#{name}.md"), content)
  end

  # Makes the downloader "fetch" the fixture checkout instead of using the network.
  def stub_downloader
    downloader = Object.new
    headers = File.join(@root, "include")
    downloader.define_singleton_method(:download_and_extract) { headers }
    downloader.define_singleton_method(:sha) { "abc1234" }
    CF::MCP::Downloader.define_singleton_method(:new) { downloader }
    yield
  ensure
    CF::MCP::Downloader.singleton_class.send(:remove_method, :new)
  end

  # Replaces Rackup::Server.start for the block; returns the options it was given.
  def stub_rackup_start
    original = Rackup::Server.method(:start)
    started = {}
    Rackup::Server.singleton_class.remove_method(:start)
    Rackup::Server.define_singleton_method(:start) { |**options| started.merge!(options) }
    yield
    started
  ensure
    Rackup::Server.singleton_class.remove_method(:start)
    Rackup::Server.define_singleton_method(:start, original)
  end
end
