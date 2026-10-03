# Stabilization before 1.0

The roadmap requires four actual weeks in the 0.9 series without a required breaking change, and zero unresolved critical bugs, before publishing 1.0. Documentation, passing tests or successful package publication cannot replace elapsed time.

The stable candidate comprises `gritz-core`, `gritz-native`, `gritz`, `gritz-otel` and `gritz-rails` 0.9.0. Async remains experimental, with a compatible 0.1-series release and its failed restart target recorded separately. The [public API](public-api.md), [support policy](support-policy.md) and [security review](security-review.md) define the candidate's scope.

The observation clock starts only after all five 0.9.0 packages are published and their release/main checks pass. Publication is currently pending; no observation start or 1.0 eligibility is claimed. A breaking correction resets the clock to the revised candidate's publication. Compatible fixes remain eligible only after their required checks pass.

Before 1.0, review the public API and dependency/default changes since the candidate, main/release CI, Native lifecycle and retained performance evidence, and any reported critical defects. External beta operation was canceled by the owner and is not a release gate. The documented Async limitation remains outside stable scope.
