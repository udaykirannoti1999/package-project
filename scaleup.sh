#!/bin/bash

service_name=$1
cluster="my_dev_cluster37"

if [ -z "$service_name" ]; then
  echo "Error: No service name provided."
  exit 1
fi

# Scale the service up if desired count is 0
desiredCount=$(aws ecs describe-services --cluster "$cluster" --services "$service_name" --query "services[0].desiredCount" --output text)

if [ "$desiredCount" -eq 0 ]; then
    aws ecs update-service --cluster "$cluster" --service "$service_name" --desired-count 1 --no-cli-pager > /dev/null
    aws ecs wait services-stable --cluster "$cluster" --services "$service_name"
    echo "Service $service_name scaled up to desired count 1."
else
    echo "Service $service_name is already running with desired count $desiredCount."
fi
