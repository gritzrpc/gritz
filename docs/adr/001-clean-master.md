# ADR-001: Keep the master free of native gRPC objects

- Status: Accepted
- Date: 2026-10-02
- Related work: S-01, S-03, S-04, T2-03

The supervisor needs to preload definitions and fork workers. gRPC native
allocation in the parent makes ordinary postfork use fail on the measured
grpc 1.83.0. Experimental fork APIs have additional lifecycle restrictions.

Load Ruby code and protobuf service definitions in the master; construct
channels, credentials and servers only after fork. [S-01](../spikes/S-01.md)
actually served requests using this sequence. The initial single-process
release does not exercise a supervisor and does not claim cluster support.

Guard normal class constructors before native allocation using singleton
`new` hooks. The original instance `initialize` proposal is rejected:
[S-03](../spikes/S-03.md) demonstrated that its native allocator has already
initialized grpc before the hook can raise. Guard installation must precede
application initialization; direct `allocate` and preexisting resources need
additional checks in the production ForkGuard.

Experimental prefork APIs may later support explicitly opted-in client-only
master activity. [S-04](../spikes/S-04.md) establishes one successful sequence,
while active bidi is rejected. They are not the default fork strategy.

This decision preserves Copy-on-Write preload without relying on experimental
server fork behavior. It requires lazy clients and worker boot hooks for
application code that normally creates native resources during initialization.
