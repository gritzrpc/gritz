# Public API and versioning

The stable 1.0 scope is `gritz`, `gritz-core`, `gritz-native`, `gritz-rails` and `gritz-otel`. `gritz-async` remains experimental: the [continuous-load restart limitation](https://github.com/gritzrpc/gritz-async/blob/main/docs/adr/phased-restart-limit.md) prevents its promotion. Experimental `fork_mode :grpc_fork_support` is also outside the stable guarantee.

The API reference includes objects tagged `@api public`. YARD inherits this tag from a containing class or module; methods do not need duplicate tags. Explicit `@api private` and Ruby-private methods are implementation details. Runtime-generated configuration accessors, configuration-file setters/hooks and canonical error classes are generated into the reference from `Configuration::DEFAULTS`, `Configuration::HOOKS` and `Errors::CODES`.

| Surface | Supported entrypoints |
| --- | --- |
| Application handlers | `Controller.bind`, filters, rescue handlers, `request`, `stream`, `context`, `fail!` |
| Calls and errors | `Call`, `Context`, `MethodDescriptor`, `Error`, `Errors.for_code` and canonical error subclasses |
| Configuration | `Configuration.load`, validated settings, DSL settings/hooks, controller and middleware registration |
| Middleware | `Middleware::Stack` and the documented middleware call contract |
| Native transport and clients | `Transport::Native`, `Client.define`, client middleware and process-local `ChannelRegistry` |
| Process operation | CLI commands, documented signals, Admin routes and `Supervisor::Master` |
| Tests | `Testing::Server`, `Testing::Cluster`, RPC helpers and shared transport contracts |
| Integrations | `Rails.install`, `rails_app`, generators, `Otel.install`, `opentelemetry` |
| Gruf migration | `Compat::Gruf::Controller`, request/error compatibility and `ServerInterceptor` |

Configuration defaults, validation, documented CLI output contracts and lifecycle behavior are part of compatibility. The API reference provides individual methods; the [configuration guide](guides/configuration.md) lists defaults and signal behavior. No deprecated public API currently requires removal.

Before 1.0, a breaking change requires a minor version increase and migration notes. After 1.0, removal or incompatible behavior in the stable public surface requires a major version; additions use a minor version and compatible fixes use a patch version. Implementation classes, private methods, benchmark JSON and experimental APIs may change without that guarantee. Dependency and supported-platform changes follow the [support policy](support-policy.md).

The [0.9 candidate inventory](public-api-baseline.txt) records public object names and method signatures for review. It also lists experimental Async references; those remain excluded from the stable guarantee above. The published site's `public-api.txt` reflects its checked-out sources.

The 0.9 series freezes this intended public surface for the [four-week stabilization gate](stabilization.md). A required breaking change restarts that gate after the revised 0.9 release. A release date does not substitute for completing the observation period.
