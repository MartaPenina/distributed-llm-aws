#!/bin/bash
# Counts real Ollama "/api/chat" requests in the last 5 minutes from Docker
# logs and publishes the count as a custom CloudWatch metric, tagged with
# this instance's own ID — lets us verify in Grafana whether the internal
# ALB is actually load-balancing chat traffic between LLM1 and LLM2, and
# diagnose slow responses under concurrent load.
TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
INSTANCE_ID=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id)
COUNT=$(docker logs ollama --since 5m 2>&1 | grep -c 'POST.*"/api/chat"')
aws cloudwatch put-metric-data \
  --namespace "OllamaRequests" \
  --metric-name "chat_requests_per_5min" \
  --dimensions InstanceId="$INSTANCE_ID" \
  --value "$COUNT" \
  --region eu-central-1