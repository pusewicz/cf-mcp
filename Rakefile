# frozen_string_literal: true

require "bundler/gem_tasks"
require "minitest/test_task"
require "standard/rake"

Minitest::TestTask.create

desc "Generate Manifest.txt from git ls-files"
task :manifest do
  ignore_patterns = %w[bin/ Gemfile .gitignore test/ .github/ .standard.yml cf-mcp.gemspec .ruby-version CLAUDE.md fly.toml Procfile Dockerfile .dockerignore .claude/]

  files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true)
  end.reject { |f| f.start_with?(*ignore_patterns) }.sort

  # Add Manifest.txt itself so it's included in the gem
  files << "Manifest.txt" unless files.include?("Manifest.txt")
  files.sort!

  File.write("Manifest.txt", files.join("\n") + "\n")
  puts "Generated Manifest.txt with #{files.size} files"
end

desc "Validate RBS type signatures"
task :rbs do
  sh "rbs", "-I", "sig", "validate"
end

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
