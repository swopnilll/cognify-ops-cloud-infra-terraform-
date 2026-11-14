# Cognify Ops: project notes and handover

Last updated: 14 November 2026.

This note is for anyone (person or AI session) picking the project up. It covers what the
project is, how the pieces fit, what was changed during the November 2026 restart, the new
AWS setup, and what is left to do.

## 1. Where things stand

| Area | State |
|---|---|
| Code | All four repos are on `main` and pushed to GitHub (owner `swopnilll`). |
| Local stack | Works end to end with Docker Compose, except the AI features, which need a real OpenAI key. |
| AWS | **Live** in the personal account (CLI profile `swop`): VPC, SQS queue and one EC2 server running the API, the embedding worker and Postgres. The API answers on plain HTTP at the server's Elastic IP (`terraform output api_url`). |
| `deploy/` folder | Exists only on the owner's laptop. It is not in any git repo yet (see section 9). |

The frontend is live at https://cognify-ops-fe.vercel.app. `vercel.json` in `cognify-ops-fe`
rewrites `/api/*` to the server's Elastic IP, so the browser only talks HTTPS to Vercel; if
the Elastic IP changes, update it there.

**Next steps:** set a real `OPENAI_API_KEY` in `server/.env.prod`, add
backups and a budget alert.

## 2. What the project is

Cognify Ops is a project management web app, originally a college project by Swopnil Acharya
and Suraj Kumar Regmi (early to mid 2025). Users create projects, manage tasks on a Kanban
board, and ask an AI assistant ("Intellecta") questions that are answered from the project's
own data using retrieval-augmented generation (RAG).

The original cloud resources (Supabase, Azure Service Bus, Auth0, an AWS S3 + CloudFront
frontend, the OpenAI key) have all expired or been deleted. In November 2026 the project was
restarted with a simpler, cheaper setup: everything on one EC2 instance.

## 3. Repositories and folders

All of these sit side by side in `~/Documents/cognify/`. The Compose file refers to the
others by relative path, so keep them as siblings.

| Folder | GitHub repo | What it is |
|---|---|---|
| `cognify-ops-fe` | `swopnilll/cognify-ops-fe` | React frontend |
| `cognify-ops-api` | `swopnilll/cognify-ops-api` | Main REST API |
| `embedding-microservice` | `swopnilll/embedding-microservice` | Background worker that builds the knowledge base |
| `cognify-ops-cloud-infra-terraform-` | `swopnilll/cognify-ops-cloud-infra-terraform-` | Terraform (this repo) |
| `deploy` | not in git yet | Docker Compose stack, Caddy config, deploy scripts |

## 4. How it works

```
Browser
   |
   v
web (Caddy)  -- serves the React app; proxies /api/* -->  api (Express, port 3000)
                                                            |          |
                                                            |          +--> SQS queue "embedding-jobs"
                                                            v                      |
                                                     db (Postgres 17 + pgvector)   v
                                                            ^            embedding (worker, port 3002)
                                                            |                      |
                                                            +----------------------+--> OpenAI
```

1. A user creates a project or a task through the API.
2. The API saves it to Postgres and publishes a job `{ projectId, taskId }` to the SQS queue.
3. The embedding service receives the job, reads the project and task text from Postgres,
   splits it into chunks (500 characters, 100 overlap), gets an embedding for each chunk from
   OpenAI, and stores them in the `knowledge_base` table.
4. When a user asks Intellecta a question with "Project knowledge" on, the API runs a
   similarity search over `knowledge_base` (top 5 chunks) and sends them with the question to
   the chat model.

Only the `web` container is reachable from outside. Postgres and the embedding service are
private to the Docker network.

## 5. The components

### Frontend (`cognify-ops-fe`)

- React 19, Vite 6, TypeScript, Tailwind CSS 4, TanStack Router (file-based routes in
  `src/routes`) and TanStack Query, `@dnd-kit` for drag and drop, Headless UI, `lucide-react`
  icons, `react-toastify`.
- Material UI, Radix, `react-spinners`, `react-icons`, Heroicons and `react-table` were
  removed in the redesign. Shared components live in `src/components/ui` (`Button`,
  `TextField`, `Select`, `Modal`, `Avatar`, `AvatarGroup`, `SearchBox`, `Spinner`, `UserMenu`).
- Design tokens (brand blue built around `#1868DB`, Inter font) are in `src/styles/index.css`.
- Pages: `/` landing, `/login`, `/signup`, `/projects`, and under `/project/$projectId`:
  `kanbanView` (board), index (task list), `ai-portal` (Intellecta), `settings` (team members).
- The login token is kept in `localStorage` (`access_token`, plus a `user` object). There is
  no refresh token; the token lasts 7 days.
- `VITE_API_BASE_URL` empty means "the API is on the same origin". That is how the Docker
  build sets it. For `npm run dev` against a local API, set it to `http://localhost:3000`.

