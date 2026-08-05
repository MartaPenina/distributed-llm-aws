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

# Task 2 — Monitoring & Alerting — Status (updated)

## Context
Infrastructure was redeployed today via Terraform after a full teardown. Two hidden bugs
were found and fixed during verification (Grafana Agent hostname substitution, Grafana
datasource provisioning path). Both fixes were confirmed to survive a full AMI rebuild +
redeploy cycle, proving the "provisioning as code" requirement is met for Point 1.

## Mentor's comments — status against each one

| Mentor's comment | Status |
|---|---|
| Only bastion connected, LLM1/LLM2 not sending metrics | Fixed. Root cause: Grafana Agent needed the `-config.expand-env` startup flag to substitute the real hostname; without it both servers reported under the same placeholder name. Verified live in Prometheus and Grafana Explore — both LLM hosts now show up separately. |
| What to install on LLM hosts so they communicate with Prometheus/Grafana | Already installed (node_exporter + Grafana Agent), now confirmed actually working correctly (not just running). |
| Understand how Grafana data sources connect | Understood and demonstrated: Prometheus now appears automatically in Grafana's Data Sources list (marked "default") on every fresh boot, with zero manual clicks. Root cause of the earlier failure: the provisioning file was written to `/tmp/` (tmpfs, wiped on every new instance) instead of `/etc/` (persistent disk). |
| Provision everything as code so redeploys don't need manual clicking | Confirmed working for datasources. Rebuilt both AMIs twice today and redeployed — the fix persisted automatically both times, with no manual steps. Dashboards (the "3 servers x 5 metrics" part) are not yet provisioned as code — still to do. |
| Add CloudWatch Agent into Packer | Done. Installed via Packer, confirmed it is actually publishing memory and disk metrics to CloudWatch (`CWAgent` namespace, verified with `aws cloudwatch list-metrics`). |
| Alerts via Terraform, not the console | 8 of 13 required alarms written and applied via a reusable `for_each` Terraform pattern (2 EC2 CPU that already existed + 6 new: RDS cpu/storage/memory, ALB host-count/4xx/5xx). Remaining 5 (EC2 memory/disk/service) blocked on a CloudWatch Agent dimension issue — see Open Questions. |
| Finish 1-2-3-4, 5 already done, 6 skip, 7-8 finish | See table below. |

## Status by task point

| # | Point | Status | Done | Remaining |
|---|-------|--------|------|-----------|
| 1 | Monitoring Infrastructure | Done | Prometheus + Grafana alive on bastion; Grafana Agent on both LLM hosts confirmed reporting under real hostnames; datasource provisioning-as-code confirmed working across redeploys | CloudWatch for DB/ALB inside Grafana dashboards (not just alarms); SNS — verify subscription confirmed |
| 2 | Alerting (Grafana Alert Rules, Alertmanager, Slack) | Not started | — | Everything: Alert Rule Evaluation Engine, Alertmanager routing (currently down — `up{job="alertmanager"}=0`), Slack integration |
| 3 | Metrics Collection | Partial | LLM host metrics (CPU/RAM/disk/network) confirmed working via node_exporter + Grafana Agent; CloudWatch Agent confirmed reporting memory/disk | PostgreSQL metrics; ALB metrics inside Grafana (not just CloudWatch alarms) |
| 4 | Dashboards | Not started | — | Host status dashboard; Service status dashboard (both as provisioning-as-code JSON, not manual UI) |
| 5 | Web UI (Ollama) | Done | AnythingLLM + Ollama 0.3.6 + qwen2.5:3b, stable on both LLM hosts, via ALB | — |
| 6 | CI/CD | Skipped per mentor's instruction | — | — |
| 7 | Security | Done | Verified least-privilege IAM: ASG and bastion roles have only the minimum required policies (SSM, CloudWatchAgentServerPolicy) — no broad/admin access | — |
| 8 | AMI Creation | Almost done | Both bastion and LLM AMIs rebuilt today with all fixes baked in (hostname fix, datasource path fix, CloudWatch Agent); confirmed via Instance Refresh that new AMIs apply cleanly | Formal AMI versioning/metadata tags could be more descriptive; monitoring-host-specific AMI not separately built (bastion doubles as monitoring host) |
| — | 13 CloudWatch/Grafana alerts from the list | Partial (8/13) | EC2 cpu high/low; RDS cpu/storage/memory; ALB host-count/4xx/5xx — all via Terraform `for_each`, applied and visible in `aws cloudwatch describe-alarms` | EC2 memory/disk/service (5 remaining) — CloudWatch Agent data confirmed present, but its `host` dimension changes on every instance replacement, so a naive alarm would break on the next redeploy; needs a stable-dimension approach before writing these |

## Next steps (order)
1. Decide how to handle the CloudWatch Agent `host` dimension instability (options: per-instance alarms with a refresh mechanism, or a Lambda/EventBridge-based auto-updater) before writing the last 5 alarms.
2. Investigate why `alertmanager` shows `up=0` in Prometheus — likely a container/network issue on bastion, not yet diagnosed.
3. Move Grafana dashboards to provisioning-as-code: one host-status dashboard (CPU/RAM/disk/network/up per server) and one service-status dashboard.
4. Add PostgreSQL and ALB metrics into Grafana dashboards specifically (CloudWatch alarms for these already exist, but the data isn't visualized in Grafana yet).
5. Point 2: Alertmanager routing config + Slack webhook integration.
6. Final polish on Point 8: AMI tagging/versioning metadata.

## Open questions (need verification/decision)
- CloudWatch Agent metrics use a `host` dimension tied to the instance's hostname, not a stable identifier like `AutoScalingGroupName` — need a plan for alarms to survive instance replacement (ASG scaling, redeploys).
- SNS subscription: confirmed or not — verify live in AWS Console (SNS > Subscriptions).
- Whether to build a dedicated monitoring-host AMI, or continue running Prometheus/Grafana on the bastion host as today.
