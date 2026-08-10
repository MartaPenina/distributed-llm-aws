cat > ~/distributed-llm-aws/README.md << 'EOF'
# Task 2 — Monitoring & Alerting System — Final Status

## Overview
Full monitoring, alerting, dashboarding, and security stack for the distributed LLM
AWS environment. Everything is provisioned as code via Packer (AMI baking) and
Terraform (infrastructure + CloudWatch alarms) — a fresh redeploy requires zero
manual configuration.

## Status by requirement

| Requirement | Status | Notes |
|---|---|---|
| Monitoring Infrastructure (Prometheus, Grafana, CloudWatch, SNS) | Done | Prometheus + Grafana on bastion; Grafana Agent on both LLM hosts; CloudWatch Agent on all hosts; SNS topic confirmed subscribed |
| Alerting System (Grafana Alert Rules, Alertmanager, notifications) | Done | Grafana Alertmanager with Discord contact point (webhook from SSM); notification policy routes to Discord; verified end-to-end with a live business-metric alarm |
| Metrics Collection (agents, DB, infra, app-specific, ALB) | Done | node_exporter + Grafana Agent on LLM hosts; PostgreSQL via RDS Enhanced Monitoring; CloudWatch Agent for memory/disk/procstat; ALB 4xx/5xx/host-count |
| Dashboards | Done | 5 Grafana dashboards, all provisioning-as-code: Host Status, Service Status (grouped by server type), Application Performance, LLM Model Usage, Database Performance & Health |
| Web Interface for Ollama | Done | AnythingLLM + Ollama 0.3.6 + qwen2.5:3b, served via an internal ALB, exposed through a custom HTTPS domain on the bastion |
| CI/CD Integration | Done | Pipeline from Task 1 unchanged; all monitoring config (dashboards, Packer scripts, alerts) committed to Git; deployment of Prometheus/Grafana/AnythingLLM/CloudWatch Agent fully automated via Packer + systemd, no manual steps on the host |
| Security | Done | Least-privilege IAM roles; Grafana admin password and AnythingLLM auth token both sourced from SSM Parameter Store (never hardcoded); HTTPS for both the web chat interface and Grafana; RDS storage encrypted |
| AMI Creation (Packer) | Done | bastion and LLM AMIs rebuilt with all fixes baked in; tagged with build date/source/type |
| CloudWatch/Grafana Alerts (13 required) | Done (13/13) | EC2 CPU/memory/disk (high+low), service liveness, RDS CPU/storage/memory, ALB host-count/4xx/5xx, business metric (chat volume) |

## Architecture notes

- **Stable alarm dimensions**: CloudWatch Agent uses `append_dimensions` (`AutoScalingGroupName`) so alarms survive instance replacement instead of breaking when a hostname/IP changes on redeploy.
- **Grafana provisioning path**: datasources and dashboards live under `/etc/grafana-provisioning/` (persistent disk), not `/tmp/` — required for the config to survive a container restart.
- **Notification routing**: two independent alert paths converge on the same Discord channel — CloudWatch alarms via SNS + Lambda, and Grafana alert rules via Grafana's own Alertmanager.
- **HTTPS**: both the AnythingLLM chat interface and Grafana are served over HTTPS via an nginx reverse proxy running on the bastion, with a Let's Encrypt certificate obtained through a Route53 DNS-01 challenge (no Cloudflare, no open port 80). A single certificate covers both domains, and a systemd timer renews it automatically twice a day.

## Known limitations
- No dedicated usage-analytics panel beyond the existing chat-volume metric on the Application Performance dashboard.
- The "LLM Services Status" panel on the Service Status dashboard currently reports a combined process count across LLM1/LLM2 rather than breaking it out per instance — a per-instance dimension split is planned as a follow-up.
EOF