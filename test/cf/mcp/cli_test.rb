# frozen_string_literal: true

require "test_helper"

class CF::MCP::CLITest < Minitest::Test
  def test_parse_args_with_stdio_command
    cli = CF::MCP::CLI.new(["stdio"])
    options = cli.instance_variable_get(:@options)

    assert_equal :stdio, options[:command]
  end

  def test_parse_args_with_http_command
    cli = CF::MCP::CLI.new(["http"])
    options = cli.instance_variable_get(:@options)

    assert_equal :http, options[:command]
  end

  def test_parse_args_with_help_flag
    cli = CF::MCP::CLI.new(["--help"])
    options = cli.instance_variable_get(:@options)

    assert_equal :help, options[:command]
  end

  def test_parse_args_with_short_help_flag
    cli = CF::MCP::CLI.new(["-h"])
    options = cli.instance_variable_get(:@options)

    assert_equal :help, options[:command]
  end

  def test_parse_args_defaults_to_help
    cli = CF::MCP::CLI.new([])
    options = cli.instance_variable_get(:@options)

    assert_equal :help, options[:command]
  end

  def test_parse_args_with_root_option
    cli = CF::MCP::CLI.new(["stdio", "--root", "/tmp/test"])
    options = cli.instance_variable_get(:@options)

    assert_equal "/tmp/test", options[:root]
  end

  def test_parse_args_with_short_root_option
    cli = CF::MCP::CLI.new(["stdio", "-r", "/tmp/test"])
    options = cli.instance_variable_get(:@options)

    assert_equal "/tmp/test", options[:root]
  end

  def test_parse_args_with_port_option
    cli = CF::MCP::CLI.new(["http", "--port", "8080"])
    options = cli.instance_variable_get(:@options)

    assert_equal 8080, options[:port]
  end

  def test_parse_args_with_short_port_option
    cli = CF::MCP::CLI.new(["http", "-p", "8080"])
    options = cli.instance_variable_get(:@options)

    assert_equal 8080, options[:port]
  end

  def test_parse_args_with_host_option
    cli = CF::MCP::CLI.new(["http", "--host", "127.0.0.1"])
    options = cli.instance_variable_get(:@options)

    assert_equal "127.0.0.1", options[:host]
  end

  def test_parse_args_with_short_host_option
    cli = CF::MCP::CLI.new(["http", "-H", "127.0.0.1"])
    options = cli.instance_variable_get(:@options)

    assert_equal "127.0.0.1", options[:host]
  end

  def test_parse_args_with_download_flag
    cli = CF::MCP::CLI.new(["stdio", "--download"])
    options = cli.instance_variable_get(:@options)

    assert_equal true, options[:download]
  end

  def test_parse_args_with_short_download_flag
    cli = CF::MCP::CLI.new(["stdio", "-d"])
    options = cli.instance_variable_get(:@options)

    assert_equal true, options[:download]
  end

  def test_parse_args_default_host
    cli = CF::MCP::CLI.new(["http"])
    options = cli.instance_variable_get(:@options)

    assert_equal "0.0.0.0", options[:host]
  end

  def test_parse_args_default_download_false
    cli = CF::MCP::CLI.new(["stdio"])
    options = cli.instance_variable_get(:@options)

    assert_equal false, options[:download]
  end

  def test_parse_args_with_unknown_command
    cli = CF::MCP::CLI.new(["unknown"])
    options = cli.instance_variable_get(:@options)

    assert_equal :help, options[:command]
  end

  def test_option_parser_available
    cli = CF::MCP::CLI.new([])
    parser = cli.instance_variable_get(:@option_parser)

    refute_nil parser
    assert_kind_of OptionParser, parser
  end
end
