# Infinite Music — Mock Catalog Backend

Development backend implementing the Phase A API contract: versioned delta
sync, a monotonic catalog change-log, and demo (unsigned) audio streaming.
See `src/repository/catalogRepository.js` and `src/services/streamUrlProvider.js`
for what's real logic vs. explicitly-marked mock behavior.

## Requirements

- Node.js 18+ (uses the built-in `node --test` runner — verified on Node 22.22.2)

## Setup

```
npm ci
```

`npm ci` (not `npm install`) installs exactly what's pinned in
`package-lock.json` — use this for a reproducible install, especially in CI
or when verifying this project fresh.

## Run the test suite

```
npm test
```

Runs `node --test test/*.test.js` — both `test/catalogRepository.test.js`
(repository-level unit tests: versioning, add/update/delete, search) and
`test/api.test.js` (HTTP-level tests against every real endpoint via
`supertest`, no server process needs to be running for these — the Express
app is imported and tested in-process).

The suite currently contains **36 tests** (repository + HTTP). The delivered source should be verified with `npm ci && npm test` before release; the current audit environment cannot fetch one npm tarball dependency.

## Start the server

```
npm start
```

Listens on `http://0.0.0.0:3000` by default (override with `PORT=xxxx npm start`).
Development admin/test mutation routes are enabled by default outside production;
set `ENABLE_DEV_ADMIN=false` to disable them locally. When `NODE_ENV=production`,
admin mutation routes are **always disabled** by this Phase A mock and must be
replaced by authenticated admin infrastructure before any production deployment.
From an Android emulator, reach it at `http://10.0.2.2:3000` — see the
Flutter project's README for why that address is emulator-only.

## Manually exercising delta sync

With the server running:

```
curl -X POST http://localhost:3000/api/v1/admin/songs/s1/touch
curl -X DELETE http://localhost:3000/api/v1/admin/songs/s1
curl "http://localhost:3000/api/v1/catalog/sync?version=8"
```

The last call should show only what actually changed since version 8, not
the whole catalog.
