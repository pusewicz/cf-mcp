# frozen_string_literal: true

require_relative "lib/cf/mcp/version"

Gem::Specification.new do |spec|
  spec.name = "cf-mcp"
  spec.version = CF::MCP::VERSION
  spec.authors = ["Piotr Usewicz"]
  spec.email = ["piotr@layer22.com"]

  spec.summary = "MCP server providing documentation tools for Cute Framework"
  spec.description = "An MCP server that indexes Cute Framework header files and provides search functionality for structs, functions, enums, and other elements."
  spec.homepage = "https://github.com/pusewicz/cf-mcp"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/pusewicz/cf-mcp"

  # Specify which files should be added to the gem when it is released.
  # Run `rake manifest` to regenerate Manifest.txt after adding/removing files.
  spec.files = File.read(File.join(__dir__, "Manifest.txt")).split("\n")
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "mcp", "~> 0.5"
  spec.add_dependency "puma", "~> 6.0"
  spec.add_dependency "rack", "~> 3.0"
  spec.add_dependency "rackup", "~> 2.0"
  spec.add_dependency "rubyzip", "~> 2.3"
end
