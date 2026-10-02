# ADR-007: Component gems with the existing root metagem

- Status: Accepted
- Related tasks: T0-01, T1-01 through T1-12

Core and C-core transport are separate gems as specified by the design. The existing root `gritz.gemspec`, entry point and executable remain the metagem instead of being moved into `gems/gritz/`.

The root Gemfile references both component gems by path. All versions are identical; release builds explicitly package each component's own files, excluding plans, tests and spike code. Both components carry their own license and README.

This keeps the established root entry point while ensuring `require "gritz/core"` works without loading grpc. Zeitwerk loads the core, with errors and optional test integrations handled explicitly. The adapter requires its own files and dependencies only through `gritz/grpc`.
