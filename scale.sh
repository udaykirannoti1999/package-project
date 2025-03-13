#!/bin/bash

cluster="my_dev_cluster37"
s3_bucket="nodemode"
current_date=$(date '+%Y-%m-%d')
output_file="services_$current_date.txt"

# Clear previous content of the output file
> "$output_file"

echo "Listing all services with desired count 0 and saving to $output_file..."

# List all services in the cluster
aws ecs list-services --cluster "$cluster" | awk -F'"' '{print $2}' | rev | awk -F'/' '{print $1}' | rev | grep -v serviceArns > all_services.txt

services=$(cat all_services.txt)

for service in $services; do
  desiredCount=$(aws ecs describe-services --cluster "$cluster" --services "$service" --query "services[0].desiredCount" --output text)

  if [ "$desiredCount" -eq 1 ]; then
    # Update the service to desired count 1
    aws ecs update-service --cluster "$cluster" --service "$service" --desired-count 0 --no-cli-pager > /dev/null
    aws ecs wait services-stable --cluster "$cluster" --services "$service"

    # Log the updated service if not already present
    if ! grep -qx "$service" "$output_file"; then
      echo "$service" >> "$output_file"
      echo "Service $service scaled up to desired count 1."
    fi
  fi

done

# Upload the updated services file to S3 regardless of duplicates
aws s3 cp "$output_file" "s3://$s3_bucket/$output_file"
echo "File uploaded to S3: $s3_bucket/$output_file"

echo "Process completed. Services with desired count 1 saved to $output_file."
