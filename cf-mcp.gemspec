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
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ Gemfile .gitignore test/ .github/ .standard.yml])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "mcp", "~> 0.5"
  spec.add_dependency "rack", "~> 3.0"
  spec.add_dependency "rackup", "~> 2.0"
end
