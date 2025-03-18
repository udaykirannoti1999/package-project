#!/bin/bash

cluster="my_dev_cluster37"
s3_bucket="nodemode"
current_date=$(date -d "yesterday" '+%Y-%m-%d')
output_file="services_$current_date.txt"
slack_file="alert_json_$current_date.csv"
service_name="$1"
slack_webhook_url=$(aws secretsmanager get-secret-value --secret-id myscreate234 --region ap-south-1 --query SecretString --output text | jq -r '."slack-webhook"')

# Clear previous content of the files
> "$output_file"
> "$slack_file"
echo "Service Name,Previous Desired Count,Updated Desired Count,Current Status" > "$slack_file"

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
previous_count=$(aws ecs describe-services --cluster "$cluster" --services "$service_name" --query "services[0].desiredCount" --output text)

if [ "$previous_count" -eq 1 ]; then
  # Update the service to desired count 0
  aws ecs update-service --cluster "$cluster" --service "$service_name" --desired-count 0 --no-cli-pager > /dev/null
  aws ecs wait services-stable --cluster "$cluster" --services "$service_name"
  updated_count=0
  status="✅ Scaled Down"
else
  updated_count=$previous_count
  status="ℹ️ Already Scaled Down"
fi

# Checking whether duplicate services are uploading or not
if ! grep -qx "$service_name" "$output_file"; then
  echo "$service_name" >> "$output_file"
  echo "$service_name,$previous_count,$updated_count,$status" >> "$slack_file"
  echo "Service $service_name scaled down to desired count 0."
fi

# Upload the updated services file to S3
if aws s3 cp "$output_file" "s3://$s3_bucket/$output_file"; then
  echo "File uploaded to S3: $s3_bucket/$output_file"
  
  # Upload the Slack file to S3 and generate a presigned URL
  if aws s3 cp "$slack_file" "s3://$s3_bucket/$slack_file"; then
    presigned_url=$(aws s3 presign "s3://$s3_bucket/$slack_file")
    echo "Presigned URL generated: $presigned_url"

    # Send notification to Slack
    message="Service Scaling Report generated. [Open Report]($presigned_url)"
    payload="{\"text\": \"$message\"}"
    curl -X POST -H 'Content-type: application/json' --data "$payload" "$slack_webhook_url"
  else
    echo "Failed to upload Slack file to S3."
  fi
else
  echo "Failed to upload file to S3."
fi

echo "Process completed for service: $service_name. Saved to $output_file."
