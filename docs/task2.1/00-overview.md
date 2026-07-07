# Task 2.1 — LLM Platform Improvements

## Goal
Make the Task 1 infrastructure actually usable: add a Web UI for Ollama,
protect RDS from accidental destruction, add pgvector support, harden
Packer AMIs, and restrict Bastion access to SoftServe IP ranges.

## Status

| Step | Description | Status |
|------|-------------|--------|
| 0 | Create `task2` branch | Done |
| 1 | Test Flowise + PostgreSQL locally via Docker | Done |
| 2 | Decouple RDS from Terraform (prevent_destroy) | In progress |
| 3 | Install pgvector extension on RDS | Not started |
| 4 | Packer: SSM agent, dedicated bastion AMI, SSH key | Not started |
| 5 | Security Group: restrict Bastion to SoftServe IPs | Not started |
| 6 | Deploy Flowise on Bastion (AWS) | Not started |
| 7 | Scaling Policy research (theory) | Not started |
| 8 | End-to-end test | Not started |

## Decisions Log
(filled in as we go)

## Verification
(filled in as we go)

## Links
- Terraform lifecycle: https://developer.hashicorp.com/terraform/language/meta-arguments/lifecycle
- Flowise docs: https://docs.flowiseai.com
- pgvector: https://github.com/pgvector/pgvector
