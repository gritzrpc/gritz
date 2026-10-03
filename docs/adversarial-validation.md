# Adversarial validation of the stabilization candidate

The audit found four gaps in 0.9.0: Native controllers could not observe client cancellation, configured readiness budgets above 60 seconds were capped, the documented operational CLI commands were missing, and three controller callback APIs were absent from the reference. Compatible patches fix these gaps: Core, Native, the meta gem, OpenTelemetry and Rails 0.9.1, plus experimental Async 0.1.5.

## Corrections and regressions

- Native now observes C-core close notifications while controllers run. All four RPC forms verify that a cooperative controller exits after client cancellation and another call can use the serving slot. Six additional tests cover concurrent observer creation, status/close ownership races, failed-status cancellation latching, ten repeated cancellations without retained threads, and normal completion remaining uncancelled.
- Initial and replacement generations use `reexec_timeout` from process launch. Real child-process tests verify budgets longer than the bootstrap limit, time spent loading configuration, rollback/reaping, and a late configured message arriving after a paused owner's bootstrap deadline. Configuration itself must still arrive within the separate 60-second bootstrap limit.
- `gritz stats`, `stop` and `restart` use the live Admin status and lifecycle owner without evaluating application code. Invalid/group PIDs, mismatched PID files, proxies, oversized data, redirects, invalid JSON and truncated HTTP bodies cannot become signal targets. A real TCP response with valid JSON but an incomplete Content-Length is rejected, including with PID fallback available.
- The reference generates the actual `before_action`, `around_action` and `after_action` signatures. Its runtime coverage and signature checks reject missing or incorrect generated documentation. The published API matches the 559-entry baseline.

The Native and HTTP race regressions first reproduced failures, then passed after correction. Changes were reviewed separately, committed directly to each `main`, and pushed without PRs or task identifiers in commit messages. The initial owner-published Gem files were preserved.

## Verification

Linux ARM64, Ruby 3.4.11 and grpc 1.84 completed all 463 tests against sibling source checkouts:

| Gem | Tests | Line coverage |
| --- | ---: | ---: |
| Core | 225 | 91.03% |
| Native | 137 | 97.94% |
| Meta | 12 | 100% |
| OpenTelemetry | 33 | 98.11% |
| Rails | 18 | 93.88% |
| Async | 38 | 97.73% |

All six lints and strict package builds passed. Dependency auditing against ruby-advisory-db commit `97659622944c19d42961c03813666f4196457229` found no vulnerabilities. All main workflows passed on Ruby 3.3, 3.4 and 4.0. Native/meta cover grpc 1.83 and the latest allowed version; Rails covers Rails 8.0 and 8.1. macOS Ruby 4.0.6/grpc 1.83 also passed the scheduling regressions. Documentation verified required pages, navigation, local links and the public API inventory.

Tag-triggered Trusted Publishing tests each package against published dependencies. The [stabilization record](stabilization.md) links main CI and releases. Publication verification downloads each Gem, checks its SHA256 against the individual RubyGems version API, compares the complete `lib`/`exe` manifest and bytes with its release tag, and confirms consumer Core 0.9.1 pins and the meta gem's Native 0.9.1 pin. It also checks local/remote main agreement, absence of PRs, and commit messages. All six downloaded packages passed: 87 runtime files matched their tag manifests and contents, every SHA256 matched RubyGems, and each repository had zero PRs and zero forbidden commit identifiers.

## Remaining gates

These corrections do not establish that the entire roadmap is finished. Native cancellation observation uses an additional short-lived thread per admitted application RPC. The short shared-VM diagnostic showed extra allocation and variable latency; the previous +3.70% overhead result predates this fix. Fixed-runner overhead/regression validation remains pending, as does the [sporadic CPU deadline investigation](https://github.com/gritzrpc/gritz-native/blob/main/docs/adr/cpu-deadline-investigation.md). See the [cancellation decision and retained samples](https://github.com/gritzrpc/gritz-native/blob/main/docs/adr/cancellation-observation.md).

The four actual weeks of stabilization have not elapsed; the earliest 1.0 decision remains 2026-10-31 09:11:28 UTC. Async's failed restart target remains outside stable scope. External beta operation was canceled by the owner. Other projects' containers were never stopped during this correction session; the owned Linux test container was returned to its stopped state. No 1.0 tag or publication was created.
