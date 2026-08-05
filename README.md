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
| Dashboards | Done | 4 Grafana dashboards, all provisioning-as-code: Host Status, Service Status, Application Performance, LLM Model Usage, Database Performance & Health |
| Web Interface for Ollama | Done | AnythingLLM + Ollama 0.3.6 + qwen2.5:3b, served via ALB with a custom HTTPS domain through Cloudflare |
| CI/CD Integration | Skipped (out of scope for this iteration) | — |
| Security | Done | Least-privilege IAM roles; Grafana admin password and AnythingLLM auth token both sourced from SSM Parameter Store (never hardcoded); HTTPS for the web chat interface; RDS storage encrypted |
| AMI Creation (Packer) | Done | bastion and LLM AMIs rebuilt with all fixes baked in; tagged with build date/source/type |
| CloudWatch/Grafana Alerts (13 required) | Done (13/13) | EC2 CPU/memory/disk (high+low), service liveness, RDS CPU/storage/memory, ALB host-count/4xx/5xx, business metric (chat volume) |

## Architecture notes

- **Stable alarm dimensions**: CloudWatch Agent uses `append_dimensions` (`AutoScalingGroupName`) so alarms survive instance replacement instead of breaking when a hostname/IP changes on redeploy.
- **Grafana provisioning path**: datasources and dashboards live under `/etc/grafana-provisioning/` (persistent disk), not `/tmp/` — required for the config to survive a container restart.
- **Notification routing**: two independent alert paths converge on the same Discord channel — CloudWatch alarms via SNS + Lambda, and Grafana alert rules via Grafana's own Alertmanager.
- **HTTPS**: the AnythingLLM chat interface is served over HTTPS via a Cloudflare-proxied custom domain. Grafana (non-standard port) uses the same domain over plain HTTP, since Cloudflare's free tier does not proxy that port.

## Known limitations
- No dedicated usage-analytics panel beyond the existing chat-volume metric on the Application Performance dashboard.
- Grafana HTTPS on its non-standard port would require a Cloudflare Tunnel or an ALB listener with host-based routing on 443 to fully match the chat interface's setup.
