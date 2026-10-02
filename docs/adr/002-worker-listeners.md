# ADR-002: Worker listener strategy remains unapproved

- Status: Proposed
- Date: 2026-10-02
- Related work: S-01, S-02, T2-01, T3-01

The proposed C-core cluster creates a fixed-port reuseport listener independently
in each child, preserving clean master. [S-01](../spikes/S-01.md) demonstrates
successful binding and connection distribution for grpc 1.83.0.

The production choice is not accepted. Four-worker scaling was measured only
on two CPUs, so the ≥3.4× four-core gate remains untested. More importantly,
[S-02](../spikes/S-02.md) observed six CANCELLED and one UNAVAILABLE error even
with `tcp_migrate_req=1`, replacement ready before drain, and retries disabled.
That tested configuration fails the zero-error condition.

Keep multi-process reuseport unavailable in the initial release. Before selecting
a listener strategy, run the prescribed dedicated scaling and 60-second load
tests, isolate shutdown cancellation and listener queue resets, and fix the
measured failure. If the gates still fail, use worker-specific ports behind a
proxy and revise the cluster architecture. Do not substitute client retries for
the acceptance measurement.

Inherited listener descriptors remain a candidate for a future Async adapter;
the Ruby C-core binding does not provide that adapter interface. No proxy,
FD transfer mechanism or production supervisor is introduced by this ADR.
