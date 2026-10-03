# Support policy

Policy date: 2026-10-03. Stable scope and experimental exclusions are described in the [public API policy](public-api.md).

| Component | Supported versions / environment |
| --- | --- |
| Ruby | CRuby 3.3, 3.4 and 4.0; CI tests each branch |
| Process supervision | Linux for multiple workers, inherited listeners and process lifecycle gates |
| macOS | Single-process development with `workers 0`; Linux validates multiprocess deployment |
| Native gRPC | Official `grpc` gem >= 1.83.0 and < 2; CI tests the minimum and latest allowed versions |
| Rails | Rails 8.0 and 8.1 on each supported Ruby branch |
| OpenTelemetry | Versions bounded by the integration gemspec; the metrics SDK remains alpha |
| Async | Experimental, upstream versions bounded by its gemspec; excluded from the stable 1.0 guarantee |

JRuby, TruffleRuby, Windows process supervision and untested Ruby/grpc major versions are outside the current support matrix. Use matching Gritz component versions as required by their gemspecs; the meta gem selects the default Native adapter.

Ruby support follows the upstream [maintenance branches](https://www.ruby-lang.org/en/downloads/branches/). Ruby 3.3 is in security maintenance, with expected EOL 2027-03-31. Ruby 3.4 and 4.0 are in normal maintenance; their EOL dates are not yet announced. This policy does not invent dates for those branches. Security fixes are supported while the relevant Ruby branch receives upstream security maintenance.

Dropping a supported Ruby branch or increasing the grpc/Rails minimum is a breaking support change: announce it in CHANGELOG and migration documentation, use a minor release before 1.0 or a major release after 1.0. Raising the tested latest compatible patch/minor within existing constraints does not remove the declared minimum. Add a new Ruby or grpc major to the support contract only after its full CI and lifecycle checks pass.

The latest stable minor series receives compatible bug and security fixes. Report vulnerabilities privately as described in [SECURITY.md](../SECURITY.md). No fixed response-time SLA or unmaintained backport branch is promised. Review upstream EOL status before each stabilization or major release.
