#!/bin/bash

service_name=$1
cluster="my_dev_cluster37"
s3_bucket="nodemode"



# Download the scaling file from S3
aws s3 cp s3://$s3_bucket/$filePattern . > /dev/null 2>&1

if [ ! -f "$filePattern" ]; then
  echo "Error: Scaling file not found in S3."
  exit 1
fi

# If no service name is provided, list all services from the file
if [ -z "$service_name" ]; then
    cat "$filePattern"
    exit 0
fi

# Check the desired count of the service
desiredCount=$(aws ecs describe-services --cluster "$cluster" --services "$service_name" --query "services[0].desiredCount" --output text)

if [ "$desiredCount" == "None" ]; then
    echo "Error: Service $service_name not found in the cluster."
    exit 1
fi

if [ "$desiredCount" -eq 0 ]; then
    # Scale the service up to desired count 1
    aws ecs update-service --cluster "$cluster" --service "$service_name" --desired-count 1 --no-cli-pager > /dev/null
    aws ecs wait services-stable --cluster "$cluster" --services "$service_name"
    echo "Service $service_name scaled up to desired count 1."
else
    echo "Service $service_name is already running with desired count $desiredCount."
fi


