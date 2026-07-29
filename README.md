# Task 2 — Monitoring & Alerting — Status (updated after break)

## Context
Infrastructure was destroyed (`terraform destroy`) to save costs.
First step now is `terraform apply`, verify baseline functionality (Web UI, Ollama, bastion monitoring),
and only then continue with the points below.

## Mentor's latest comments (current, relevant)
- Only bastion is connected to Grafana/Prometheus — LLM1/LLM2 are not sending metrics.
- Need to install something on the LLM hosts that lets them communicate with Prometheus/Grafana on bastion.
- Understand how Grafana data sources connect (conceptually).
- Everything should be provisioned as code (datasources, dashboards) — so that on every redeploy
  (3 servers x 5 metrics) nothing needs to be clicked manually.
- Add CloudWatch Agent into Packer (bastion/monitoring host).
- Alerts — via Terraform (aws_cloudwatch_metric_alarm), not through the console.
- Finish points 1, 2, 3, 4; point 5 is already done; point 6 - skip;
  points 7, 8 - finish to completion.

## Status by task point

| # | Point | Status | Done | Remaining |
|---|-------|--------|------|-----------|
| 1 | Monitoring Infrastructure | Partial | Prometheus + Grafana alive on bastion, connected as data source | Grafana Agent on LLM1/LLM2; CloudWatch for DB/ALB; SNS - verify live |
| 2 | Alerting (Grafana Alert Rules, Alertmanager, Slack) | Not started | - | Everything: Alert Rule Evaluation Engine, Alertmanager routing, Slack integration |
| 3 | Metrics Collection | Partial | LLM host metrics partial (only bastion sees itself) | Agent on LLM1/LLM2; PostgreSQL metrics; ALB metrics (4xx/5xx/host count) |
| 4 | Dashboards | Not started | - | Host status dashboard; Service status dashboard (both - provisioning-as-code) |
| 5 | Web UI (Ollama) | Done | AnythingLLM + Ollama 0.3.6 + qwen2.5:3b, stable on both LLM hosts, via ALB | - |
| 6 | CI/CD | Skipped per mentor's instruction | - | - |
| 7 | Security | Partial | SG drift fixed, basic IAM in place | Final least-privilege review after redeploy; IAM role for CloudWatch Agent |
| 8 | AMI Creation | Almost done | Packer: bastion AMI (AnythingLLM+Prometheus+Grafana) and LLM AMI (qwen2.5:3b) rebuilt | Add CloudWatch Agent install into packer scripts for monitoring host |
| - | 13 CloudWatch/Grafana alerts from the list | Not started | 2 EC2 alarms exist (high/low CPU) - check whether they're in Terraform or created manually | Remaining 11 alarms; all - via Terraform |

## Next steps (order)
1. `terraform plan` -> cross-check AMI ID against the latest Packer build -> `terraform apply`.
2. Verify baseline state via SSM: Ollama, Web UI, bastion Grafana/Prometheus.
3. Decide and document the metrics-collection architecture from the LLM hosts (pull vs push) -
   align with existing SG rules for private subnets.
4. Install/configure the agent on LLM1/LLM2, confirm it shows up in Prometheus (`up{job="node_exporter"}`).
5. Move Grafana datasources and dashboards to provisioning-as-code.
6. Add CloudWatch Agent into Packer + check IAM role/instance profile.
7. Move the existing 2 alarms (if created manually) into Terraform, add the remaining 11 + Grafana/Alertmanager/Slack.
8. Final review of Security (7) and AMI (8), close out the task.

## Open questions (need verification/decision)
- SNS subscription: confirmed or not - sources conflict, verify live after apply.
- Whether an IAM instance profile for CloudWatch Agent already exists, or needs to be created from scratch.
- Metrics collection model for LLM hosts: bastion Prometheus scrape (pull) vs Grafana Agent remote_write (push).
