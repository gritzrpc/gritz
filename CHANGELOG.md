# Changelog

## 0.3.0

- Add phased worker replacement, hot application reload, worker recycling and stable admin probes with Prometheus metrics.
- Support native TLS, mTLS and gRPC Health Check/Watch.
- Add structured RPC logs with credential redaction and preserve accepted calls during graceful shutdown.

## 0.2.0

- Support Linux forked workers, automatic replacement, graceful shutdown and dynamic worker counts.
- Add `gritz check` to report unsafe master-side gRPC initialization.

## 0.1.0

Initial release.
