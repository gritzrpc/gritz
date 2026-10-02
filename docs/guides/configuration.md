# Configuration

Use `gritz start -C config/gritz.rb` or `gritz routes -C config/gritz.rb`.
CLI `--workers`, `--threads`, `--bind` and `--strict-routes` override matching
environment variables, which override file settings, which override defaults.
The file may require application code and call `register_controller Controller`.
Empty route tables are permitted for inspection; servers require a controller.

Each scalar setting below maps to `GRITZ_` plus its uppercase name.
Integers and decimals are parsed strictly; booleans accept `true`/`false` or
`1`/`0`; enum values use their lowercase symbol name. Unknown `GRITZ_*` names
fail startup to catch typos. `GRITZ_WORKER_RECYCLE` and `GRITZ_TLS` accept JSON
objects. Callback blocks, controller classes and middleware are configured in
Ruby rather than environment variables.

| Setting | Default | Type / constraints |
| --- | --- | --- |
| `workers` | `0` | Nonnegative integer; v0.1 server requires 0 |
| `threads` | `16` | Positive integer |
| `max_waiting_requests` | `64` | Positive integer; ignored by grpc 1.83 |
| `transport` | `:grpc_core` | `:grpc_core`, `:async`; v0.1 requires grpc_core |
| `listener_strategy` | `:reuseport` | `:reuseport`, `:inherited_fd`, `:port_per_worker`; v0.1 requires reuseport |
| `bind` | `"0.0.0.0:50051"` | host:port; port 0 allowed for single-process tests |
| `admin_bind` | `"127.0.0.1:9090"` | Reserved; no admin server in v0.1 |
| `strict_routes` | `false` | Boolean; fail boot on missing application actions |
| `fork_mode` | `:clean` | `:clean`, `:grpc_fork_support`; v0.1 requires clean |
| `fork_guard` | `:raise` | Reserved: `:raise`, `:warn`, `:off` |
| `drain_delay` | `5.0` | Reserved; nonnegative seconds |
| `shutdown_timeout` | `25.0` | Positive seconds; native RPC shutdown grace |
| `worker_boot_timeout` | `60.0` | Reserved; positive seconds |
| `worker_timeout` | `30.0` | Reserved; positive seconds |
| `status_interval` | `1.0` | Reserved; positive seconds |
| `min_ready_workers` | `1` | Reserved; positive integer |
| `phased_restart_surge` | `1` | Reserved; positive integer |
| `max_connection_age` | `300.0` | Nonnegative seconds |
| `max_connection_age_grace` | `30.0` | Nonnegative seconds |
| `keepalive_time` | `60.0` | Nonnegative seconds |
| `keepalive_permit_without_calls` | `true` | Boolean |
| `max_receive_message_size` | `4194304` | Positive bytes |
| `max_send_message_size` | `4194304` | Positive bytes |
| `max_metadata_size` | `8192` | Positive bytes |
| `metrics_backend` | `:pipe` | Reserved: `:pipe`, `:otlp`, `:mmap`; v0.1 rejects otlp/mmap |
| `log_format` | `:json` | `:json`, `:logfmt`; v0.1 requires json |
| `worker_recycle` | `{}` | Reserved; v0.1 rejects nonempty rules |
| `tls` | `{}` | Reserved; v0.1 rejects native TLS |

Integers must fit a signed 32-bit native channel argument. Durations must be
finite, real and no larger than 2,147,483.647 seconds. Addresses support
bracketed IPv6. Multi-worker reuseport with port 0 and grpc_core with inherited
FDs are invalid combinations, even during route inspection.

`worker_recycle` accepts positive `max_requests`, `max_rss_mb`, `max_pss_mb` and
`max_lifetime`, plus `jitter` between 0 and 1. `max_requests` is an integer.
`tls` accepts readable `cert`, `key` and optional `client_ca` paths. These rules
are validated now, but activating them requires a later release.

```ruby
preload_app! { require_relative "../app/rpc" }
before_fork { |index| disconnect_database(index) } # Reserved until supervisor support.
on_worker_boot { |index| setup_worker(index) }
on_worker_shutdown { |index| cleanup_worker(index) }

middleware do |stack|
  stack.insert_after Gritz::Middleware::Logging, Authentication
end
```

Preload callbacks run before routing. Single-process worker hooks receive index
0. `health_check(:database) { ... }` is parsed but rejected for server startup
until the health service exists. Config inspection does not run worker hooks.
`Testing::Server` applies the same feature validation and lifecycle as the CLI.
