# Security Policy

## Reporting a vulnerability

Please do not disclose security vulnerabilities, real Management API addresses, management keys, tokens, account details, or unredacted logs in a public Issue.

Use GitHub's private vulnerability reporting feature when available. If it is unavailable, open an Issue containing only a non-sensitive summary and wait for a maintainer to provide a private contact method.

## Deployment guidance

- Connect only to CLIProxyAPI instances you trust.
- Require HTTPS for remote connections and restrict access to the Management API at the network layer.
- Use a dedicated management key and rotate it if exposure is suspected.
- Review screenshots and logs before sharing them publicly.
- Keep the Android app and CLIProxyAPI server updated.

The application stores the configured Management API address and management key using Android-backed secure storage. It does not ship with a preconfigured private endpoint or credential.

## Official Android signing certificate

Current QuotaDash Android releases use the following SHA-256 signing certificate fingerprint,
verified against the official 2.2.1 APK:

```text
DE:58:35:3C:54:25:C2:73:5B:B0:2C:18:D6:C2:59:1F:A7:B9:71:D3:66:96:EE:FB:A8:AA:33:2B:26:55:77:83
```

Updates retain application ID `cn.imyxx.cliproxy_dash` and increase the version code.
An installation signed with a different legacy or debug key cannot be replaced by
this certificate. Never generate a replacement release key merely to build an update.

## Client privacy protections

- Service URLs reject embedded credentials, query parameters, and fragments.
- HTTP is limited to loopback and literal private LAN IPs; remote service addresses require HTTPS.
- Authenticated requests refuse redirects; configure the final service URL directly.
- Network errors show application-authored messages and HTTP status codes only.
  Server error bodies and transport diagnostics must not be displayed or logged.
- Android backup and device-transfer rules exclude application data containing settings.
- macOS service URLs and management keys are stored in Keychain; older plaintext URL settings migrate on startup.
- WorkBuddy reads plugin account and credits endpoints on the configured server;
  its access and refresh tokens remain on the server.
- Signing material belongs in repository Secrets or protected local storage, never
  Actions artifacts. The former signing-bootstrap workflow has been removed.
- CI scans Git history with Gitleaks and redacts scanner output.
