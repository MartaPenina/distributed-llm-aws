# Packer AMIs + Security Groups

## What
Two separate Packer templates, hardened for their role:
- `ollama-ami.pkr.hcl` — LLM hosts (Docker, Ollama, llama3.1:8b, SSM Agent)
- `bastion-ami.pkr.hcl` — Bastion (SSM Agent, SSH forwarding, Docker,
  AWS CLI, Flowise systemd service)

## Why separate AMIs
Mentor requirement: each host type should only have what it needs.
Bastion doesn't need Ollama/Docker's LLM stack — smaller attack surface,
cleaner separation of roles.

## SSM Agent fix
Base Ubuntu AMI ships with SSM Agent pre-installed as a snap. Original
script tried `systemctl enable amazon-ssm-agent`, which fails — snap
services don't register under that plain name. Fixed with
`snap start amazon-ssm-agent` + `|| true` on install (tolerate "already
installed").

## Security Group changes
- Bastion SSH: restricted from open `/32` to SoftServe IP ranges +
  personal IP (`bastion_allowed_cidrs`, `list(string)`)
- Bastion: added ingress 3000 (Flowise UI), used for browser access
- RDS SG: added ingress 5432 from Bastion SG (previously ASG-only —
  needed once Flowise moved to Bastion)
- ALB SG: added ingress 11434 (Ollama API, for future direct/ALB access)

## Verify
```bash
aws ec2 describe-images --owners self --profile distributed-llm-aws --region eu-central-1
terraform plan   # should show no unexpected SG diffs
```
