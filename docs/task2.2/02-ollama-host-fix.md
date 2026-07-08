# Ollama OLLAMA_HOST Fix — Bind to 0.0.0.0

## Problem
Ollama binds to `127.0.0.1:11434` by default — ALB health checks fail,
Flowise on Bastion cannot reach LLM instances through ALB.

## Root Cause
Official Ollama installer creates systemd service without `OLLAMA_HOST` set.
Defaults to loopback-only — rejects all external connections including ALB.

## Fix (packer/scripts/install-ollama.sh)
Added systemd drop-in override after Ollama install:
```bash
sudo mkdir -p /etc/systemd/system/ollama.service.d
sudo tee /etc/systemd/system/ollama.service.d/override.conf > /dev/null <<'EOF'
[Service]
Environment="OLLAMA_HOST=0.0.0.0"
EOF
sudo systemctl daemon-reload
sudo systemctl restart ollama
```

## Steps taken
1. Updated `install-ollama.sh` with drop-in override
2. `packer build ollama-ami.pkr.hcl` → `ami-0709d666a6e964670`
3. Updated `ami_id` in `terraform/terraform.tfvars`
4. `terraform apply` → updated Launch Template
5. `aws autoscaling start-instance-refresh` → rolling instance replacement

## Verify
```bash
# Inside SSM Session Manager on ASG instance:
ss -tlnp | grep 11434
# Expected: *:11434 (not 127.0.0.1:11434)

# From local machine:
aws elbv2 describe-target-health \
  --target-group-arn <ollama-tg-arn> \
  --profile distributed-llm-aws \
  --region eu-central-1
# Expected: State = healthy
```
