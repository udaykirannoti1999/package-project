#!/bin/bash

service_name=$1
cluster="my_dev_cluster37"

yesterday= $(date '+%Y-%m-%d')
filePattern="services_${yesterday}.txt"
s3_bucket="nodemode"

if [ -z "$service_name" ]; then
  echo "Error: No service name provided."
  exit 1
fi

aws s3 ls s3://nodemode/

# Download the scaling file from S3
aws s3 cp s3://$s3_bucket/$filePattern . > /dev/null 2>&1

if [ ! -f "$filePattern" ]; then
  echo "Error: Scaling file not found in S3."
  exit 1
fi

# Scale the service up if desired count is 0
if [ "$service_name" != "$filePattern" ]; then
    desiredCount=$(aws ecs describe-services --cluster "$cluster" --services "$service_name" --query "services[0].desiredCount" --output text)

    if [ "$desiredCount" -eq 0 ]; then
        aws ecs update-service --cluster "$cluster" --service "$service_name" --desired-count 1 --no-cli-pager > /dev/null
        aws ecs wait services-stable --cluster "$cluster" --services "$service_name"
        echo "Service $service_name scaled up to desired count 1."
    else
        echo "Service $service_name is already running with desired count $desiredCount."
    fi
fi
