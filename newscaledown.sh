#!/bin/bash

cluster="my_dev_cluster37"
s3_bucket="nodemode"
current_date=$(date '+%Y-%m-%d')
output_file="services_$current_date.txt"
service_name="$1"  # Get the service name passed from Groovy

# Clear previous content of the output file
> "$output_file"

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

  # Log the updated service
  if ! grep -qx "$service_name" "$output_file"; then
    echo "$service_name" >> "$output_file"
    echo "Service $service_name scaled down to desired count 0."
  fi
else
  echo "Service $service_name already has desired count 0."
fi

# Upload the updated services file to S3
aws s3 cp "$output_file" "s3://$s3_bucket/$output_file"
echo "File uploaded to S3: $s3_bucket/$output_file"

echo "Process completed for service: $service_name. Saved to $output_file."
