#!/bin/bash

cluster="my_dev_cluster37"
s3_bucket="nodemode"
current_date=$(date '+%Y-%m-%d')
output_file="services_$current_date.txt"

# Check if a service name is provided as an argument
if [ -z "$1" ]; then
  echo "No service name provided."
  exit 1
fi

service="$1"

desiredCount=$(aws ecs describe-services --cluster "$cluster" --services "$service" --query "services[0].desiredCount" --output text)

if [ "$desiredCount" -eq 0 ]; then
  # Scale down the service
  aws ecs update-service --cluster "$cluster" --service "$service" --desired-count 1 --no-cli-pager > /dev/null
  aws ecs wait services-stable --cluster "$cluster" --services "$service"

  # Check if the service is already logged
  if ! grep -qx "$service" "$output_file"; then
    # Log updated service
    echo "$service" >> "$output_file"
    echo "Scaled down and stabilized service: $service"

    # Upload the updated services file to S3
    aws s3 cp "$output_file" "s3://$s3_bucket/$output_file"
    echo "File uploaded to S3: $s3_bucket/$output_file"
  else
    echo "Service $service is already recorded in the file. Skipping upload."
  fi
else
  echo "Service $service is not running with desired count 1."
fi

echo "Process completed for service: $service."
