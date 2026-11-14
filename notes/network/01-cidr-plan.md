# 01 – CIDR plan

The address plan for the Cognify VPC. It is decided first because a VPC's
primary CIDR and a subnet's CIDR can't be changed after creation: getting it
wrong means destroying and rebuilding everything inside.

Status: **in Terraform (`modules/network`), planned but not applied.** Account
588301174695, CLI profile `swop`.

---

## 1. The plan

| Range     | CIDR          | AZ              | Addresses        | For                                  |
|-----------|---------------|-----------------|------------------|--------------------------------------|
| VPC       | 10.30.0.0/16  | –               | 65,536           |                                      |
| public-a  | 10.30.0.0/24  | ap-southeast-2a | 256 (251 usable) | The EC2 server                       |
| public-b  | 10.30.1.0/24  | ap-southeast-2b | 256 (251 usable) | Empty. Second AZ, if a load balancer is ever added |
| private-a | 10.30.10.0/24 | ap-southeast-2a | 256 (251 usable) | Empty. Reserved for a database       |
| private-b | 10.30.11.0/24 | ap-southeast-2b | 256 (251 usable) | Empty. Reserved for a database       |

- **Usable addresses:** AWS keeps 5 in every subnet: `.0` network, `.1` router,
  `.2` DNS, `.3` reserved, `.255` broadcast.
- **Free space:** 10.30.2.0–10.30.9.255 (8 more public /24s), 10.30.12.0–10.30.19.255
  (8 more private /24s), and everything from 10.30.20.0 up.
- **IP version:** IPv4 only.
- **Cost:** a VPC and its subnets are free. Empty subnets cost nothing.

## 2. Why these numbers

**VPC: 10.30.0.0/16**

- **Private range.** It must come from RFC 1918 space: 10.0.0.0/8,
  172.16.0.0/12 or 192.168.0.0/16.
- **Not 172.x.** Docker uses 172.17.0.0/16 for its default bridge and takes
  172.18–172.31 for Compose networks. The server runs Docker Compose, so a VPC in
  that range could make a container network shadow real VPC addresses.
- **Not 192.168.x.** Home routers use it. It would clash if a VPN from a laptop
  is ever added.
- **Not 10.0.0.0/16 or 10.20.0.0/16.** 10.0 is what everyone picks, and 10.20 is
  taken by `flatwhite-prod-vpc` in the other account. Two VPCs can only be
  peered if their ranges don't overlap, so each VPC gets its own second octet.
- **/16.** The largest a VPC can be. Addresses are free, so there's no reason to
  go smaller, and it makes the subnet maths simple (below).

**Subnets: /24, numbered by the third octet**

- A /24 inside a /16 means the third octet *is* the subnet number, so an address
  can be read at a glance: `10.30.10.57` is VPC 30, subnet 10, host 57.
- **0–9 is the public tier, 10–19 the private tier.** Seeing the third octet
  tells you the tier. Each tier has room for 10 subnets.
- **Within a tier, the number counts AZs:** `.0` = a, `.1` = b. `.10` = a,
  `.11` = b. A third AZ would be `.2` and `.12`.
- 251 addresses per subnet is far more than one server needs. A bigger subnet
  wouldn't cost more, but /24 keeps the octet-boundary readability.

**Two AZs, although there's one server**

- Subnets live in exactly one AZ and can't be moved. A load balancer needs
  subnets in two AZs, and so does an RDS subnet group. Reserving the b-side
  ranges now is free; finding non-clashing ranges later is the annoying part.
- Nothing is built in public-b or the private subnets. The "no NAT gateway, no
  load balancer, no RDS" rule in `PROJECT_NOTES.md` still stands.

## 3. How Terraform computes it

`cidrsubnet(prefix, newbits, netnum)` adds `newbits` to the prefix length and
picks subnet number `netnum`:

| Call                                  | Result        |
|---------------------------------------|---------------|
| `cidrsubnet("10.30.0.0/16", 8, 0)`    | 10.30.0.0/24  |
| `cidrsubnet("10.30.0.0/16", 8, 1)`    | 10.30.1.0/24  |
| `cidrsubnet("10.30.0.0/16", 8, 10)`   | 10.30.10.0/24 |
| `cidrsubnet("10.30.0.0/16", 8, 11)`   | 10.30.11.0/24 |

/16 + 8 bits = /24. Only `vpc_cidr` is typed by hand (in the root `main.tf`), so
the subnets can never fall outside the VPC or overlap each other.

Check the maths without an AWS account:

```bash
echo 'cidrsubnet("10.30.0.0/16", 8, 10)' | terraform console
```

## 4. What "public" and "private" mean right now

Nothing yet. The names are only labels. A subnet is public when its route table
has a route to an internet gateway, and there's no internet gateway or route
table so far. Until then all four subnets use the VPC's main route table, which
only has the local route (10.30.0.0/16 → local).

## 5. Next steps (one change at a time)

1. `terraform apply`. The plan shows 5 resources: 1 VPC and 4 subnets.
2. Remote state: `bootstrap/state` (S3 bucket, versioning, lock file).
3. Internet gateway.
4. Public route table with 0.0.0.0/0 → internet gateway, associated with
   public-a and public-b.
5. Security group for the server.
6. Then the server itself, SQS, IAM and the budget alert. The earlier
   single-file version of these is in git history: `git show ea75655 --stat`.
