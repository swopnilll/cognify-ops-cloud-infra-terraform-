# 01 – Remote state

[← Back to the README](../../Readme.md)

Where Terraform keeps its record of what it has built, and why that record
lives in S3 instead of on a laptop.

Status: **applied.** Code: [`bootstrap/state`](../../bootstrap/state).

---

## 1. What state is

Terraform code says what should exist. **State** is Terraform's record of what
does exist: for every resource in the code, the real ID in AWS and its current
settings. `terraform plan` is the difference between the two.

If the state is lost, Terraform no longer knows the VPC or the server are its
own. It would try to create everything again.

## 2. Why not keep it on the laptop

| Local `terraform.tfstate` | State in S3 |
|---|---|
| Gone if the laptop is lost | Stored with 11 nines of durability |
| No history | Every version is kept (bucket versioning) |
| Can't be committed: it can hold secrets | Private, encrypted bucket |
| Two people can apply at once and corrupt it | A lock file stops the second apply |

## 3. What was built

One S3 bucket, with:

- **Versioning on.** Each apply writes a new version. A bad state can be rolled
  back to the one before.
- **Old versions expire after 90 days**, so they don't pile up forever.
- **Encryption at rest** (AES256, with a bucket key).
- **All four public access blocks on.**
- **A bucket policy that denies any request not using HTTPS.**
- **`prevent_destroy`**, so Terraform refuses to delete the bucket.

Two state files live in it:

| Key | Describes |
|---|---|
| `bootstrap/state/terraform.tfstate` | The bucket itself |
| `prod/terraform.tfstate` | Everything else: network, queue, server |

**Locking** uses an S3 lock file (`use_lockfile = true`). While an apply runs,
Terraform writes `<key>.tflock` next to the state and removes it at the end.
Older setups needed a DynamoDB table for this. That is no longer required.

## 4. The chicken-and-egg problem

The bucket has to exist before any configuration can store state in it,
including the configuration that creates the bucket. So it is built in two
moves:

1. Apply `bootstrap/state` with **local** state. The bucket now exists.
2. Add the `backend "s3"` block and run `terraform init -migrate-state`.
   Terraform copies the local state into the bucket. The local file is then
   deleted.

This is why the bucket has its own small configuration, separate from the
root: it is built once and then left alone.

## 5. Things to know

- A `backend` block can't use variables, so the bucket name is written out in
  full in both `main.tf` files.
- State can contain secrets in plain text (database passwords, for example).
  Treat read access to the bucket like access to the account.
- Cost: a few kilobytes of S3 storage. Well under one cent a month.
