# Stabilization before 1.0

The roadmap requires four actual weeks in the 0.9 series without a required breaking change, and zero unresolved critical bugs, before publishing 1.0. Documentation, passing tests or successful package publication cannot replace elapsed time.

The stable candidate comprises `gritz-core`, `gritz-native`, `gritz`, `gritz-otel` and `gritz-rails` 0.9.0. Async remains experimental, with a compatible 0.1-series release and its failed restart target recorded separately. The [public API](public-api.md), [support policy](support-policy.md) and [security review](security-review.md) define the candidate's scope.

All five 0.9.0 packages are published, with successful main and Trusted Publishing release workflows. Verification completed at **2026-10-03 09:11:28 UTC** (18:11:28 JST); this is the observation start. The earliest possible 1.0 decision is **2026-10-31 09:11:28 UTC** (18:11:28 JST). The four weeks have not elapsed, so 1.0 has not been tagged or published. A breaking correction resets the clock to the revised candidate's publication. Compatible fixes remain eligible only after their required checks pass.

| Gem | Version | Main CI | Release |
| --- | --- | --- | --- |
| gritz-core | 0.9.0 | [Passed](https://github.com/gritzrpc/gritz-core/actions/runs/37111409519) | [Published](https://github.com/gritzrpc/gritz-core/releases/tag/v0.9.0) |
| gritz-native | 0.9.0 | [Passed](https://github.com/gritzrpc/gritz-native/actions/runs/37111411741) | [Published](https://github.com/gritzrpc/gritz-native/releases/tag/v0.9.0) |
| gritz | 0.9.0 | [Passed](https://github.com/gritzrpc/gritz/actions/runs/37111453577) | [Published](https://github.com/gritzrpc/gritz/releases/tag/v0.9.0) |
| gritz-otel | 0.9.0 | [Passed](https://github.com/gritzrpc/gritz-otel/actions/runs/37111416634) | [Published](https://github.com/gritzrpc/gritz-otel/releases/tag/v0.9.0) |
| gritz-rails | 0.9.0 | [Passed](https://github.com/gritzrpc/gritz-rails/actions/runs/37111418700) | [Published](https://github.com/gritzrpc/gritz-rails/releases/tag/v0.9.0) |
| gritz-async (experimental) | 0.1.4 | [Passed](https://github.com/gritzrpc/gritz-async/actions/runs/37111420534) | [Published](https://github.com/gritzrpc/gritz-async/releases/tag/v0.1.4) |

All six versions and runtime dependency requirements were checked through RubyGems' individual version API; consumer gems require Core 0.9.0, and the meta gem also requires Native 0.9.0. The main suites contain 427 tests. Native and meta CI cover each of Ruby 3.3/3.4/4.0 with both minimum grpc 1.83.0 and the latest allowed version; Rails also covers 8.0/8.1. All six release workflows passed tests, lint and strict builds against published dependencies. The meta release checks the hello sample's four RPC forms; the Rails release checks real database RPCs on all four workers and process cleanup.

The [documentation deployment](https://github.com/gritzrpc/gritz/actions/runs/37111453600) passed, and the [public site](https://gritzrpc.github.io/gritz/) returned HTTP 200. Its public API inventory matched the reviewed candidate snapshot. The site build checks guide/reference pages, navigation and local file links.

Before 1.0, review the public API and dependency/default changes since the candidate, main/release CI, Native lifecycle and retained performance evidence, and any reported critical defects. External beta operation was canceled by the owner and is not a release gate. The documented Async limitation remains outside stable scope.
