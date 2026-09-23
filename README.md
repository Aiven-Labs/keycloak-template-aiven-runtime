# Run Keycloak on Aiven Runtime

A ready-to-deploy [Keycloak](https://www.keycloak.org/) container backed by
PostgreSQL 18, built for [Aiven Runtime](https://aiven.io/runtime).

## How it's wired

- **`Containerfile`** — multi-stage build. Runs `kc.sh build` against
  `KC_DB=postgres` to produce an optimized Keycloak image, then starts it
  with `kc.sh start --optimized`.
- **`entrypoint.sh`** — Keycloak wants discrete `KC_DB_URL` /
  `KC_DB_USERNAME` / `KC_DB_PASSWORD` values, but Aiven Runtime injects a
  single `DATABASE_URL`. This script parses and percent-decodes that URI
  at container start and exports the Keycloak-native vars before handing
  off to `kc.sh`. It never prints the URL or credentials.
- **`compose.yaml`** — defines two services:
  - `keycloak` — the application service (built via `build:`, so Aiven
    Runtime runs it as your app).
  - `postgres` — uses the `postgres:18` image, which Aiven Runtime
    recognizes as a PostgreSQL data service. **On Aiven Runtime this
    service is not run as a container** — Aiven provisions a managed
    Aiven for PostgreSQL instance instead and injects `DATABASE_URL` into
    the `keycloak` service automatically. Locally with `docker compose up`,
    it's a real Postgres 18 container so you can develop offline.

## Local development

```bash
export POSTGRES_PASSWORD=devpassword
export KC_BOOTSTRAP_ADMIN_PASSWORD=devpassword
docker compose up --build
```

Keycloak comes up on `http://localhost:8080`. Log in to the admin console
with username `admin` and the password above.

> Postgres 18's official image changed its data-directory layout — the
> volume mounts at `/var/lib/postgresql` (not `.../data`) so it can manage
> major-version subdirectories itself. Don't change this mount path.

## Deploying to Aiven Runtime

1. Push this repo (or a fork of it) to a Git provider connected to your
   Aiven Runtime project.
2. Create the application from `compose.yaml` — Aiven Runtime will build
   the `keycloak` service from `Containerfile` and provision a managed
   PostgreSQL 18 service for `postgres`, wiring `DATABASE_URL` into
   `keycloak` for you.
3. Set these environment variables on the `keycloak` service in the Aiven
   Runtime console (never commit them):
   - `KC_BOOTSTRAP_ADMIN_USERNAME`
   - `KC_BOOTSTRAP_ADMIN_PASSWORD`
   - Optionally `KC_HOSTNAME` once you know the app's public URL, for
     stricter hostname checking than the `KC_HOSTNAME_STRICT=false`
     default baked into the image.
4. Deploy. Aiven Runtime routes traffic to the container's `EXPOSE`d port
   `8080`; `KC_PROXY_HEADERS=xforwarded` is already set so Keycloak trusts
   the platform's reverse proxy for scheme/host.

### Tightening TLS to the database

By default the parsed `KC_DB_URL` uses whatever `sslmode` Aiven's
`DATABASE_URL` specifies (falls back to `require`, which encrypts but
doesn't verify the server certificate). To move to `verify-ca`/
`verify-full`, download the PostgreSQL service's CA certificate from the
Aiven Console and mount it into the container, then extend
`entrypoint.sh` to pass `KC_DB_URL_PROPERTIES` (or append
`&sslrootcert=/path/to/ca.pem`) before calling `kc.sh`.
