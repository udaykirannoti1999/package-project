#!/bin/bash

cluster="my_dev_cluster37"
s3_bucket="nodemode"
current_date=$(date -d "yesterday" '+%Y-%m-%d')
output_file="services_$current_date.txt"
slack_file="slack_alert_$current_date.csv"
service_name="$1"

# Clear previous content of the files
> "$output_file"
> "$slack_file"
echo "Service Name,Previous Desired Count,Updated Desired Count,Current Status" > "$slack_file"

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
previous_count=$(aws ecs describe-services --cluster "$cluster" --services "$service_name" --query "services[0].desiredCount" --output text)

if [ "$previous_count" -eq 1 ]; then
    aws ecs update-service --cluster "$cluster" --service "$service_name" --desired-count 0 --no-cli-pager > /dev/null
    if aws ecs wait services-stable --cluster "$cluster" --services "$service_name"; then
        updated_count=0
        status="✅ Scaled Down"
        echo "$service_name scaled down to desired count 0."
    else
        updated_count=$previous_count
        status="❌ Failed to Scale Down"
    fi
else
    updated_count=$previous_count
    status="ℹ️ Already Scaled Down"
fi

# Checking whether duplicate services are uploading or not
if ! grep -qx "$service_name" "$output_file"; then
    echo "$service_name" >> "$output_file"
    echo "$service_name,$previous_count,$updated_count,$status" >> "$slack_file"
else            
    echo "Failed to write the $output_file"
fi

# Upload the updated services file to S3
if aws s3 cp "$output_file" "s3://$s3_bucket/$output_file"; then
    echo "File uploaded to S3: $s3_bucket/$output_file"
else
    echo "Failed to upload file to S3."
fi

# Send Slack alert with local file link
slack_file_url="file://$(pwd)/$slack_file"
message="Service Scaling Report generated. [Open Report]($slack_file_url)"
payload="{\"text\": \"$message\"}"
curl -X POST -H 'Content-type: application/json' --data "$payload" "$SLACK_WEBHOOK_URL"
echo "Slack alert sent successfully."

