# distributed-llm-aws

## Overview
Secure, scalable AWS infrastructure for running a self-hosted LLM platform
using Ollama with auto-scaling capabilities, connected to PostgreSQL vector database,
accessible via Flowise Web UI.

## Architecture

```
User (Browser)
      │
      ▼
Internet Gateway ──▶ ALB (Load Balancer)
                          │
                ┌─────────┴─────────┐
                ▼                   ▼
    AZ1: Private Subnet     AZ2: Private Subnet
    └── EC2 (ASG)           └── EC2 (ASG)
         └── Ollama               └── Ollama
         └── Flowise              └── Flowise
                │                       │
                └──────────┬────────────┘
                           ▼
                  DB Private Subnet
                  └── RDS PostgreSQL + pgvector

Public Subnets:
├── Bastion Host (AZ1) ← only SSH entry point
└── NAT Gateway (AZ2)  ← outbound internet for private instances
```

## Tech Stack

| Tool | Purpose |
|------|---------|
| Terraform | Infrastructure as Code |
| Ansible | Configuration management |
| Packer | Custom AMI with Ollama pre-installed |
| Ollama | Local LLM server (llama3.1:8b) |
| Flowise | Web UI with PostgreSQL support |
| AWS ASG | Auto Scaling across 2 Availability Zones |
| AWS RDS | PostgreSQL with pgvector extension |
| AWS ALB | Load balancing between LLM instances |

## Project Structure

```
distributed-llm-aws/
├── bootstrap/           # IAM service account setup (run once)
│   └── bootstrap.sh
├── terraform/           # Infrastructure as Code
│   ├── modules/
│   │   ├── networking/  # VPC, subnets, IGW, NAT
│   │   ├── security/    # Security Groups
│   │   ├── compute/     # ASG, Launch Template, ALB
│   │   └── database/    # RDS PostgreSQL
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── versions.tf
├── packer/              # Custom AMI with Ollama + llama3.1:8b
│   ├── ollama-ami.pkr.hcl
│   └── scripts/
│       └── install-ollama.sh
├── ansible/             # Server configuration
│   ├── roles/
│   │   ├── ollama/
│   │   └── flowise/
│   └── playbook.yml
└── docs/                # Architecture and documentation
```

## Quick Start

```bash
# 1. Run bootstrap — creates IAM service account (run once from root)
cd bootstrap && ./bootstrap.sh

# 2. Deploy infrastructure
cd terraform
terraform init
terraform plan
terraform apply

# 3. Configure servers
cd ansible
ansible-playbook playbook.yml
```

## Security Principles

- No credentials in Git — ever
- Bastion is the only public SSH entry point
- LLM instances in private subnets — not accessible from internet
- RDS accessible only from ASG Security Group on port 5432
- NAT Gateway for outbound internet from private instances
- All secrets via environment variables or AWS Secrets Manager

## Prerequisites

- AWS Account with IAM access
- Terraform >= 1.15
- Ansible >= 2.15
- Packer >= 1.10
- AWS CLI v2

## Key Design Decisions

**Why Ollama:** Open-source LLM server, runs llama3.1:8b locally without cloud API costs.

**Why Packer:** Pre-baking 4.9GB model into AMI avoids expensive NAT Gateway data transfer on every ASG scale-out event.

**Why Flowise:** 54k GitHub stars, native PostgreSQL support, Ollama integration, visual agent builder — not a basic chat UI.

**Why RDS separately:** Database lifecycle is independent from compute. Can stop/start RDS without destroying Terraform state.
