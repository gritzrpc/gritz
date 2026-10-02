# Releasing

The tag-triggered `.github/workflows/release.yml` follows [canopus's release workflow](https://github.com/noxdea/canopus/blob/main/.github/workflows/release.yml): pinned actions, a `release` environment, OIDC credentials, tests/builds, and a GitHub Release containing only the matching CHANGELOG entry.

## First release: user setup required

No release tag is pushed until trusted publishing is configured. On RubyGems, create a [pending trusted publisher](https://rubygems.org/profile/oidc/pending_trusted_publishers) for each of `gritz-core`, `gritz-grpc` and `gritz`, with these identical settings:

| Field | Value |
| --- | --- |
| Repository owner | `ydah` |
| Repository name | `gritz` |
| Workflow filename | `release.yml` |
| Environment | `release` |

Leave reusable-workflow repository fields empty. No API key is needed. See the [RubyGems trusted publishing guide](https://guides.rubygems.org/trusted-publishing/).

After the user confirms configuration, verify main's CI is green, then run:

```sh
git tag v0.1.0
git push origin v0.1.0
```

This publishes real controller and server functionality, rather than placeholder packages. The initial CHANGELOG section and GitHub Release body contain only `Initial release.`.

## Subsequent releases

1. Update all three version files together: `lib/gritz/version.rb`, `gems/gritz-core/lib/gritz/core/version.rb` and `gems/gritz-grpc/lib/gritz/grpc/version.rb`.
2. Record only user-visible changes in CHANGELOG. Keep documentation and internal tooling out of release notes. Do not tag a release containing only documentation, tests, version bumps or tooling changes.
3. Run tests, lint, dependency audit and `bundle exec rake build`, commit and push main, and wait for CI.
4. Push the matching `vX.Y.Z` tag. The workflow validates versions and runtime/dependency changes, publishes `gritz-core`, then `gritz-grpc`, then `gritz`, and creates the GitHub Release from CHANGELOG.

`rake release` is restricted to the tag-triggered workflow and receives short-lived credentials from `rubygems/release-gem`. It does not create commits or tags. If a publish step fails after a component is published, inspect RubyGems before rerunning; published versions cannot be overwritten.
