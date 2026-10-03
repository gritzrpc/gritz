# Changelog

## 0.9.1

- Select Core and Native 0.9.1 for cooperative RPC cancellation, operational commands and corrected master readiness timeouts.

## 0.9.0

- Select Core and Native 0.9.0 for the stabilization series.

## 0.6.1

- Include gritz-core and gritz-native 0.6.1, avoiding work on suppressed RPC completion logs.

## 0.6.0

- Include gritz-core and gritz-native 0.6.0 with shared adapter contracts and transport selection.

## 0.5.0

- Include Gruf migration support and optional gRPC Reflection through gritz-core and gritz-native 0.5.0.

## 0.4.0

- Add fork-safe clients for all four RPC forms, with deadline and request-header propagation and client middleware.
- Preserve typed downstream errors and rich details while returning safe `INTERNAL` responses for unhandled downstream failures.
- Support native retry and load-balancing service configuration and optional OpenTelemetry integration.

## 0.3.0

- Add phased worker replacement, hot application reload, worker recycling and stable admin probes with Prometheus metrics.
- Support native TLS, mTLS and gRPC Health Check/Watch.
- Add structured RPC logs with credential redaction and preserve accepted calls during graceful shutdown.

## 0.2.0

- Support Linux forked workers, automatic replacement, graceful shutdown and dynamic worker counts.
- Add `gritz check` to report unsafe master-side gRPC initialization.

## 0.1.0

Initial release.
