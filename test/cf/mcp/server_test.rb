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
      CF::MCP::Tools::GetDetails,
      CF::MCP::Tools::FindRelated,
      CF::MCP::Tools::ParameterSearch,
      CF::MCP::Tools::MemberSearch,
      CF::MCP::Tools::ListTopics,
      CF::MCP::Tools::GetTopic
    ]

    assert_equal expected_tools, CF::MCP::Server::TOOLS
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
    assert_equal 11, tools.size

    tool_names = tools.map { |t| t["name"] }
    assert_includes tool_names, "cf_search"
    assert_includes tool_names, "cf_search_functions"
    assert_includes tool_names, "cf_search_structs"
    assert_includes tool_names, "cf_search_enums"
    assert_includes tool_names, "cf_list_category"
    assert_includes tool_names, "cf_get_details"
    assert_includes tool_names, "cf_list_topics"
    assert_includes tool_names, "cf_get_topic"
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

# HTTP server tests (CORS, routing, landing page)
class CF::MCP::HTTPServerTest < Minitest::Test
  def setup
    @index = CF::MCP::Index.new
    @index.add(CF::MCP::Models::FunctionDoc.new(
      name: "cf_make_sprite",
      category: "sprite",
      brief: "Loads a sprite from an aseprite file.",
      signature: "CF_Sprite cf_make_sprite(const char* path)"
    ))

    @http_server = CF::MCP::HTTPServer.new(@index)
    @app = @http_server.rack_app
  end

  # CORS Tests

  def test_cors_headers_on_mcp_response
    response = make_mcp_request("/http", "initialize", {
      protocolVersion: "2024-11-05",
      capabilities: {},
      clientInfo: {name: "test", version: "1.0"}
    })

    assert_equal 200, response.status
    assert_cors_headers(response)
  end

  def test_cors_preflight_options_request
    env = Rack::MockRequest.env_for("/", method: "OPTIONS")
    response = Rack::MockResponse.new(*@app.call(env))

    assert_equal 204, response.status
    assert_cors_headers(response)
  end

  def test_cors_preflight_on_well_known_path
    env = Rack::MockRequest.env_for(
      "/.well-known/oauth-protected-resource",
      method: "OPTIONS"
    )
    response = Rack::MockResponse.new(*@app.call(env))

    assert_equal 204, response.status
    assert_cors_headers(response)
  end

  def test_cors_preflight_on_http_path
    env = Rack::MockRequest.env_for("/http", method: "OPTIONS")
    response = Rack::MockResponse.new(*@app.call(env))

    assert_equal 204, response.status
    assert_cors_headers(response)
  end

  # OAuth Discovery Tests

  def test_well_known_oauth_protected_resource_returns_404
    env = Rack::MockRequest.env_for("/.well-known/oauth-protected-resource")
    response = Rack::MockResponse.new(*@app.call(env))

    assert_equal 404, response.status
    assert_equal "application/json", response.headers["content-type"]
    assert_cors_headers(response)

    body = JSON.parse(response.body)
    assert_equal "Not found", body["error"]
  end

  def test_well_known_openid_configuration_returns_404
    env = Rack::MockRequest.env_for("/.well-known/openid-configuration")
    response = Rack::MockResponse.new(*@app.call(env))

    assert_equal 404, response.status
    assert_cors_headers(response)
  end

  # Landing Page Tests

  def test_landing_page_for_browser_request
    env = Rack::MockRequest.env_for("/", method: "GET")
    env["HTTP_ACCEPT"] = "text/html,application/xhtml+xml"
    response = Rack::MockResponse.new(*@app.call(env))

    assert_equal 200, response.status
    assert_equal "text/html; charset=utf-8", response.headers["content-type"]
    assert_includes response.body, "<title>CF::MCP"
    assert_includes response.body, "Cute Framework"
    assert_cors_headers(response)
  end

  def test_landing_page_shows_stats
    env = Rack::MockRequest.env_for("/", method: "GET")
    env["HTTP_ACCEPT"] = "text/html"
    response = Rack::MockResponse.new(*@app.call(env))

    # Should show the index stats
    assert_includes response.body, "Total Items"
    assert_includes response.body, "Functions"
    assert_includes response.body, "Structs"
    assert_includes response.body, "Enums"
  end

  def test_landing_page_shows_tools_dynamically
    env = Rack::MockRequest.env_for("/", method: "GET")
    env["HTTP_ACCEPT"] = "text/html"
    response = Rack::MockResponse.new(*@app.call(env))

    # Should show all configured tools
    CF::MCP::Server::TOOLS.each do |tool|
      assert_includes response.body, tool.tool_name
    end
  end

  def test_landing_page_shows_endpoints
    env = Rack::MockRequest.env_for("/", method: "GET")
    env["HTTP_ACCEPT"] = "text/html"
    response = Rack::MockResponse.new(*@app.call(env))

    assert_includes response.body, "/http"
  end

  def test_landing_page_shows_version
    env = Rack::MockRequest.env_for("/", method: "GET")
    env["HTTP_ACCEPT"] = "text/html"
    response = Rack::MockResponse.new(*@app.call(env))

    assert_includes response.body, CF::MCP::VERSION
  end

  def test_landing_page_shows_claude_code_cli_command
    env = Rack::MockRequest.env_for("/", method: "GET")
    env["HTTP_ACCEPT"] = "text/html"
    response = Rack::MockResponse.new(*@app.call(env))

    assert_includes response.body, "claude mcp add"
    assert_includes response.body, "--transport http"
    assert_includes response.body, "/http"
  end

  def test_landing_page_shows_claude_desktop_setup
    env = Rack::MockRequest.env_for("/", method: "GET")
    env["HTTP_ACCEPT"] = "text/html"
    response = Rack::MockResponse.new(*@app.call(env))

    assert_includes response.body, "Claude Desktop"
    assert_includes response.body, "Settings"
    assert_includes response.body, "Connectors"
  end

  # Routing Tests

  def test_root_path_redirects_to_http_for_mcp_client
    env = Rack::MockRequest.env_for("/", method: "POST")
    env["CONTENT_TYPE"] = "application/json"
    env["HTTP_ACCEPT"] = "application/json"
    response = Rack::MockResponse.new(*@app.call(env))

    assert_equal 301, response.status
    assert_equal "/http", response.headers["location"]
  end

  def test_http_path_routes_to_http_transport
    response = make_mcp_request("/http", "initialize", {
      protocolVersion: "2024-11-05",
      capabilities: {},
      clientInfo: {name: "test", version: "1.0"}
    })

    assert_equal 200, response.status
    body = JSON.parse(response.body)
    assert_equal "cf-mcp", body["result"]["serverInfo"]["name"]
  end

  def test_tools_call_via_http_server
    response = make_mcp_request("/http", "tools/call", {
      name: "cf_search",
      arguments: {query: "sprite"}
    })

    assert_equal 200, response.status
    body = JSON.parse(response.body)
    refute body["result"]["isError"]
    assert_includes body["result"]["content"].first["text"], "cf_make_sprite"
  end

  def test_http_path_with_trailing_slash
    response = make_mcp_request("/http/", "initialize", {
      protocolVersion: "2024-11-05",
      capabilities: {},
      clientInfo: {name: "test", version: "1.0"}
    })

    assert_equal 200, response.status
    body = JSON.parse(response.body)
    assert_equal "cf-mcp", body["result"]["serverInfo"]["name"]
  end

  def test_http_transport_tools_list
    response = make_mcp_request("/http", "tools/list", {})

    assert_equal 200, response.status
    body = JSON.parse(response.body)
    tools = body["result"]["tools"]
    assert_equal 11, tools.size
  end

  def test_get_without_html_accept_redirects_to_http
    env = Rack::MockRequest.env_for("/", method: "GET")
    env["HTTP_ACCEPT"] = "application/json"
    response = Rack::MockResponse.new(*@app.call(env))

    # Should redirect to /http
    assert_equal 301, response.status
    assert_equal "/http", response.headers["location"]
  end

  def test_cors_headers_on_landing_page
    env = Rack::MockRequest.env_for("/", method: "GET")
    env["HTTP_ACCEPT"] = "text/html"
    response = Rack::MockResponse.new(*@app.call(env))

    assert_equal 200, response.status
    assert_cors_headers(response)
  end

  def test_http_transport_is_stateless
    response = make_mcp_request("/http", "initialize", {
      protocolVersion: "2024-11-05",
      capabilities: {},
      clientInfo: {name: "test", version: "1.0"}
    })

    assert_equal 200, response.status
    refute response.headers["mcp-session-id"], "Stateless transport should not return session ID"
  end

  private

  def make_mcp_request(path, method, params, id: 1)
    body = JSON.generate({
      jsonrpc: "2.0",
      id: id,
      method: method,
      params: params
    })

    env = Rack::MockRequest.env_for(
      path,
      method: "POST",
      input: body
    )
    env["CONTENT_TYPE"] = "application/json"
    env["HTTP_ACCEPT"] = "application/json, text/event-stream"

    Rack::MockResponse.new(*@app.call(env))
  end

  def assert_cors_headers(response)
    assert_equal "*", response.headers["access-control-allow-origin"],
      "Expected access-control-allow-origin header"
    assert_equal "GET, POST, DELETE, OPTIONS", response.headers["access-control-allow-methods"],
      "Expected access-control-allow-methods header"
    assert_includes response.headers["access-control-allow-headers"], "Content-Type",
      "Expected Content-Type in access-control-allow-headers"
    assert_includes response.headers["access-control-allow-headers"], "Mcp-Session-Id",
      "Expected Mcp-Session-Id in access-control-allow-headers"
    assert_equal "Mcp-Session-Id", response.headers["access-control-expose-headers"],
      "Expected access-control-expose-headers header"
  end
end
