#!/bin/bash
# Counts AnythingLLM "sent_chat" events in the last hour from Docker logs
# and publishes the count as a custom CloudWatch metric — this is our
# business-value metric per the mentor's requirement (chat_request/hour, threshold 10)
COUNT=$(docker logs anythingllm --since 1h 2>&1 | grep -c "sent_chat")
aws cloudwatch put-metric-data \
  --namespace "AnythingLLM" \
  --metric-name "chat_request_per_hour" \
  --value "$COUNT" \
  --region eu-central-1
