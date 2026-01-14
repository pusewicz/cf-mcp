Prepare a release of the gem by running checks, ensuring version is bumped, changelog is updated, and creating a PR.

1. Run `rake test` to ensure all tests pass. If tests fail, stop and report the failures.

2. Run `rake standard` to check code style. If there are issues, run `rake standard:fix` and include the fixes.

3. Run `rake manifest` to regenerate Manifest.txt.

4. Check the current version in lib/cf/mcp/version.rb.

5. Check git log to see what changes have been made since the last release tag (use `git describe --tags --abbrev=0` to find the last tag, then `git log <tag>..HEAD --oneline`).

6. If there are meaningful changes that warrant a release:
   - If the version hasn't been bumped yet (no version bump commit since last tag), ask the user what type of version bump is needed (patch/minor/major) and bump accordingly.
   - Update CHANGELOG.md with a new entry for the current version, documenting the changes since the last release.
   - Add the comparison link at the bottom of CHANGELOG.md.

7. Run `bundle install` to update Gemfile.lock if version was changed.

8. Create a new branch named `release/vX.Y.Z` where X.Y.Z is the version number.

9. Commit all changes with message "Prepare release vX.Y.Z".

10. Push the branch and create a PR with:
    - Title: "Release vX.Y.Z"
    - Body: Include the changelog entry for this version and a checklist for release steps.
