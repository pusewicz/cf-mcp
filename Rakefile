# frozen_string_literal: true

require "bundler/gem_tasks"
require "minitest/test_task"

Minitest::TestTask.create

require "standard/rake"

desc "Generate Manifest.txt from git ls-files"
task :manifest do
  ignore_patterns = %w[bin/ Gemfile .gitignore test/ .github/ .standard.yml cf-mcp.gemspec .ruby-version CLAUDE.md AGENTS.md fly.toml Procfile Dockerfile .dockerignore .claude/ .mcp.json .serena/ sig/ sig-stubs/ Steepfile rbs_collection.yaml rbs_collection.lock.yaml]

  files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true)
  end.reject { |f| f.start_with?(*ignore_patterns) }.sort

  # Add Manifest.txt itself so it's included in the gem
  files << "Manifest.txt" unless files.include?("Manifest.txt")
  files.sort!

  File.write("Manifest.txt", files.join("\n") + "\n")
  puts "Generated Manifest.txt with #{files.size} files"
end

namespace :rbs do
  desc "Validate RBS type signatures"
  task :validate do
    sh "rbs", "-I", "sig", "-I", "sig-stubs", "validate"
  end

  desc "Type check lib/ against the RBS signatures with Steep"
  task :steep do
    sh "steep", "check"
  end

  desc "Run the test suite under the RBS runtime type checker"
  task :test do
    env = {
      "RBS_TEST_TARGET" => "CF::MCP::*",
      "RBS_TEST_OPT" => "-I sig -I sig-stubs --collection rbs_collection.yaml",
      "RBS_TEST_DOUBLE_SUITE" => "minitest",
      "RBS_TEST_LOGLEVEL" => "warn",
      # Append rather than replace: under `bundle exec`, RUBYOPT already carries
      # -rbundler/setup, and dropping it would make the child resolve system gems.
      "RUBYOPT" => "#{ENV["RUBYOPT"]} -rrbs/test/setup".strip
    }
    sh env, "bundle", "exec", "rake", "test"
  end
end

desc "Validate signatures, type check with Steep, and run the tests under the runtime type checker"
task rbs: %w[rbs:validate rbs:steep rbs:test]

task default: %i[test standard rbs manifest]

desc "Deploy to Fly.io (runs tests and linting first)"
task deploy: %i[test standard] do
  sh "fly deploy"
end

desc "Create a git tag for the current version"
task :tag do
  require_relative "lib/cf/mcp/version"
  version = CF::MCP::VERSION
  tag = "v#{version}"

  if system("git", "rev-parse", tag, out: File::NULL, err: File::NULL)
    puts "Tag #{tag} already exists"
  else
    sh "git", "tag", "-a", tag, "-m", "Release #{version}"
    puts "Created tag #{tag}"
  end
end

desc "Create and push git tag for current version"
task "release:tag" => %i[test standard tag] do
  require_relative "lib/cf/mcp/version"
  tag = "v#{CF::MCP::VERSION}"
  sh "git", "push", "origin", tag
  puts "Pushed #{tag} to origin"
end
