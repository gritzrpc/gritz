# Releasing

Pushing a `vX.Y.Z` tag triggers `.github/workflows/release.yml`. It tests and builds the packages, publishes `gritz-core`, `gritz-grpc` and `gritz` in that order, and creates a GitHub Release from the matching CHANGELOG entry.

## Trusted Publishing

Before publishing a new gem, create a [pending trusted publisher](https://rubygems.org/profile/oidc/pending_trusted_publishers) on RubyGems for each of `gritz-core`, `gritz-grpc` and `gritz`, using these settings:

| Field | Value |
| --- | --- |
| Repository owner | `ydah` |
| Repository name | `gritz` |
| Workflow filename | `release.yml` |
| Environment | `release` |

Leave reusable-workflow repository fields empty. No API key is needed. See the [RubyGems trusted publishing guide](https://guides.rubygems.org/trusted-publishing/).

## Publish a version

1. Update all three version files together: `lib/gritz/version.rb`, `gems/gritz-core/lib/gritz/core/version.rb` and `gems/gritz-grpc/lib/gritz/grpc/version.rb`.
2. Record only user-visible changes in CHANGELOG. Use `Initial release.` for the first release. Do not tag a release containing only documentation, tests, version bumps or tooling changes.
3. Run tests, lint, dependency audit and `bundle exec rake build`, commit and push main, and wait for CI.
4. With Trusted Publishing configured and main's CI passing, push the matching tag:

```sh
git tag v0.1.0
git push origin v0.1.0
```

Replace `0.1.0` with the release version. The workflow validates package versions and checks for runtime or dependency changes before publishing.

`rake release` is restricted to the tag-triggered workflow and receives short-lived credentials from `rubygems/release-gem`. It does not create commits or tags. If a publish step fails after a component is published, inspect RubyGems before rerunning; published versions cannot be overwritten.
