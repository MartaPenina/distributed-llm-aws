# Useful Commands — distributed-llm-aws

## Ollama Local Testing (Docker)

# Start Ollama locally (same version as AWS)
docker run -d \
  --name ollama-local \
  -p 11434:11434 \
  -v ollama-local:/root/.ollama \
  ollama/ollama:0.3.6

# Check container is running
docker ps

# Pull a model (downloads ~4.9GB, takes time)
docker exec ollama-local ollama pull llama3.1:8b

# List available models
docker exec ollama-local ollama list

# Read logs
docker logs ollama-local --tail 20

# Quick test — check if Ollama is responding
curl http://localhost:11434

# Test inference (send a message to LLM)
curl -s -X POST http://localhost:11434/api/chat \
  -H "Content-Type: application/json" \
  -d '{"model":"llama3.1:8b","messages":[{"role":"user","content":"Make a funny joke about guys on a date"}],"stream":false}'

# Stop and remove container
docker stop ollama-local && docker rm ollama-local

# Remove volume too (deletes downloaded models)
docker volume rm ollama-local

## Bastion — SSH Access and Flowise Management

# Connect to Bastion (with SSH agent forwarding for jumping to private ASG instances from Bastion)
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519

# Verify key is added
ssh-add -l

ssh -A ubuntu@<bastion_public_ip>
# Get current IP: cd terraform && terraform output bastion_public_ip
# Check current IP: curl ifconfig.me

# Check Flowise service status
sudo systemctl status flowise.service
# If "failed" = check docker logs flowise

# Check all running containers on Bastion
sudo docker ps

# Read Flowise logs
sudo docker logs flowise --tail 20

# Restart Flowise manually
sudo systemctl restart flowise.service

## ASG Instance Access (from Bastion)

# Get current ASG instance IPs (run locally, not on Bastion)
aws ec2 describe-instances \
  --filters "Name=instance-state-name,Values=running" \
    "Name=tag:Name,Values=distributed-llm-aws-dev-asg-instance" \
  --query 'Reservations[*].Instances[*].PrivateIpAddress' \
  --output table \
  --profile distributed-llm-aws \
  --region eu-central-1

# SSH jump from Bastion to ASG instance
ssh ubuntu@<asg_private_ip>

# Check Ollama on ASG instance
sudo docker ps
sudo docker exec ollama ollama list
sudo docker exec ollama ollama run llama3.1:8b "Make a funny joke about Erasmus party(do not mention story about ladder)"
sudo docker logs ollama --tail 20
curl -s http://localhost:11434/api/tags

## Diagnosing "Web UI not working" (via ALB)

# Check Target Health for Flowise (run locally, not in SSM)
aws elbv2 describe-target-health \
  --target-group-arn arn:aws:elasticloadbalancing:eu-central-1:705505267797:targetgroup/distributed-llm-aws-dev-tg/13f8e423f1c7fd84

# Check Target Health for Ollama (external ALB)
aws elbv2 describe-target-health \
  --target-group-arn arn:aws:elasticloadbalancing:eu-central-1:705505267797:targetgroup/dev-ollama-tg/46785c4b7100c394

# Check Target Health for Ollama internal ALB
aws elbv2 describe-target-health \
  --target-group-arn arn:aws:elasticloadbalancing:eu-central-1:705505267797:targetgroup/dev-ollama-int-tg/0e4b82cfdabbfab3

# Connect to bastion via SSM
aws ssm start-session --target i-00b744866ea3e26ba

# Check Flowise container status
sudo docker ps

# Check Flowise logs
sudo docker logs flowise --tail 50

# Check Flowise root path (used by ALB health check)
curl -v http://localhost:3000/

# Check Flowise health endpoint (may require auth — expect 401)
curl -v http://localhost:3000/api/v1/health

# Connect to ASG instance via SSM
aws ssm start-session --target <asg-instance-id>

# Check Ollama on ASG instance
sudo docker ps
sudo docker exec ollama ollama list
sudo docker logs ollama --tail 50
curl -s http://localhost:11434/api/tags

# From bastion — check Flowise → Ollama path via internal ALB
curl -v http://<ollama_internal_alb_dns>:11434/api/tags

# Test full path through external ALB
curl -v http://<alb_dns_name>/


# bastion
sudo docker logs flowise --tail 50

# asg instances
sudo docker logs ollama --tail 50

# locally
aws elbv2 describe-target-health \
  --target-group-arn arn:aws:elasticloadbalancing:eu-central-1:705505267797:targetgroup/dev-ollama-int-tg/0e4b82cfdabbfab3

# Check Ollama on ASG instance
sudo docker ps
sudo docker exec ollama ollama list
sudo docker exec ollama ollama run llama3.1:8b "Make a funny joke about international relationship"
sudo docker logs ollama --tail 20
curl -s http://localhost:11434/api/tags

# AnythingLLM (replaces Flowise on bastion)

# Stop old Flowise (kept for rollback, not removed)
sudo docker stop flowise

# Check AnythingLLM container status

sudo docker ps
sudo docker logs anythingllm --tail 50

# Check AnythingLLM can reach Postgres (RDS)
sudo docker exec anythingllm env | grep DATABASE_URL

# Check AnythingLLM can reach Ollama via internal ALB
curl -v http://internal-dev-ollama-internal-alb-1818075333.eu-central-1.elb.amazonaws.com:11434/api/tags

# Restart AnythingLLM after config change
sudo docker restart anythingllm

# Verify pgvector extension exists on RDS (run from bastion, psql client)
psql "$DATABASE_URL" -c "SELECT * FROM pg_extension WHERE extname = 'vector';"


# 13.07 bastion
sudo systemctl status anythingllm.service
sudo docker ps
sudo docker logs anythingllm --tail 30

# Check if ALB now sees bastion as healthy after AnythingLLM finished startup
aws elbv2 describe-target-health \
  --target-group-arn arn:aws:elasticloadbalancing:eu-central-1:705505267797:targetgroup/distributed-llm-aws-dev-tg/13f8e423f1c7fd84

# Confirm AnythingLLM responds locally on bastion (bypasses ALB entirely)
curl -v http://localhost:3000/