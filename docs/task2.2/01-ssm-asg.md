# SSM Session Manager — IAM Fix for ASG and Bastion

## Problem
ASG instances had no IAM Instance Profile — SSM Agent couldn't authenticate
with AWS. Bastion had a role but missing SSM Session Manager permissions.

## Root Cause
SSM Session Manager requires `AmazonSSMManagedInstanceCore` managed policy.
- Bastion: had custom role (ssm:GetParameter only) — missing SSM core policy
- ASG: no IAM role or Instance Profile at all

## What was added (terraform/modules/security/main.tf)
- `aws_iam_role_policy_attachment.bastion_ssm_core` — attached
  `AmazonSSMManagedInstanceCore` to existing Bastion role
- `aws_iam_role.asg` — new role for ASG instances
- `aws_iam_role_policy_attachment.asg_ssm` — attached
  `AmazonSSMManagedInstanceCore` to ASG role
- `aws_iam_instance_profile.asg` — Instance Profile for ASG

## What was updated
- `modules/compute/main.tf` — added `iam_instance_profile` block to
  `aws_launch_template.main`
- `terraform/main.tf` — added `asg_instance_profile_name` to
  `module "compute"`

## How instances were updated
ASG instances: `aws autoscaling start-instance-refresh` with
`MinHealthyPercentage: 50` — rolling replacement without downtime.

Bastion: not replaced (not in ASG) — SSM Agent picks up new credentials
automatically within ~15 min, or manually:
`sudo systemctl restart snap.amazon-ssm-agent.amazon-ssm-agent.service`

## Final Status
AWS Console → EC2 → Connect → SSM Session Manager:
All instances verified Connected in AWS Console:
- Bastion : Connected
- ASG instance 1 : Connected
- ASG instance 2 : Connected

## Test commands (run inside SSM Session Manager terminal)
```bash
# Verify Ollama is running
systemctl status ollama

# Verify which interface Ollama listens on
ss -tlnp | grep 11434

# Verify LLM model is present
ollama list
```

## Notes
- Bastion SSM came online ~15min after IAM policy was applied (no restart needed)
- ASG instances updated via Instance Refresh (rolling, zero-downtime)
- Ollama still binds 127.0.0.1 on existing instances — pending Packer fix (see 02-ollama-host-fix.md)