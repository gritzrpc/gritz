# ADR-003: Keep application dispatch independent of transport

- Status: Accepted
- Date: 2026-10-02
- Related work: T1-04, T1-07, T1-09, T6-01

Controllers and middleware should express RPC behavior without depending on
grpc view classes or native channel lifecycle. Test code also needs to invoke
the same application path without opening a socket.

Use a transport-independent Call contract, method descriptors and dispatcher.
The C-core adapter translates the four grpc handler signatures into that
contract and owns wire status and trailer conversion. An in-memory call uses
the same dispatcher for controller checks.

Keep C-core in its own adapter gem. Add another adapter only when its
interoperability and transport contract pass. [S-06](../spikes/S-06.md) is still
pending; this architectural boundary does not imply an implemented Async adapter.

Direct grpc-specific controller APIs are rejected because they would couple
application behavior to C-core views and make network-free tests diverge from
real dispatch. The boundary adds only the call translation required by the
actual C-core and in-memory implementations.
