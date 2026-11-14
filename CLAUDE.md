# Cognify Ops infrastructure

Read `PROJECT_NOTES.md` in this folder before doing anything. It describes the whole project
(frontend, API, embedding service, database, deployment), the current state, and what is left
to do.

Rules that must not be broken:

- The default AWS CLI profile on this machine is a **work account**. Never create or change
  Cognify resources with it. Use the `swop` profile (the owner's personal account, 588301174695).
  Nothing has been applied to AWS yet.
- Commit as `swopnilll` / `swopnilacharya@gmail.com` and push straight to `main`. Do not
  create feature branches or pull requests unless asked.
- Never commit `.env`, `.env.prod` or `terraform.tfvars`.
- Keep the setup on the single EC2 instance. Do not add a NAT gateway, load balancer or RDS
  unless asked.
- The app repos and the `deploy` folder are siblings of this repo in `~/Documents/cognify/`.
