# Known Issues / TODO

## Ollama binds to 127.0.0.1 — ALB health checks fail

**Symptom:** ALB Target Group for Ollama (port 11434) shows targets as
`unhealthy` / `Target.FailedHealthChecks`.

**Root cause:** The official Ollama installer creates a systemd service
with no `OLLAMA_HOST` set. Ollama defaults to listening on `127.0.0.1`
only — accepts local connections, rejects everything from the network
(including ALB health checks and Flowise's requests from Bastion).

**Verified fix (manual, on a live instance):**
```bash
sudo mkdir -p /etc/systemd/system/ollama.service.d
sudo tee /etc/systemd/system/ollama.service.d/override.conf > /dev/null <<'EOF'
[Service]
Environment="OLLAMA_HOST=0.0.0.0"
EOF
sudo systemctl daemon-reload
sudo systemctl restart ollama
```

**Not yet done:** bake this into `install-ollama.sh` so every new AMI has
it automatically. Manual fix only survives until ASG replaces the instance.

**Next steps:**
1. Add the systemd drop-in creation to `packer/scripts/install-ollama.sh`
   (after Ollama install, before `sleep 10`)
2. `packer build ollama-ami.pkr.hcl` → new AMI ID
3. Update `ami_id` in `terraform/terraform.tfvars`
4. `terraform apply` (ASG will replace instances with the new AMI)
5. Verify: `aws elbv2 describe-target-health` shows `healthy`
6. Then: connect Ollama to Flowise via `http://<alb_dns_name>:11434`,
   test end-to-end chat

## Scaling Policy — not benchmarked

Current policy (Target Tracking, CPU 70%) is untouched from Task 1.
Researched but not tested: CPU isn't ideal for LLM inference workloads
(long-running requests, CPU-bound but doesn't reflect concurrency well).
Better fit would be `ALBRequestCountPerTarget` or a custom CloudWatch
metric for concurrent requests — not implemented yet.
