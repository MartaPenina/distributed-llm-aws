# Task 2 — Monitoring & Alerting + LLM Platform Completion

## Priority Order
1. Fix what's blocking end-to-end LLM interaction (unfinished from Task 2.1)
2. AMI Creation (Packer for monitoring host)
3. Web UI working end-to-end with LLM
4. Monitoring Infrastructure (Prometheus, Grafana, CloudWatch)
5. Alerting System
6. CI/CD Integration

---

## PHASE 1 — Complete Task 2.1 blockers (do first)

### 1.1 Fix Ollama OLLAMA_HOST (BLOCKER — web UI can't reach LLM)

**Problem:** Ollama binds to `127.0.0.1` by default — ALB health checks fail,
Flowise can't reach Ollama through ALB.

**Fix:** Add systemd drop-in to `packer/scripts/install-ollama.sh`:
```bash
sudo mkdir -p /etc/systemd/system/ollama.service.d
sudo tee /etc/systemd/system/ollama.service.d/override.conf > /dev/null <<'EOF'
[Service]
Environment="OLLAMA_HOST=0.0.0.0"
EOF
sudo systemctl daemon-reload
sudo systemctl restart ollama
```

**Steps:**
- [ ] Add above block to `install-ollama.sh` (after `curl ollama install`, before `sleep 10`)
- [ ] `packer build ollama-ami.pkr.hcl` → new AMI ID
- [ ] Update `ami_id` in `terraform/terraform.tfvars`
- [ ] `terraform apply` (ASG replaces instances)
- [ ] Verify: `aws elbv2 describe-target-health` shows `healthy`

### 1.2 Fix SSM Session Manager for ASG instances (BLOCKER — no browser SSH)

**Problem:** ASG instances have no IAM instance profile → SSM Agent can't
authenticate → Session Manager shows "Not connected" in AWS Console.

**Current state:** IAM Role + Instance Profile exists only for Bastion.
ASG Launch Template has no `iam_instance_profile` set.

**Fix needed:**
- Add `aws_iam_role.asg` + `aws_iam_role_policy_attachment` (attach
  `AmazonSSMManagedInstanceCore` managed policy) + `aws_iam_instance_profile.asg`
  in `modules/security/main.tf`
- Add `iam_instance_profile` to `aws_launch_template.main` in
  `modules/compute/main.tf`
- `terraform apply` → new Launch Template version → ASG instance refresh

**Verify:** AWS Console → EC2 → Connect → SSM Session Manager → "Connected"

### 1.3 End-to-end LLM test (after 1.1 and 1.2 done)

- [ ] Open `http://<bastion_ip>:3000`
- [ ] Create a Chatflow with Chat Ollama node
- [ ] Set Ollama URL: `http://<alb_dns>:11434`
- [ ] Send a test message → get LLM response
- [ ] Verify response logged in RDS (`SELECT * FROM chat_message`)

---

## PHASE 2 — AMI Creation (Task 2, point 8)

Create a **monitoring host AMI** via Packer:
- `packer/monitoring-ami.pkr.hcl`
- `packer/scripts/install-monitoring.sh` (Prometheus, Grafana, Alertmanager)
- Tags: `Type=monitoring`, build version, date

Existing AMIs to update:
- `ollama-ami.pkr.hcl` — add Grafana Agent (for metrics collection)
- `bastion-ami.pkr.hcl` — review if anything needed

---

## PHASE 3 — Monitoring Infrastructure (Task 2, points 1-4)

Architecture (see diagram):
- **Monitoring Host** in public subnet 2 (with Prometheus + Grafana + Alertmanager)
- **Grafana Agent** on each LLM instance (push metrics to Prometheus)
- **CloudWatch** for ALB, RDS, ASG metrics
- **SNS** for email notifications

### Components to deploy:
- [ ] New EC2 (monitoring host) in public subnet — via Terraform
- [ ] Prometheus (collects metrics from Grafana Agents + CloudWatch exporter)
- [ ] Grafana (dashboards, alert rules)
- [ ] Alertmanager (routing: Slack + email via SNS)
- [ ] Grafana Agent on LLM1 and LLM2 (in existing Ollama AMI)

---

## PHASE 4 — Alerting System (Task 2, point 2)

Alerts to create (Grafana + CloudWatch):
[llm]-[test]-[db]-[high]-[storage]
[llm]-[test]-[db]-[high]-[cpu]
[llm]-[test]-[db]-[high]-[memory]
[llm]-[test]-[ec2]-[low]-[cpu]
[llm]-[test]-[ec2]-[high]-[cpu]
[llm]-[test]-[ec2]-[low]-[memory]
[llm]-[test]-[ec2]-[high]-[memory]
[llm]-[test]-[ec2]-[low]-[disk-space]
[llm]-[test]-[ec2]-[high]-[disk-space]
[llm]-[test]-[elb]-[high]-[host-count]
[llm]-[test]-[elb]-[medium]-[4XX-errors]
[llm]-[test]-[elb]-[medium]-[5XX-errors]
[llm]-[test]-[ec2]-[service]-[service_name]
Notification channels:
- Slack integration via Alertmanager
- Email via SNS → SES/Mail

---

## PHASE 5 — Dashboards (Task 2, point 4)

- [ ] Infrastructure dashboard (CPU, memory, disk, network per host)
- [ ] Service status dashboard (grouped by host type: bastion, LLM, monitoring)
- [ ] LLM performance dashboard (Ollama response time, request count)
- [ ] Database dashboard (RDS CPU, connections, storage)
- [ ] ALB dashboard (4xx, 5xx, healthy host count)

---

## PHASE 6 — CI/CD Integration (Task 2, point 6)

- [ ] Monitoring config as code in Git (Prometheus config, Grafana dashboards as JSON)
- [ ] Packer builds automated (GitHub Actions or manual documented process)
- [ ] `terraform apply` for monitoring host in existing pipeline

---

## Status Summary

| Phase | Status |
|---|---|
| 1.1 Ollama OLLAMA_HOST fix | Not done — BLOCKER |
| 1.2 SSM for ASG instances | Not done — BLOCKER |
| 1.3 End-to-end LLM chat test | Blocked by 1.1 |
| 2. Monitoring AMI | Not started |
| 3. Monitoring Infrastructure | Not started |
| 4. Alerting | Not started |
| 5. Dashboards | Not started |
| 6. CI/CD | Not started |

## Current Architecture

See Task 2.1 for completed infrastructure.
Monitoring host (Phase 2-3) will be added to public subnet 2 (AZ2),
alongside NAT Gateway.
