# Flowise Deployment on Bastion

## What
Flowise (Web UI) deployed on the Bastion host via a systemd service that
auto-starts on every boot, fetching the DB password from AWS SSM Parameter
Store instead of hardcoding it.

## Why on Bastion, not ASG
Flowise is stateful (holds its own auth session config). ASG instances are
meant to be interchangeable/stateless. Bastion is a fixed, single instance —
better fit.

## Components
- IAM Role + Instance Profile (`aws_iam_role.bastion`,
  `aws_iam_instance_profile.bastion`) — lets Bastion call
  `ssm:GetParameter` scoped to `/distributed-llm-aws/*`
- SSM Parameter `/distributed-llm-aws/dev/db_password` (SecureString)
- `packer/scripts/flowise.service` — systemd unit, `Type=oneshot`,
  fetches password at start, runs `docker run flowiseai/flowise`

## Issues hit and fixed (in order)
1. Password mismatch between Postgres/Flowise env vars in local Docker test
2. `ETIMEDOUT` connecting to RDS — RDS SG only allowed ASG SG, not Bastion SG
   (fixed: added ingress rule for Bastion SG on 5432)
3. `no encryption` — RDS requires SSL, Flowise didn't use it by default
   (fixed: `DATABASE_SSL=true`)
4. `self-signed certificate in certificate chain` — Node doesn't trust
   Amazon RDS's CA by default
   (fixed: `NODE_TLS_REJECT_UNAUTHORIZED=0` — acceptable here since RDS is
   private, not internet-facing; proper fix for production would be
   loading the official RDS CA bundle instead)
5. `password authentication failed` — password mismatch between
   `terraform/terraform.tfvars` and `terraform/rds/terraform.tfvars`
   (RDS was actually created via the `rds/` project, so that file is the
   source of truth)
   (fixed: `aws rds modify-db-instance --master-user-password` to force
   a known-good password, then synced SSM to match)

## Verified working
```sql
SELECT name, email FROM "user";     -- shows registered admin account
SELECT name FROM chat_flow;          -- shows test flow created in browser
```
Both confirmed present in real RDS (not local test data).

## Access
`http://<bastion_public_ip>:3000`
