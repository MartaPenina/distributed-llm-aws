# RDS — Decouple + Protection

## What
RDS moved into a separate Terraform project (`terraform/rds/`) instead of
being part of the main state.

## Why
Mentor requirement: RDS must survive `terraform destroy` runs on the main
infrastructure — recreating a database every time is slow and risky.

## How it works
- `terraform/rds/backend.tf` — separate S3 state key
- `terraform/rds/main.tf` — reads `subnet_ids` and `sg_id` from the main
  project's state via `data "terraform_remote_state"` (read-only, no
  duplication of networking resources)
- `modules/database/main.tf` — three protections added:
  - `lifecycle { prevent_destroy = true }` — blocks `terraform destroy`
    at the Terraform level
  - `deletion_protection = true` — blocks deletion at the AWS API level
  - `skip_final_snapshot = false` + `final_snapshot_identifier` — forces
    a backup snapshot before any deletion attempt

## Verify
```bash
cd terraform/rds
terraform show
terraform output rds_endpoint
```

## Outputs added
- `terraform/outputs.tf`: `private_db_subnet_ids`, `rds_sg_id`
  (consumed by the RDS project's remote state read)
