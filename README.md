# Gritz

Gritz is a Ruby gRPC application framework with controllers, middleware and network-free controller tests. It supports a single-process C-core server and all four RPC forms: unary, server streaming, client streaming and bidirectional streaming.

Requires CRuby 3.3 or later and grpc 1.83 or later. Linux and macOS are tested.

## Quickstart from source

```bash
git clone https://github.com/ydah/gritz.git
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

workers 0
threads 16
bind "127.0.0.1:50051"
register_controller GreeterController
```

Set `strict_routes true` once every RPC in the bound service has an action; otherwise missing actions return `UNIMPLEMENTED`.

`before_action`, `around_action`, `after_action` and `rescue_from` support inheritance. Each RPC gets its own controller instance. `Gritz::Context.current` carries metadata, deadline, peer, request ID and a per-request store; child fibers and threads inherit it. Requests exceeding their deadline are rejected cooperatively at request reads and response writes. `context.check_deadline!` can also be called during application work.

The default middleware adds request IDs, scopes context, writes JSON completion logs and converts exceptions to gRPC errors. Internal errors expose an `error-id` trailer rather than application exception messages. `fail!` accepts status symbols, trailing metadata and protobuf rich error details. Middleware wraps the full stream, including incremental response writes.

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

The server binds insecure gRPC sockets. Use a trusted network or a TLS-terminating proxy. Native TLS, health checks, reflection, metrics export and multi-process supervision are unavailable. Unsupported transport, worker and TLS features fail at startup.

The packages are `gritz-core` (no grpc dependency), `gritz-grpc` (C-core adapter) and `gritz` (the default combination and executable).

## Development

Run `bundle exec rake`, `COVERAGE=1 bundle exec rspec`, `bundle exec rubocop` and `bundle exec rake build`. The [Linux devcontainer](.devcontainer/devcontainer.json) includes grpcurl and ghz. See the [release guide](docs/guides/releasing.md) for publishing packages.

## Contributing

Bug reports and pull requests are welcome on [GitHub](https://github.com/ydah/gritz). See [CONTRIBUTING.md](CONTRIBUTING.md) and [SECURITY.md](SECURITY.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
