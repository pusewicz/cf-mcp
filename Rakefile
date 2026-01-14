# frozen_string_literal: true

require "bundler/gem_tasks"
require "minitest/test_task"

Minitest::TestTask.create

require "standard/rake"

desc "Generate Manifest.txt from git ls-files"
task :manifest do
  ignore_patterns = %w[bin/ Gemfile .gitignore test/ .github/ .standard.yml cf-mcp.gemspec .ruby-version CLAUDE.md fly.toml Procfile Dockerfile .dockerignore]

  files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true)
  end.reject { |f| f.start_with?(*ignore_patterns) }.sort

  # Add Manifest.txt itself so it's included in the gem
  files << "Manifest.txt" unless files.include?("Manifest.txt")
  files.sort!

  File.write("Manifest.txt", files.join("\n") + "\n")
  puts "Generated Manifest.txt with #{files.size} files"
end

task default: %i[test standard]

desc "Deploy to Fly.io (runs tests and linting first)"
task deploy: %i[test standard] do
  sh "fly deploy"
end
