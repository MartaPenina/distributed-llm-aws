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

# bastion
# check container is running and for how long
sudo docker ps

# check AnythingLLM systemd service status
sudo systemctl status anythingllm.service

# check recent application logs for errors
sudo docker logs anythingllm --tail 50 -t

# instances
# check Ollama container is running
sudo docker ps

# list models downloaded to disk
sudo docker exec ollama ollama list

# check which models are CURRENTLY loaded in RAM right now
sudo docker exec ollama ollama ps

# check total and available system memory
free -h

# check Ollama container logs for errors
sudo docker logs ollama --tail 50 -t

curl http://localhost:11434/api/generate -d '{"model": "phi3:mini", "prompt": "Hi", "stream": false}'

# Testing locally 

#  Start just the Ollama container
docker compose up -d

# Confirm it's running
docker compose ps

# Pull a model into the container
docker exec -it ollama-local-test ollama pull phi3:mini

# Which models are on disk
docker exec -it ollama-local-test ollama list

# Live memory usage of the container
docker stats ollama-local-test

# Run it once, watch for crashes
docker exec -it ollama-local-test ollama run phi3:mini

# While step 4 is running, watch memory in a second terminal
docker stats ollama-local-test

# stop and remove the current container (downloaded models stay safe in the volume)
docker compose down

# recreate the container fresh, now with the 7GB memory limit applied
docker compose up -d

# watch live memory usage — leave this running in its own terminal
docker stats ollama-local-test

# check live memory for both containers together — leave this running in its own terminal
docker stats

# pull the smaller model into the already-running Ollama container
docker exec -it ollama-local-test ollama pull qwen2.5:1.5b

# pull the new model to test
docker exec -it ollama-local-test ollama pull qwen2.5:3b

# unload a specific model from RAM immediately (instead of waiting for the default 5-min idle timeout)
# IMPORTANT: run this BEFORE testing a new model, so memory stats reflect only the new model, not both
curl http://localhost:11434/api/generate -d '{"model": "MODEL_NAME_HERE", "keep_alive": 0}'

# remove granite3.3:2b from disk — incompatible with this Ollama version, no point keeping it
docker exec -it ollama-local-test ollama rm granite3.3:2b

# pull the new tested model into the already-running Ollama container
sudo docker exec ollama ollama pull qwen2.5:3b

# remove the old, unsafe model to free disk space
sudo docker exec ollama ollama rm phi3:mini

# confirm only the new model remains
sudo docker exec ollama ollama list

# check what's currently loaded in RAM right now (not just on disk)
sudo docker exec ollama ollama ps

# force unload anything still in memory before the real test
curl http://localhost:11434/api/generate -d '{"model": "MODEL_NAME_HERE", "keep_alive": 0}'

 # show the last 30 log lines from Ollama, with timestamps — used to see exactly what happened at the moment of the crash
sudo docker logs ollama --tail 30 -t

# check which Ollama version is actually running inside this container
sudo docker exec ollama ollama --version

# check which Docker image (and tag/version) this container was built from
sudo docker inspect ollama --format '{{.Config.Image}}'