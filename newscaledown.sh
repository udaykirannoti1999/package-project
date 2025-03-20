#!/bin/bash

cluster="$2"
service_name="$1"  # service name passed from Groovy
slack_webhook_url=$(aws secretsmanager get-secret-value --secret-id myscreate234  --region ap-south-1 --query SecretString --output text | jq -r '.["slack-webhook"]')

if [ -z "$service_name" ]; then
  exit 1
fi

# Check if the service exists in the cluster
service_arn=$(aws ecs list-services --cluster "$cluster" | grep "$service_name")

if [ -z "$service_arn" ]; then
  exit 1
fi

# Get the desired count of the provided service
desiredCount=$(aws ecs describe-services --cluster "$cluster" --services "$service_name" --query "services[0].desiredCount" --output text)

if [ "$desiredCount" -eq 1 ]; then
  # Update the service to desired count 0
  aws ecs update-service --cluster "$cluster" --service "$service_name" --desired-count 0 --no-cli-pager > /dev/null
  aws ecs wait services-stable --cluster "$cluster" --services "$service_name"
  
  # Log only the service name for Jenkins to capture
  echo "$service_name"
fi
