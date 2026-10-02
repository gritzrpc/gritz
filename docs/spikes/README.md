# Phase 0 evidence

Measured on 2026-10-02. Linux runs used Docker 29.5.2, kernel
6.8.0-117-generic, aarch64, Ruby 3.4.11, grpc 1.83.0 and protobuf 4.36.2.
The Docker VM exposes **two CPUs** and is not a dedicated benchmark runner.
macOS constructor checks used Ruby 4.0.6 and the same gem versions.

| Spike | Status | Evidence |
| --- | --- | --- |
| [S-01](S-01.md) | Partial | Clean-fork servers and independent-channel distribution work; four-core scaling gate unmeasured. |
| [S-02](S-02.md) | Failed smoke check | Replacement-first with `tcp_migrate_req=1` still produced RPC errors with retries disabled. |
| [S-03](S-03.md) | Pass for class `new` hooks | All seven constructor entry points blocked before native allocation; `initialize` hooks are unsafe. |
| [S-04](S-04.md) | Partial | Unary master call followed by child server works; active bidi correctly blocks prefork. |
| [S-05](S-05.md) | Partial | Serialized descriptors and direct `to_proto` extraction work; reflection wire server untested. |
| [S-06](S-06.md) | Pending | Async transport interoperability has not been executed. |
| [S-07](S-07.md) | Pending | Rails memory experiment has not been executed. |
| [S-08](S-08.md) | Partial | Six RubyGems names returned 404; no placeholder publication or trademark clearance. |

**The multi-process reuseport plan has not passed Phase 0.** A single-process
initial release does not establish its scaling or zero-error restart guarantees.
ADR 002 remains Proposed. Do not treat the smoke measurements as completed
production acceptance tests.

Build the Linux development environment:

```sh
docker build -t gritz-dev .devcontainer
docker run --rm -it --sysctl net.ipv4.tcp_migrate_req=1 \
  -v "$PWD:/workspace" -w /workspace gritz-dev bash
gem install grpc -v 1.83.0 --no-document
```

The committed generated spike files let probes run without regeneration.
To regenerate them with the development bundle:

```sh
bundle exec grpc_tools_ruby_protoc -I spikes/s01_reuseport/proto \
  --ruby_out=spikes/s01_reuseport/lib --grpc_out=spikes/s01_reuseport/lib \
  spikes/s01_reuseport/proto/echo.proto
```

Spike programs are isolated experiments, not production implementation.
Raw JSON measurements are in [results](results/).
