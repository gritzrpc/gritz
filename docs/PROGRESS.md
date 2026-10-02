# Implementation progress

The original design, roadmap and work procedure are retained in this directory.
This file records implementation evidence; the roadmap's dates and goals are
plans, not claims of completed validation.

## Initial release boundary

The first release candidate is **0.1.0**, with usable single-process gRPC
functionality. Publication pauses before the tag is created or pushed because
the user must configure RubyGems Trusted Publishing first. No placeholder gem
is published. The initial CHANGELOG and GitHub Release body are `Initial release.`.

| Tasks | State |
| --- | --- |
| T0-01 | Core and grpc component gems plus root metagem; [ADR-007](adr/007-packaging.md) records the retained root layout |
| T1-01 | Typed configuration/DSL, CLI/environment/file precedence, reserved process settings, validation |
| T1-02 | All 17 status classes, `fail!`, native rich protobuf error trailers |
| T1-03 | Fiber storage with restoration and inherited thread/fiber context |
| T1-04 | Call contract and network-free InMemoryCall for all four forms |
| T1-05 | Generated service descriptors, duplicate binding and missing action checks |
| T1-06 | Fresh controllers, inherited before/around/after filters and rescue handlers |
| T1-07 | Dispatcher and mutable middleware stack operations |
| T1-08 | Request IDs, scoped Context, JSON completion logs, secure exception mapping |
| T1-09 | Actual C-core unary/client/server/bidi RPCs, incremental streaming, rich trailers, bounded graceful stop |
| T1-10 | RSpec and Minitest network-free helpers; real-server lifecycle helper |
| T1-11 | `start` with workers 0, `routes`, help/version, TERM/INT/QUIT, pipe-visible startup logs |
| T1-12 | Four-form generated hello example and README quickstart |

Tests include real sockets, metadata and errors, active cancellation, saturation,
unstarted listener cleanup, shutdown deadlines, malformed responses, lifecycle
hooks, context isolation and package/release policies. CI tests Ruby 3.3, 3.4
and 4.0 on Linux, lint, dependency audit and strict package builds. All 70 tests
passed locally on macOS/Ruby 4.0.6 and Linux/Ruby 3.4.11, with 94.61% line
coverage. grpcurl 1.9.4 called all four sample RPC forms successfully on Linux.
Lint, actionlint, dependency audit and three strict package builds passed.
See CI for the committed revision's
final result. A third-party five-minute quickstart check has not been performed.

## Phase 0 findings and pending gates

See [spike evidence](spikes/README.md). Clean-fork startup and four-worker
connection distribution work. A two-core VM showed 2.00x CPU throughput with
two workers, but cannot measure the required four-core scaling gate.

The tested reuseport replacement-first configuration with `tcp_migrate_req=1`
still returned seven RPC errors. This fails that smoke test's zero-error gate.
ADR 002 stays Proposed. Before Phase 2, repeat the prescribed longer ghz
experiment, isolate native shutdown behavior and assess the roadmap's
port-per-worker/proxy alternative if the gate still fails.

Native allocation occurs before a C class's `initialize`, so ForkGuard must
intercept class `new` before allocation. The original initialize-only design
was disproved and the correction is recorded in ADR 001.

Async interop, Rails PSS, full Reflection wire behavior, long-run experimental
fork-support stress, trademark clearance and dedicated hardware benchmarks
remain pending. Phase 0 is not marked complete.

## After the user's first release

Phase 2–7 have not been implemented or certified. Continue with the Phase 0
multi-process gate and then T2-01 through T2-12; do not claim production
zero-error restart or performance guarantees from v0.1.

Known native constraints are documented: grpc 1.83 ignores
`max_waiting_requests`, and server-view cancellation can be delayed. ActiveRecord
errors map to safe statuses; Rails-specific protobuf `BadRequest` details are
reserved for the later Rails integration. The initial server has no native TLS,
health/reflection service, admin server, metrics backend, fork-safe outbound
client, Rails integration or Async transport.
