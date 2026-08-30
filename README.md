# Project 1: Three-Tier App on AWS — High-Level Design

## Business use / real-world application

This project simulates a very common real-world pattern: **a company needs to let
a customer look up their own data on a website, safely.**

Examples of the same pattern in the real world:
- A banking app showing your account balance
- An e-commerce site showing your order history
- A telco showing your phone bill
- CBA's PDF statement generation service (customer needs to see their statement)

The specific design choices below exist for real, practical reasons:
- **Public/private subnet split** — a company cannot let random people on the
  internet talk directly to a database holding customer data. In banking this
  is close to a regulatory requirement.
- **Secrets Manager instead of hardcoding a password** — prevents the very
  common real-world mistake of committing a database password into code.
- **Security Groups / NACLs** — even if someone breaks into the web server,
  they still cannot freely reach the database, because the database only
  trusts requests from that one specific server.

## Architecture overview (in plain language)

Four zones, three arrows:

1. **Customer** — visits the website (a browser hitting a URL).
2. **AWS VPC** — the walls of a private building inside AWS. Nothing gets in
   or out unless a door has been explicitly built.
3. **Public subnet** (inside the VPC) — the front lobby, has a door to the
   internet. Contains the **EC2 web server**.
4. **Private subnet** (inside the VPC) — a locked back room, no door to the
   internet at all. Contains the **RDS database** and **Secrets Manager**.

**Arrows (the actual flow):**
- Customer → EC2: someone visits the site, hits the web server.
- EC2 → Secrets Manager: before touching the database, EC2 asks for the DB
  password (never hardcoded).
- EC2 → RDS: web server reaches into the private subnet to read/write data.

**Where NACLs, Security Groups, and IAM fit in (not drawn as boxes — they are
locks on the doors already described):**
- **Security Groups** sit on the EC2 → RDS arrow: "only EC2 may knock on the
  database's door."
- **NACLs** sit on the subnet boundaries themselves: a second, stricter layer
  of gatekeeping at the subnet level.
- **IAM** decides which humans or services are allowed to make changes to any
  of these resources in the first place.

## File map

### Terraform files (build the boxes)

| File                 | What it does                                              | Maps to                        |
| -------------------- | --------------------------------------------------------- | ------------------------------ |
| `network.tf`         | Creates the VPC, the public subnet, the private subnet    | The VPC + two subnet zones     |
| `nacl.tf`            | Sets the subnet-level door rules                          | Lock on the subnet boundary    |
| `security-groups.tf` | Sets the rule "only EC2 can talk to RDS"                  | Lock on the EC2 → RDS arrow    |
| `ec2.tf`             | Creates the web server                                    | EC2 box                        |
| `rds.tf`             | Creates the database                                      | RDS box                        |
| `secrets.tf`         | Creates the locked safe and stores the DB password        | Secrets Manager box            |
| `iam.tf`             | Creates the ID card defining what EC2 is allowed to touch | Invisible access-control layer |
| `outputs.tf`         | Prints useful info after building (e.g. EC2 address)      | Convenience only, not a "box"  |

### Python files (ride the arrows)

| File                 | What it does                                                                                   | Maps to                               |
| -------------------- | ---------------------------------------------------------------------------------------------- | ------------------------------------- |
| `check_db_health.py` | Gets the password from Secrets Manager, connects to RDS, checks it's alive, reports the result | EC2 → Secrets Manager, then EC2 → RDS |

## Build order (each step depends on the one before it)

1. `network.tf` — VPC and subnets must exist before anything else
2. `nacl.tf` + `security-groups.tf` — locks go on before anything sensitive exists
3. `iam.tf` — the ID card is created before it's handed to EC2
4. `secrets.tf` — the safe is created and the password goes in
5. `rds.tf` — the database is created inside the private subnet
6. `ec2.tf` — the web server is created last, once it has somewhere to go and something to talk to
7. `outputs.tf` — so the results can be seen
8. `check_db_health.py` — run after everything above exists

## Design rule for this entire project

Every `.tf`, `.py`, `.yml`, or `.json` file does exactly one job, and that job
can be summarized in one sentence. No unnecessary abstraction, no
"enterprise-grade" folder structures for a solo learning project.

## Status: built, verified end-to-end, and torn down (30 Aug 2026)

All 8 files were written, applied to a real AWS account, and verified working:
`check_db_health.py` successfully fetched credentials from Secrets Manager
using the IAM role, connected to RDS through the security group, and
reported `HEALTHY`. All 20 resources were then destroyed cleanly with
`terraform destroy` to avoid ongoing cost — the whole stack can be rebuilt
from GitHub in minutes with `terraform apply`.

GitHub repo: https://github.com/anuragjaiswal26/three-tier-app-aws

## Real issues hit and fixed while building

These are genuine troubleshooting moments worth being able to talk through
in an interview — they show debugging skill, not just copy-pasting code.

1. **RDS engine version rejected.** `engine_version = "16.4"` failed with
   `InvalidParameterCombination: Cannot find version 16.4 for postgres` -
   that exact minor version wasn't available in the region at the time.
   **Fix:** pin only the major version (`engine_version = "16"`), which lets
   AWS pick the latest available minor version automatically - more robust
   against future deprecations too.

2. **EC2 instance type not free-tier eligible.** `t2.micro` was rejected
   with `InvalidParameterCombination: The specified instance type is not
   eligible for Free Tier`. AWS's free-tier-eligible instance type differs
   by account age/cohort. **Fix:** switched to `t3.micro`, which was the
   eligible type for this account.

3. **Key pair not found.** `ec2.tf` referenced a key pair name that didn't
   exist yet in the account (an old project's key was there instead).
   **Fix:** created a fresh key pair (`three-tier-key`, RSA, `.pem`) in the
   EC2 console specifically for this project, and ran `chmod 400` on the
   downloaded file (SSH refuses to use a key file with overly-open
   permissions).

4. **Git push rejected (`fetch first` / divergent branches).** GitHub had
   auto-created a file (likely a README) when the repo was made, so the
   remote had commits the local repo didn't. **Fix:**
   `git config pull.rebase false`, then
   `git pull origin main --allow-unrelated-histories`, resolved the merge,
   then pushed cleanly.

5. **`nano` not installed on Amazon Linux 2023** - had to
   `sudo dnf install -y nano` first.

6. **Empty file saved via `nano` over SSH.** After installing nano and
   pasting the script, the file saved as 0 bytes (`ls -la` showed size
   `0`) - `python3 check_db_health.py` ran with no output and exit code 0,
   which was the actual clue something was wrong (an empty file "succeeds"
   silently). Likely cause: the terminal's paste didn't get handled
   correctly by nano over this SSH session. **Fix:** used a `cat > file
   << 'EOF' ... EOF` heredoc instead, which pastes reliably in one shot
   without an interactive editor in the way. Always verify a file actually
   has content (`ls -la`, or `cat` it) before assuming a paste worked.

## Cost note

RDS (`db.t3.micro`) is the only resource in this stack with a meaningful
ongoing cost if left running past the free tier. Run `terraform destroy`
after each practice/demo session; rebuild with `terraform apply` when
needed again - the full stack takes roughly 6-7 minutes end to end (RDS is
the slow part, ~5 minutes; everything else is near-instant).