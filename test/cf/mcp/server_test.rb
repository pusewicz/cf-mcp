# frozen_string_literal: true

require "test_helper"
require "json"
require "stringio"

class CF::MCP::ServerTest < Minitest::Test
  def setup
    @index = CF::MCP::Index.new
    @index.add(CF::MCP::Models::FunctionDoc.new(
      name: "cf_make_sprite",
      category: "sprite",
      brief: "Loads a sprite from an aseprite file.",
      signature: "CF_Sprite cf_make_sprite(const char* path)"
    ))
    @index.add(CF::MCP::Models::StructDoc.new(
      name: "CF_Sprite",
      category: "sprite",
      brief: "A sprite represents a drawable entity."
    ))
    @index.add(CF::MCP::Models::EnumDoc.new(
      name: "CF_PlayDirection",
      category: "sprite",
      brief: "The direction a sprite plays frames."
    ))

    @server = CF::MCP::Server.new(@index)
  end

  def test_server_initializes_with_correct_name_and_version
    assert_equal "cf-mcp", @server.server.name
    assert_equal CF::MCP::VERSION, @server.server.version
  end

  def test_server_has_index
    assert_equal @index, @server.index
  end

  def test_server_context_contains_index
    assert_equal @index, @server.server.server_context[:index]
  end

  def test_server_tools_constant_contains_all_tool_classes
    expected_tools = [
      CF::MCP::Tools::SearchTool,
      CF::MCP::Tools::SearchFunctions,
      CF::MCP::Tools::SearchStructs,
      CF::MCP::Tools::SearchEnums,
      CF::MCP::Tools::ListCategory,
      CF::MCP::Tools::GetDetails
    ]

    assert_equal expected_tools, CF::MCP::Server::TOOLS
  end

  def test_http_app_returns_rack_app
    app = @server.http_app
    assert_respond_to app, :call
  end
end

# HTTP transport integration tests
class CF::MCP::ServerHTTPTest < Minitest::Test
  def setup
    @index = CF::MCP::Index.new
    @index.add(CF::MCP::Models::FunctionDoc.new(
      name: "cf_make_sprite",
      category: "sprite",
      brief: "Loads a sprite from an aseprite file.",
      signature: "CF_Sprite cf_make_sprite(const char* path)"
    ))

    @server = CF::MCP::Server.new(@index)
    @app = @server.http_app
  end

  def test_http_initialize_request
    response = make_request("initialize", {
      protocolVersion: "2024-11-05",
      capabilities: {},
      clientInfo: {name: "test", version: "1.0"}
    })

    assert_equal 200, response.status
    body = JSON.parse(response.body)
    assert_equal "cf-mcp", body["result"]["serverInfo"]["name"]
  end

  def test_http_tools_list
    response = make_request("tools/list", {})

    assert_equal 200, response.status
    body = JSON.parse(response.body)
    tools = body["result"]["tools"]
    assert_equal 6, tools.size
  end

  def test_http_tools_call_search
    response = make_request("tools/call", {
      name: "cf_search",
      arguments: {query: "sprite"}
    })

    assert_equal 200, response.status
    body = JSON.parse(response.body)
    refute body["result"]["isError"]
    assert_includes body["result"]["content"].first["text"], "cf_make_sprite"
  end

  def test_http_requires_accept_header
    env = Rack::MockRequest.env_for(
      "/",
      method: "POST",
      input: JSON.generate({jsonrpc: "2.0", id: 1, method: "initialize", params: {}})
    )
    env["CONTENT_TYPE"] = "application/json"
    # No Accept header

    response = Rack::MockResponse.new(*@app.call(env))

    assert_equal 406, response.status
  end

  private

  def make_request(method, params, id: 1)
    body = JSON.generate({
      jsonrpc: "2.0",
      id: id,
      method: method,
      params: params
    })

    env = Rack::MockRequest.env_for(
      "/",
      method: "POST",
      input: body
    )
    env["CONTENT_TYPE"] = "application/json"
    env["HTTP_ACCEPT"] = "application/json, text/event-stream"

    Rack::MockResponse.new(*@app.call(env))
  end
end

