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