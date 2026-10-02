# Contributing

Use CRuby 3.3 or later. Run `bundle install`, then `bundle exec rake` and `bundle exec rubocop`. For changes involving sockets, run real gRPC tests; for future process management changes, use Linux and retain the clean-master invariant.

Write a failing behavior test before changing nontrivial logic. Keep commits focused and include the work procedure task ID where applicable. Public API comments use YARD's `@api public` tag. Avoid loading optional testing libraries in production.

Update CHANGELOG only for user-visible behavior. Documentation, internal tooling and tests alone do not justify a release. First release notes are exactly `Initial release.`. See [release instructions](docs/guides/releasing.md).

The [design](docs/DESIGN.md), [roadmap](docs/ROADMAP.md) and [work procedure](docs/WORK_PROCEDURE.md) describe the full plan. [PROGRESS.md](docs/PROGRESS.md) records what has actually been implemented and measured.