### API (`cognify-ops-api`)

- Express 5, TypeScript, Prisma 6 (PostgreSQL), Passport JWT, LangChain, the OpenAI SDK,
  the AWS SDK for SQS, Winston logging.
- Layout: `routes` -> `controllers` -> `services` -> `repositories`.
- Routes, all under `/api`:
  - Public: `GET /health`, `POST /auth/signup`, `POST /auth/login`.
  - Everything else needs `Authorization: Bearer <token>`:
    `PATCH /auth/update-profile`, `GET /roles`, `GET /status`,
    `/projects` (list, create, `/:userId`, `/users/available`, `/:projectId/users`),
    `/tickets` (create, `/project/:projectId`, `/:ticketId/status`),
    `POST /openai/chat` (streamed general chat), `POST /openai/askintellecta` (RAG answer).
- **Auth is built in** (Auth0 was removed). Passwords are scrypt hashes in the `User` table;
  login returns an HS256 token signed with `JWT_SECRET`. Code: `src/config/auth.ts`,
  `src/utils/password.ts`, `src/services/auth/authService.ts`,
  `src/repositories/auth/authRepository.ts`, `src/middleware/passportMiddleware.ts`.
- The container applies pending Prisma migrations on start-up, then starts the server.

### Embedding microservice (`embedding-microservice`)

- Express + TypeScript worker. Long-polls SQS (`src/consumers/consumer.ts`), embeds with
  `text-embedding-3-small`, writes to `knowledge_base`.
- Also exposes `POST /api/generate-embedding` and `POST /api/askIntellecta` with **no
  authentication**. This is acceptable only because the service is not exposed publicly.
- Its README lists the known weaknesses of the pipeline (no evaluation, no observability,
  no re-embedding when content changes).

### Database

- Postgres 17 with pgvector (`pgvector/pgvector:pg17` image), data in a Docker volume on the
  instance's disk.
- Tables (see `cognify-ops-api/prisma/schema.prisma`): `User`, `Project`, `Ticket`, `Status`,
  `Role`, `User_Role`, `Project_User`, `Ticket_Assignment`, `knowledge_base`.
- Migrations added in the restart:
  - `20261114000000_add_knowledge_base_and_seed`: enables pgvector, creates `knowledge_base`
    (1536-dimension vectors), seeds roles `admin` and `default` and statuses `To Do`,
    `In Progress`, `Done`. The status names are a guess at the originals.
  - `20261114010000_local_auth`: adds email, password hash, name, picture, last login and
    created-at columns to `User`.

## 6. Running it locally

From `~/Documents/cognify/deploy`:

```bash
cp .env.example .env        # fill in; see the "Local" block inside the file
docker compose --profile local up -d --build
```

- App: http://localhost:8080 (set `HTTP_PORT=8080` in `.env`; port 80 is the default).
- The `local` profile starts ElasticMQ, a stand-in for SQS, so no AWS account is needed.
- Set `DB_PORT=5433` if port 5432 is taken on your machine.
- Stop with `docker compose --profile local down` (add `-v` to wipe the database).
- A local-only demo account exists in the owner's current local database:
  `demo@example.com` / `DemoPass123`. It does not exist anywhere else.

### Environment variables (`deploy/.env`)

| Variable | Purpose |
|---|---|
| `POSTGRES_PASSWORD` | Database password. Letters and digits only (it goes into a URL). |
| `JWT_SECRET` | Signs login tokens. At least 32 characters: `openssl rand -hex 32`. |
| `OPENAI_API_KEY` | Needed for embeddings and Intellecta. |
| `OPENAI_CHAT_MODEL` | Defaults to `gpt-4o`. |
| `EMBEDDING_MODEL` | Defaults to `text-embedding-3-small`. Must stay a 1536-dimension model. |
| `AWS_REGION` | Defaults to `ap-southeast-2`. |
| `SQS_QUEUE_URL` | Queue URL. On the server: the `sqs_queue_url` Terraform output. |
| `SQS_ENDPOINT`, `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` | Local only. Leave empty on EC2 so the instance role is used. |
| `SITE_ADDRESS` | `:80` for plain HTTP on any address; a domain name for automatic HTTPS. |

## 7. The AWS infrastructure

Applied on 14 November 2026. The `Readme.md` and the notes under `notes/` explain every
part in detail; this is the short version.

The first version was a single file, `environments/lean/main.tf` (never applied, git history
at commit `ea75655`). The repo now has a root `main.tf` plus `modules/`.

### What exists

| Resource | Details |
|---|---|
| State | S3 bucket created by `bootstrap/state`; keys `bootstrap/state/` and `prod/` |
| VPC | `10.30.0.0/16`, two public and two private /24 subnets, internet gateway, public route table (`modules/network`) |
| SQS | `embedding-jobs` with a dead-letter queue, 3 attempts (`modules/queue`) |
| EC2 instance | `t4g.micro` (ARM, 2 vCPU, 1 GB), Ubuntu 24.04, 16 GB encrypted gp3 disk, in public-a, CPU credits `standard` (`modules/server`) |
| Elastic IP | Fixed public address |
| Security group | 80 and 443 from anywhere; 22 from the addresses in `ssh_allowed_cidrs` |
| IAM role | Send/receive/delete on the queue, plus Session Manager |

