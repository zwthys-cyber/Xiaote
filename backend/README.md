# Tesla Fleet API backend

This service adds optional Tesla account connectivity to the existing local BLE key. It is a confidential OAuth client: Tesla access and rotating refresh tokens stay encrypted on the server, while the iOS app receives only a revocable application session token.

This document describes the backend source shipped with Xiaote v3.3.2. Actual server availability and deployed configuration must be checked separately. Local BLE pairing and Phone Key authentication do not depend on this service. See [architecture](../docs/ARCHITECTURE.md), [privacy](../docs/PRIVACY.md), and [build/release instructions](../docs/BUILD.md).

## China endpoints

- Authorization: `https://auth.tesla.cn/oauth2/v3/authorize`
- Token: `https://auth.tesla.cn/oauth2/v3/token`
- Fleet API: `https://fleet-api.prd.cn.vn.cloud.tesla.cn`
- Redirect URI: `https://api.txx.app/oauth/callback`
- Virtual-key enrollment: `https://tesla.cn/_ak/api.txx.app`
- Hosted public key: `https://api.txx.app/.well-known/appspecific/com.tesla.3p.public-key.pem`

## Required secrets

Never commit these values. Production reads them from `/opt/xiaote-backend/secrets/backend.env` with mode `0600`:

```dotenv
TESLA_CLIENT_ID=
TESLA_CLIENT_SECRET=
TOKEN_ENCRYPTION_KEY=
```

`TOKEN_ENCRYPTION_KEY` is a base64-encoded random 32-byte value. Tesla access and refresh tokens are AES-256-GCM encrypted at rest. App session tokens are only stored as SHA-256 hashes.

## API flow

1. iOS calls `POST /v1/auth/start` and opens `authorization_url` in `ASWebAuthenticationSession`.
2. Tesla redirects to the HTTPS backend callback.
3. The backend exchanges the authorization code, encrypts Tesla tokens, and redirects to `teslablekey://oauth/callback` with a two-minute, single-use code.
4. iOS exchanges that code at `POST /v1/auth/exchange` and stores the returned app session in Keychain.
5. Vehicle reads and commands use the app session. The backend rotates Tesla refresh tokens automatically.

Remote commands are allowlisted and sent through Tesla's official `tesla/vehicle-command` proxy. The fleet private key never enters the iOS app or public repository.

Vehicle routes process the account vehicle identifier/VIN and user-requested state or command parameters. Unlike BLE-only operation, these requests pass through the backend and Tesla. Endpoints are declared in `cmd/server/main.go`; client-facing requests are implemented in `Xiaote/Cloud/FleetAPIClient.swift` in the repository root. Account/profile, vehicle data and wake, vehicle details, charging-site queries, and allowlisted commands depend on the user's Tesla authorization and vehicle capabilities. The presence of a backend route does not imply every endpoint has a corresponding App screen.

Deployment templates are in `deploy/compose.yaml` and `deploy/Caddyfile`; they configure the backend, HTTPS entry point and command proxy. Keep production credentials outside the repository. Deploying changes to this source is separate from publishing an iOS IPA.

## Local verification

```bash
go test ./...
go vet ./...
docker build -t xiaote-backend:test .
```
