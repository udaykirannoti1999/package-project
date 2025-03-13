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

if [ "$desiredCount" -eq 1 ]; then
  # Scale down the service
  aws ecs update-service --cluster "$cluster" --service "$service" --desired-count 0 --no-cli-pager > /dev/null
  aws ecs wait services-stable --cluster "$cluster" --services "$service"

  # Log updated service (Always append even if duplicate)
  echo "$service" >> "$output_file"
  echo "Scaled down and stabilized service: $service"

  # Check if the service is already uploaded to S3
  if ! aws s3api head-object --bucket "$s3_bucket" --key "$output_file" 2>/dev/null || ! grep -q "$service" "$output_file"; then
    # Upload the updated services file to S3
    aws s3 cp "$output_file" "s3://$s3_bucket/$output_file"
    echo "File uploaded to S3: $s3_bucket/$output_file"
  else
    echo "Service $service is already uploaded to S3. Skipping upload."
  fi
else
  echo "Service $service is not running with desired count 1."
fi

echo "Process completed for service: $service."
