# Gritz

Gritz is a Ruby gRPC application framework with controllers, middleware and network-free controller tests. It supports a single-process native server, Linux forked-worker supervision, and all four RPC forms: unary, server streaming, client streaming and bidirectional streaming.

Requires CRuby 3.3 or later and grpc 1.83 or later. Linux and macOS are tested.

## Packages

| Gem | Repository | Role |
| --- | --- | --- |
| `gritz` | [gritzrpc/gritz](https://github.com/gritzrpc/gritz) | Default combination and executable |
| `gritz-core` | [gritzrpc/gritz-core](https://github.com/gritzrpc/gritz-core) | Transport-independent application framework |
| `gritz-native` | [gritzrpc/gritz-native](https://github.com/gritzrpc/gritz-native) | Official grpc gem adapter and thread pool |
| `gritz-rails` | [gritzrpc/gritz-rails](https://github.com/gritzrpc/gritz-rails) | Optional Rails execution, generators and development reloading |
| `gritz-otel` | [gritzrpc/gritz-otel](https://github.com/gritzrpc/gritz-otel) | Optional server/client tracing and worker OTLP metrics |

Applications can add `gem "gritz", "~> 0.6.0"` to their Gemfile. It installs both the core and native adapter. Add `gritz-otel` for OpenTelemetry. Add `gritz-rails` for Rails execution, generators and development reloading. The experimental Fiber adapter [gritz-async](https://github.com/gritzrpc/gritz-async) runs without the official `grpc` gem; use it with `gritz-core` instead of this meta gem.

## Quickstart from source

```bash
git clone https://github.com/gritzrpc/gritz.git
cd gritz
bundle install
bundle exec ruby exe/gritz routes -C examples/hello/config/gritz.rb
bundle exec ruby exe/gritz start -C examples/hello/config/gritz.rb
```

In another terminal, run `bundle exec ruby examples/hello/client.rb`. It calls all four RPC forms. To use grpcurl, supply the bundled proto:

```bash
grpcurl -plaintext -import-path examples/hello/proto -proto hello.proto \
  -d '{"name":"Ruby"}' localhost:50051 helloworld.Greeter/SayHello
```

## Controllers

```ruby
class GreeterController < Gritz::Controller
  bind Helloworld::Greeter::Service

  def say_hello
    fail!(:invalid_argument, "name is required") if request.message.name.empty?
    Helloworld::HelloReply.new(message: "Hello, #{request.message.name}!")
  end

  def chat
    request.each_message do |message|
      stream.write(Helloworld::HelloReply.new(message: message.name.upcase))
    end
  end
end
```

Register controllers in a configuration file:

```ruby
require_relative "../app/greeter_controller"

workers 0 # Use workers 4 with a fixed bind port for Linux multiprocess serving.
threads 16
bind "127.0.0.1:50051"
register_controller GreeterController
```

Set `strict_routes true` once every RPC in the bound service has an action; otherwise missing actions return `UNIMPLEMENTED`.

`before_action`, `around_action`, `after_action` and `rescue_from` support inheritance. Each RPC gets its own controller instance. `Gritz::Context.current` carries metadata, deadline, peer, request ID and a per-request store; child fibers and threads inherit it. Requests exceeding their deadline are rejected cooperatively at request reads and response writes. `context.check_deadline!` can also be called during application work.

The default middleware adds request IDs, scopes context, writes JSON completion logs and converts exceptions to gRPC errors. Internal errors expose an `error-id` trailer rather than application exception messages. `fail!` accepts status symbols, trailing metadata and protobuf rich error details. Middleware wraps the full stream, including incremental response writes.

## Clients

For downstream calls, define a lazy client with `Gritz::Client.define(Helloworld::Greeter::Stub, target: "localhost:50051", deadline: 2.0)`. It shares a channel within each worker, inherits the parent deadline and selected request headers, and wraps complete streams in client middleware. See the [client guide](https://github.com/gritzrpc/gritz-core/blob/main/docs/guides/clients.md).

## Rails and Gruf migration

Add [gritz-rails](https://github.com/gritzrpc/gritz-rails), run `bin/rails generate gritz:install`, and use `bin/gritz` to start RPCs with Rails execution and development reloading. See its [Rails sample](https://github.com/gritzrpc/gritz-rails/tree/main/examples/rails_app). Existing Gruf controllers can use the optional compatibility module in core; follow the [migration guide](https://github.com/gritzrpc/gritz-core/blob/main/docs/guides/migrating-from-gruf.md).

## Testing

```ruby
require "gritz/testing/rspec"

RSpec.describe GreeterController, type: :rpc do
  it "greets a user" do
    reply = rpc(:say_hello, Helloworld::HelloRequest.new(name: "Ruby"))
    expect(reply.message).to eq("Hello, Ruby!")
  end

  it "validates names" do
    expect { rpc(:say_hello, Helloworld::HelloRequest.new) }
      .to raise_rpc_error(:invalid_argument)
  end
end
```

Minitest tests can include `Gritz::Testing::Minitest` after requiring `gritz/testing/minitest`; pass `controller:` to `rpc` and use `assert_rpc_error`. `Gritz::Testing::Server.start(controllers: [GreeterController]) { |server| ... }` starts a real server on an ephemeral port and stops it when the block exits.

## Configuration and limitations

Configuration precedence is CLI options, `GRITZ_*` environment variables, configuration file, then defaults. See the [configuration guide](docs/guides/configuration.md) for settings and lifecycle hooks.

Use `TERM` or `INT` to finish in-flight calls within `shutdown_timeout`; `QUIT` closes immediately. Application code should check deadlines and cancellation during long work. The grpc 1.83 server view can report cancellation late; deadlines remain the practical limit for long handlers. The native thread pool rejects excess requests immediately with `RESOURCE_EXHAUSTED`; grpc 1.83 ignores its deprecated `max_waiting_requests` setting.

Configure `tls cert:, key:` for TLS and add `client_ca:` for required client certificates. Native gRPC Health Check/Watch follows named `health_check` callbacks and worker draining. Admin HTTP provides `/livez`, `/readyz`, `/status` and Prometheus `/metrics` at `127.0.0.1:9090` by default. Set `reflection true` to enable standard gRPC Reflection v1/v1alpha; it is disabled by default.

For Linux operations, use `USR1` to replace workers one at a time and `USR2` to load fresh Ruby code/configuration in a new master. The CLI launcher retains probes and metric totals while old masters drain; a failed replacement leaves the active master serving. Configure `worker_recycle` to replace workers by requests, PSS/RSS or lifetime. See the [Kubernetes guide](https://github.com/gritzrpc/gritz-native/blob/main/docs/guides/kubernetes.md).

The default transport is `:native` (`Gritz::Transport::Native`). `gritz-core` can be loaded separately with `require "gritz/core"` without loading grpc.

## Development

Each repository has its own tests, CI and package build. Development dependencies come from their Git repositories; sibling checkouts are optional. See [CONTRIBUTING.md](CONTRIBUTING.md) to work on local components.

Run `bundle exec rake`, `COVERAGE=1 bundle exec rspec`, `bundle exec rubocop` and `bundle exec rake build`. The [Linux devcontainer](.devcontainer/devcontainer.json) includes grpcurl and ghz. See the [release guide](docs/guides/releasing.md) for publishing packages.

## Contributing

Bug reports and pull requests are welcome on [GitHub](https://github.com/gritzrpc/gritz). See [CONTRIBUTING.md](CONTRIBUTING.md) and [SECURITY.md](SECURITY.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