Not built: budget alert, backups, HTTPS, any frontend hosting on AWS.

Details worth knowing:
- The instance metadata hop limit is 2 so containers can pick up the instance role.
- `lifecycle.ignore_changes` covers `ami` and `user_data`, so a new Ubuntu image never
  replaces the server (the database lives on its disk).
- The provider has `allowed_account_ids`, so Terraform refuses to run against any account
  other than the one named in `terraform.tfvars`.
- SSH is open to one IP address. If the owner's IP changes, update `ssh_allowed_cidrs` in
  `terraform.tfvars` and apply.

### Cost

About US$13 a month: roughly $7.70 for the instance, $1.50 for the disk and $3.65 for the
public IPv4 address. Approximate Sydney on-demand prices.

### Deploying

```bash
cd cognify-ops-cloud-infra-terraform-
terraform apply                 # infrastructure
scripts/deploy-api.sh           # application
```

`scripts/deploy-api.sh` builds the `cognify-api` and `cognify-embedding` images on the laptop
(the server has 1 GB of memory and never builds), sends them over SSH with
`docker save | docker load`, copies `server/docker-compose.yml` and `server/.env.prod` to
`/opt/cognify`, and runs `docker compose up -d`. `server/.env.prod` is git-ignored and holds
the database password, JWT secret and OpenAI key (currently the placeholder `changeme`, so the
AI features fail).

The server runs `api` (published on port 80), `embedding` and `db`. There is no `web`/Caddy
container on the server: the frontend is to be hosted on Vercel. The sibling `deploy/` folder
is now only used for running the stack locally (section 6).

### Older Terraform

`environments/dev` held the original S3 + CloudFront frontend hosting. It was removed with
`environments/lean` (git history: commit `f204be0`). It is no longer needed:
the frontend is now built into the `web` container.

## 8. What changed in the November 2026 restart

- Azure Service Bus replaced with SQS in both the API and the embedding service.
- Auth0 replaced with built-in email and password login.
- Supabase replaced with a Postgres container on the same server.
- Frontend hosting moved from S3 + CloudFront to the Caddy container; the GitHub workflow
  that deployed to S3 was deleted from `cognify-ops-fe`.
- API Dockerfile fixed (the old one could not build and left the migrations out of the image).
- `PATCH /api/auth/update-profile` now requires a login and only changes the caller's profile.
- Chat and embedding model names moved to environment variables.
- Frontend redesigned; the task list view was implemented; the board got an assignee filter.

## 9. Known gaps and to-do

**Before the server is public**
- No rate limiting on login or sign-up.
- CORS is open to every origin (`app.use(cors())`). Same-origin serving means it can be
  restricted or removed.
- Anyone can sign up, and any signed-in user can list every user (`/projects/users/available`).
- The API does not check project membership: a signed-in user can read or change any
  project's tickets by ID.

**Operations**
- **Backups:** `deploy/backup.sh` only writes dumps to the same disk. Nothing protects against
  losing the instance. Copying dumps to S3 or scheduling EBS snapshots is not set up.
- No monitoring or alerting other than the budget alert.
- Images are built on the server. A 2 GB instance copes, with swap, but builds are slow.
- GitHub reports 88 known vulnerabilities in the API's dependencies (4 critical). Not reviewed.

**Product**
- No password reset, email verification or social login.
- Intellecta's search is not limited to the current project; it searches all projects' data.
- Embeddings are added on create only. Editing or deleting a task leaves stale chunks, and
  each new task re-embeds its project's description, creating duplicates.
- Chat history lives in the browser tab only and is lost on refresh.
- The project pages are not tuned for phone-width screens.
- `cognify-ops-fe/README.md` still shows the old CloudFront URL and old test credentials.

**Housekeeping**
- The `deploy/` folder is not in git. Put it in this repo or a new one, keeping in mind that
  its Compose file expects the app repos as sibling folders.

## 10. Working rules for this project

- **AWS account:** the default AWS CLI profile on the owner's laptop is a **work account**.
  Never create Cognify resources with it. Use the `swop` profile (account 588301174695) for the personal
  account.
- **Git:** commit as `swopnilll` / `swopnilacharya@gmail.com` and push straight to `main`.
  No feature branches or pull requests unless asked.
- **Secrets:** `.env`, `.env.prod` and `terraform.tfvars` are git-ignored. Keep it that way.
- **Cost:** stay on the single instance. Do not add services with a fixed monthly cost
  (NAT gateway, load balancer, RDS) unless the owner asks.
