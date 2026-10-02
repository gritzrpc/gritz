# Contributing

Use CRuby 3.3 or later. Run `bundle install`, then `bundle exec rake`, `bundle exec rubocop` and `bundle exec rake build`. Run `COVERAGE=1 bundle exec rspec` to check line coverage. Socket-related changes must pass the real gRPC integration tests on Linux.

Write a failing behavior test before changing nontrivial logic. Keep commits focused. Public API comments use YARD's `@api public` tag. Avoid loading optional testing libraries in production.

Update CHANGELOG only for user-visible behavior. Documentation, internal tooling and tests alone do not justify a release. First release notes are exactly `Initial release.`. See [release instructions](docs/guides/releasing.md).

`gritz-core` contains routing, controllers, middleware and configuration without requiring grpc. `gritz-grpc` implements the C-core adapter. The root `gritz` package combines them and provides the executable. Keep application behavior in the core and wire-protocol details in the adapter.
