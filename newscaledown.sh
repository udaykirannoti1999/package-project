#!/bin/bash

cluster="$2"
service_name="$1"  # service name passed from Groovy
slack_webhook_url=$(aws secretsmanager get-secret-value --secret-id myscreate234  --region ap-south-1 --query SecretString --output text | jq -r '.["slack-webhook"]')

if [ -z "$service_name" ]; then
  echo "No service name provided. Exiting."
  exit 1
fi

echo "Processing service: $service_name"

# Check if the service exists in the cluster
service_arn=$(aws ecs list-services --cluster "$cluster" | grep "$service_name")

if [ -z "$service_arn" ]; then
  echo "Service $service_name not found in the cluster. Exiting."
  exit 1
fi

# Get the desired count of the provided service
desiredCount=$(aws ecs describe-services --cluster "$cluster" --services "$service_name" --query "services[0].desiredCount" --output text)

if [ "$desiredCount" -eq 1 ]; then
  # Update the service to desired count 0
  aws ecs update-service --cluster "$cluster" --service "$service_name" --desired-count 0 --no-cli-pager > /dev/null
  aws ecs wait services-stable --cluster "$cluster" --services "$service_name"
  
  # Logging the result for Jenkins to read
  echo "$service_name scaled down to desired count 0."
else
  echo "Service $service_name already has desired count 0."
fi
