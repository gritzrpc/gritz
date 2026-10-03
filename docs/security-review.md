# Security review

Review date: 2026-10-03. This records the implemented defaults and tested boundaries for the 0.9 stabilization series.

| Boundary | Default and review result |
| --- | --- |
| RPC listener | `0.0.0.0:50051`; plaintext until `tls` is configured. Native supports TLS and required client-certificate validation through `client_ca`. |
| Admin HTTP | `127.0.0.1:9090`; read-only probes, metrics and status without authentication or built-in TLS. Keep it on loopback or protect it with network/proxy access controls. |
| Reflection | Disabled in core and production. Rails development enables Native Reflection unless explicitly overridden; Async rejects Reflection configuration. |
| Message / metadata limits | 4MiB per inbound/outbound message and 8KiB metadata; both adapters test bounded wire handling. |
| Internal RPC errors | Redacted message with an error ID by default. Explicit mappings, `expose_errors` or remote-error passthrough can expose application messages. |
| Logs | Completion records omit RPC payloads; diagnostic error records include message/class/backtrace. Field-name redaction does not sanitize arbitrary secrets embedded in free text. Restrict log access. |
| Traces | Payloads, credentials and exception messages are omitted. Secure collector endpoints and credentials separately. |
| Fork safety | `fork_guard :raise`; transport resources initialize in workers. Disabling the guard does not make inherited C-core state safe. |

Applications implement authentication and authorization in controllers or middleware. Native `context.peer_identity` returns the verified client's PEM certificate; applications must parse and authorize certificate identity claims. TLS certificate, private-key and optional client-CA paths must name readable regular files before transport allocation. Symlinks to regular files remain supported for rotated secrets; directory and FIFO rejection has a regression test. Transport startup validates certificate content.

Async remains experimental and supports plaintext HTTP/2 only. Use a trusted network or TLS-terminating gRPC proxy; it does not claim Native TLS/mTLS, Health, Reflection or connection-age controls. Its [restart limitation](https://github.com/gritzrpc/gritz-async/blob/main/docs/adr/phased-restart-limit.md) is preserved.

All repositories run bundler-audit with the current advisory database in main CI. Release workflows verify source/tag versions and user-facing changes, strict-build and test packages, then publish with RubyGems Trusted Publishing and provenance attestations. The self-hosted performance runner has no host Docker socket or host workspace mount, uses read-only repository permissions, and measures only an arranged idle environment.

This review found and fixed acceptance of directory/FIFO TLS paths before startup. Tests cover valid files and symlinks alongside rejected nonregular paths. The current dependency audit and supported-Ruby CI are required again for the stabilization release. No unresolved critical security defect was identified in this review; this is a bounded source/dependency review, not a claim of external penetration testing.
