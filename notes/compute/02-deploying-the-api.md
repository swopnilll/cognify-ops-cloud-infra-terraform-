# 02 – Deploying the API

[← Back to the README](../../Readme.md)

How the code gets onto [the server](01-server.md).

Status: **working.** Code: [`scripts/deploy-api.sh`](../../scripts/deploy-api.sh),
[`server/docker-compose.yml`](../../server/docker-compose.yml).

---

## 1. Build on the laptop, run on the server

```
laptop                                        server
──────                                        ──────
docker build  (api, embedding)
docker save | gzip ──── ssh ───────────────►  gunzip | docker load
docker-compose.yml, .env ── ssh ───────────►  /opt/cognify
                                              docker compose up -d
curl /api/health  ◄────────────────────────   api answers on port 80
```

Building an image means `npm ci` and a TypeScript compile, which need far more
memory than running the result. Building on the laptop is what lets the server
be a 1 GB instance. Both are ARM, so the images run as built.

The next step up is a registry (Amazon ECR) with images built by CI. That is
worth it once there is more than one person or one server.

## 2. What runs

| Container | Image | Reachable from |
|---|---|---|
| `api` | `cognify-api`, built from `cognify-ops-api` | The internet, on port 80 |
| `embedding` | `cognify-embedding`, built from `embedding-microservice` | Nothing. It only makes outbound calls |
| `db` | `pgvector/pgvector:pg17` | The other two containers only |

- The API container applies pending database migrations each time it starts.
- Postgres data is in a Docker volume on the root disk.
- `restart: unless-stopped` brings everything back after a reboot.
- Logs are capped at 3 × 10 MB per container so they can't fill the disk.

## 3. Secrets

`server/.env.prod` (git-ignored) holds the database password, the JWT signing
secret and the OpenAI key. The script copies it to `/opt/cognify/.env` with
mode 600 and adds the queue URL from Terraform's outputs.

There are **no AWS keys** in it. The containers use the
[instance role](01-server.md#8-iam-role).

A plain file on the server is the simplest thing that works. The better
version is SSM Parameter Store or Secrets Manager, read at start-up.

## 4. Run it

```bash
cp server/.env.example server/.env.prod    # fill in, once
scripts/deploy-api.sh
```

The script waits for the server's first-boot setup, deploys, then polls
`/api/health` until it answers.

## 5. Useful commands

```bash
ssh ubuntu@$(terraform output -raw server_public_ip)

cd /opt/cognify
docker compose ps
docker compose logs -f api
docker compose exec db psql -U cognify       # a database shell
free -m && df -h /                           # memory and disk
```
