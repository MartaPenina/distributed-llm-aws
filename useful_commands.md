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

# stop and remove the container running the wrong (latest) image — the model data stays safe in the volume
sudo docker stop ollama
sudo docker rm ollama

# start a fresh container using the correct, stable version — same settings as before
sudo docker run -d --name ollama --restart always -p 11434:11434 -e OLLAMA_HOST=0.0.0.0 -v ollama:/root/.ollama ollama/ollama:0.3.6


# ssm session manager
sudo docker exec ollama ollama --version
sudo docker exec ollama ollama list
sudo docker exec ollama ollama ps

# Point 8 AMI Packer

# check if any AMIs already exist from previous builds, and whether they have proper tags
aws ec2 describe-images --owners self --output json

# prometheus url for grafana
http://172.17.0.1:9090

---
# open SSM session on LLM1 or LLM2, then:
# confirm Ollama container, version, model
sudo docker ps
sudo docker exec ollama ollama --version
sudo docker exec ollama ollama list

# confirm nothing loaded in RAM right now (idle state)
sudo docker exec ollama ollama ps

# confirm node_exporter is running and exposing metrics
sudo systemctl status node_exporter
curl -s http://localhost:9100/metrics | head -20

# confirm Grafana Agent is running and successfully pushing (no more warn logs)
sudo systemctl status grafana-agent
sudo journalctl -u grafana-agent --no-pager | tail -10

# check memory usage live
free -h

# bastion
# check all three containers are running
sudo docker ps

# confirm AnythingLLM systemd service enabled at boot
sudo systemctl status anythingllm.service

# confirm Prometheus is receiving remote_write data
sudo docker logs prometheus --tail 20

# check disk usage (confirm 25GB fix worked)
df -h /

# confirm Grafana can see the datasource file (even if provisioning still manual)
sudo docker exec grafana grafana-cli --version

# Web UI (AnythingLLM)
http://distributed-llm-aws-dev-alb-1091450309.eu-central-1.elb.amazonaws.com

# AMI
aws ec2 describe-images --owners self --query 'Images[].[ImageId,Name,CreationDate,Tags]' --output table

# Grafana 
http://distributed-llm-aws-dev-alb-1091450309.eu-central-1.elb.amazonaws.com:3001
# Explore → запит up → показати живі node_exporter, prometheus, alertmanager targets.
# see everything Prometheus knows about (all metric names)
{__name__=~".+"}

# CPU usage per instance
node_cpu_seconds_total

# memory available right now
node_memory_MemAvailable_bytes

# disk space free
node_filesystem_avail_bytes

# network traffic
node_network_receive_bytes_total

# confirm both LLM hosts are reporting (once hostname label is fixed)
up{job="node_exporter"}

# system load average
node_load1


# SNS — підтверджена підписка
aws sns list-subscriptions-by-topic --topic-arn arn:aws:sns:eu-central-1:705505267797:distributed-llm-aws-dev-alerts

# CloudWatch Alarms
aws cloudwatch describe-alarms --alarm-names llm-test-ec2-high-cpu llm-test-ec2-low-cpu

(node_memory_MemAvailable_bytes{instance="${HOSTNAME}"})/ 1024000000


# Checking point 1

# node_exporter/agent reporting with real hostname (not ${HOSTNAME})
bastion
curl -s 'http://localhost:9090/api/v1/query?query=up' — bastion, у пошуку шукати instance="ip-10-0-0-XX" двічі (не ${HOSTNAME})

# Grafana has Prometheus connected automatically (provisioning-as-code)
bastion
sudo cat /etc/grafana-provisioning/datasources/prometheus.yaml — bastion, показує сам provisioning-файл на диску

sudo docker exec grafana cat /etc/grafana/provisioning/datasources/prometheus.yaml — bastion, показує той самий файл вже всередині контейнера Grafana (доказ, що volume-мапінг працює)

http://<alb-dns>:3001 → Connections → Data sources — браузер, Prometheus вже в списку без кліку "Add data source"

http://<alb-dns>:3001 → Explore → запит: up{job="node_exporter"} — браузер, живі дані з обох LLM-серверів на графіку

# Checking Alerts (CloudWatch alarms via Terraform)

aws cloudwatch describe-alarms --alarm-name-prefix llm-test --query 'MetricAlarms[].[AlarmName,StateValue]' --output table — WSL термінал, таблиця всіх 8 alarms з поточним станом

cd terraform && terraform state list | grep cloudwatch_metric_alarm — WSL термінал, доказ що alarms створені через Terraform, а не руками в консолі

# Checking Point 7 (Security — least privilege)

aws iam list-attached-role-policies --role-name distributed-llm-aws-dev-asg-role — WSL термінал, показує тільки мінімально потрібні policy, без зайвих широких дозволів

# Checking Point 8 (AMI Creation)

aws ec2 describe-images --owners self --query 'Images[].[ImageId,Name,CreationDate,Tags]' --output table — WSL термінал, показує нові AMI з сьогоднішньою датою і правильними тегами

# 30.07
# CPU Usage request
100 - (avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# DISK FREE %
# prometheus - mountpoint - shows free space  (ex. 71)
(node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"}) * 100
# on llm servers ssm session manager - shows space usage (ex. 29)
df -h

# RAM FREE %
# % of available RAM — note: no mountpoint needed here, memory isn't split into mount points like disk is
(node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100
# shows total/used/free RAM
free -h
(Знову збігається: free -h показує available: 6.9Gi з total: 7.6Gi, тобто 6.9/7.6 × 100 ≈ 90.8% — і Grafana показує ~90.7-90.8% для обох серверів)

#####

# reinitialize Terraform backend after changing bucket name
terraform init -reconfigure

# check why the AnythingLLM systemd service failed to start
sudo systemctl status anythingllm.service

# restart the AnythingLLM service after a fix
sudo systemctl restart anythingllm.service

# check if the DB password exists in SSM Parameter Store
aws ssm get-parameter --name "/distributed-llm-aws/dev/db_password" --region eu-central-1

# create the missing DB password parameter (encrypted)
aws ssm put-parameter --name "/distributed-llm-aws/dev/db_password" --value "ТВІЙ_ПАРОЛЬ_БД" --type "SecureString" --region eu-central-1

# reload systemd after editing a unit file directly
sudo systemctl daemon-reload
# restart AnythingLLM with the fixed RDS endpoint
sudo systemctl restart anythingllm.service
# confirm it's now running successfully
sudo systemctl status anythingllm.service