# Integration tests using STDIO transport simulation
class CF::MCP::ServerIntegrationTest < Minitest::Test
  def setup
    @index = CF::MCP::Index.new
    @index.add(CF::MCP::Models::FunctionDoc.new(
      name: "cf_make_sprite",
      category: "sprite",
      brief: "Loads a sprite from an aseprite file.",
      signature: "CF_Sprite cf_make_sprite(const char* path)"
    ))
    @index.add(CF::MCP::Models::StructDoc.new(
      name: "CF_Sprite",
      category: "sprite",
      brief: "A sprite represents a drawable entity."
    ))
    @index.add(CF::MCP::Models::EnumDoc.new(
      name: "CF_PlayDirection",
      category: "sprite",
      brief: "The direction a sprite plays frames."
    ))

    @server = CF::MCP::Server.new(@index)
  end

  def test_stdio_initialize_and_search_tool
    responses = run_stdio_requests([
      initialize_request(1),
      tools_call_request(2, "cf_search", {query: "sprite"})
    ])

    # Check initialize response
    init_response = responses[0]
    assert_equal "2.0", init_response["jsonrpc"]
    assert_equal 1, init_response["id"]
    refute init_response.key?("error")
    assert_equal "cf-mcp", init_response["result"]["serverInfo"]["name"]

    # Check search response
    search_response = responses[1]
    assert_equal 2, search_response["id"]
    refute search_response["result"]["isError"]
    text = search_response["result"]["content"].first["text"]
    assert_includes text, "Found"
    assert_includes text, "cf_make_sprite"
  end

  def test_stdio_cf_get_details_tool
    responses = run_stdio_requests([
      initialize_request(1),
      tools_call_request(2, "cf_get_details", {name: "cf_make_sprite"})
    ])

    response = responses[1]
    refute response["result"]["isError"]
    text = response["result"]["content"].first["text"]
    assert_includes text, "cf_make_sprite"
    assert_includes text, "Loads a sprite"
  end

  def test_stdio_cf_search_functions_tool
    responses = run_stdio_requests([
      initialize_request(1),
      tools_call_request(2, "cf_search_functions", {query: "sprite"})
    ])

    response = responses[1]
    refute response["result"]["isError"]
    text = response["result"]["content"].first["text"]
    assert_includes text, "cf_make_sprite"
  end

  def test_stdio_cf_search_structs_tool
    responses = run_stdio_requests([
      initialize_request(1),
      tools_call_request(2, "cf_search_structs", {query: "sprite"})
    ])

    response = responses[1]
    refute response["result"]["isError"]
    text = response["result"]["content"].first["text"]
    assert_includes text, "CF_Sprite"
  end

  def test_stdio_cf_search_enums_tool
    responses = run_stdio_requests([
      initialize_request(1),
      tools_call_request(2, "cf_search_enums", {query: "direction"})
    ])

    response = responses[1]
    refute response["result"]["isError"]
    text = response["result"]["content"].first["text"]
    assert_includes text, "CF_PlayDirection"
  end

  def test_stdio_cf_list_category_tool
    responses = run_stdio_requests([
      initialize_request(1),
      tools_call_request(2, "cf_list_category", {})
    ])

    response = responses[1]
    refute response["result"]["isError"]
    text = response["result"]["content"].first["text"]
    assert_includes text, "sprite"
  end

  def test_stdio_search_no_results
    responses = run_stdio_requests([
      initialize_request(1),
      tools_call_request(2, "cf_search", {query: "nonexistent_xyz"})
    ])

    response = responses[1]
    refute response["result"]["isError"]
    text = response["result"]["content"].first["text"]
    assert_includes text, "No results found"
  end

  def test_stdio_get_details_not_found
    responses = run_stdio_requests([
      initialize_request(1),
      tools_call_request(2, "cf_get_details", {name: "nonexistent_function"})
    ])

    response = responses[1]
    refute response["result"]["isError"]
    text = response["result"]["content"].first["text"]
    assert_includes text, "Not found"
  end

  def test_stdio_tools_list
    responses = run_stdio_requests([
      initialize_request(1),
      {jsonrpc: "2.0", id: 2, method: "tools/list", params: {}}
    ])

    response = responses[1]
    refute response.key?("error")

    tools = response["result"]["tools"]
    assert_equal 6, tools.size

    tool_names = tools.map { |t| t["name"] }
    assert_includes tool_names, "cf_search"
    assert_includes tool_names, "cf_search_functions"
    assert_includes tool_names, "cf_search_structs"
    assert_includes tool_names, "cf_search_enums"
    assert_includes tool_names, "cf_list_category"
    assert_includes tool_names, "cf_get_details"
  end

  private

  def initialize_request(id)
    {
      jsonrpc: "2.0",
      id: id,
      method: "initialize",
      params: {
        protocolVersion: "2024-11-05",
        capabilities: {},
        clientInfo: {name: "test", version: "1.0"}
      }
    }
  end

  def tools_call_request(id, tool_name, arguments)
    {
      jsonrpc: "2.0",
      id: id,
      method: "tools/call",
      params: {
        name: tool_name,
        arguments: arguments
      }
    }
  end

  def run_stdio_requests(requests)
    input = requests.map { |r| JSON.generate(r) }.join("\n")
    stdin = StringIO.new(input)
    stdout = StringIO.new

    original_stdin = $stdin
    original_stdout = $stdout

    begin
      $stdin = stdin
      $stdout = stdout

      transport = ::MCP::Server::Transports::StdioTransport.new(@server.server)
      transport.open
    rescue EOFError
      # Expected when stdin is exhausted
    ensure
      $stdin = original_stdin
      $stdout = original_stdout
    end

    stdout.string.split("\n").map { |line| JSON.parse(line) }
  end
end
