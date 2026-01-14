Bump the minor version number in lib/cf/mcp/version.rb (e.g., 1.2.3 -> 1.3.0).

1. Read the current version from lib/cf/mcp/version.rb
2. Parse the version string (MAJOR.MINOR.PATCH)
3. Increment MINOR by 1, reset PATCH to 0
4. Update the VERSION constant in lib/cf/mcp/version.rb
5. Run `bundle install` to update Gemfile.lock
6. Run `rake manifest` to regenerate Manifest.txt
