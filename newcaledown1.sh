#!/bin/bash

cluster="my_dev_cluster37"
s3_bucket="nodemode"
current_date=$(date -d "yesterday" '+%Y-%m-%d')
output_file="services_$current_date.txt"
service_name="$1" 

# Clear previous content of the output file
if [ -z "$service_name" ]; then
    echo "No service name provided. Exiting."
    exit 1
fi

# Check if the service exists in the cluster
service_arn=$(aws ecs list-services --cluster "$cluster" | grep "$service_name")

if [ -z "$service_arn" ]; then
    echo "Service $service_name not found in the cluster. Exiting."
    exit 1
fi

# Get the desired count of the provided service
desiredCount=$(aws ecs describe-services --cluster "$cluster" --services "$service_name" --query "services[0].desiredCount" --output text)
if [ "$desiredCount" -eq 1 ]; then
    aws ecs update-service --cluster "$cluster" --service "$service_name" --desired-count 0 --no-cli-pager > /dev/null
    if aws ecs wait services-stable --cluster "$cluster" --services "$service_name"; then
        echo "$service_name scaled down to desired count 0."
    else
        echo "Failed to update the desired count for $service_name"
    fi
else
    echo "Service $service_name already has desired count 0."
fi

# Checking whether duplicate services are uploading or not
if ! grep -qx "$service_name" "$output_file"; then
    echo "$service_name" >> "$output_file"
else            
    echo "Failed to write the $output_file"
fi


# Upload the updated services file to S3
if aws s3 cp "$output_file" "s3://$s3_bucket/$output_file"; then
    echo "File uploaded to S3: $s3_bucket/$output_file"
else
    curl -X POST -H 'Content-type: application/json' --data "{\"text\":\"Service scaling for: \\`$service_name\\` failed to upload file to S3.\"}" "$SLACK_WEBHOOK_URL"
fi









