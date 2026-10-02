# Security

Report suspected vulnerabilities privately through GitHub's [security advisories](https://github.com/ydah/gritz/security/advisories/new), or email the maintainer at t.yudai92@gmail.com.

The initial 0.1 release supports insecure gRPC transport. Deploy it on a trusted network or behind a TLS-terminating proxy. Applications must implement authentication and authorization in controllers or middleware. Internal exceptions are redacted in RPC responses; diagnostic logs should be access-controlled.

Inbound/outbound message and metadata size limits are enabled by default. Reflection and public administration endpoints are absent in the initial release. CI checks dependencies with bundler-audit. Future native TLS and process-management support will have separate integration coverage before release.
