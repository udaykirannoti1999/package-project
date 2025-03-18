#!/bin/bash

cluster="my_dev_cluster37"
s3_bucket="nodemode"
current_date=$(date -d "yesterday" '+%Y-%m-%d')
output_file="services_$current_date.txt"
slack_file="alert_json_$current_date.csv"
slack_webhook_url=$(aws secretsmanager get-secret-value --secret-id myscreate234 --region ap-south-1 --query SecretString --output text | jq -r '."slack-webhook"')

> "$output_file"
> "$slack_file"
echo "Service Name,Previous Desired Count,Updated Desired Count,Current Status" > "$slack_file"

if [ $# -eq 0 ]; then
  echo "No service names provided. Exiting."
  exit 1
fi

for service_name in "$@"
do
  echo "Processing service: $service_name"
  service_arn=$(aws ecs list-services --cluster "$cluster" | grep "$service_name")

  if [ -z "$service_arn" ]; then
    echo "Service $service_name not found. Skipping."
    continue
  fi

  previous_count=$(aws ecs describe-services --cluster "$cluster" --services "$service_name" --query "services[0].desiredCount" --output text)

  if [ "$previous_count" -eq 1 ]; then
    aws ecs update-service --cluster "$cluster" --service "$service_name" --desired-count 0 --no-cli-pager > /dev/null
    aws ecs wait services-stable --cluster "$cluster" --services "$service_name"
    updated_count=0
    status="✅ Scaled Down"
  else
    updated_count=$previous_count
    status="ℹ️ Already Scaled Down"
  fi

  echo "$service_name" >> "$output_file"
  echo "$service_name,$previous_count,$updated_count,$status" >> "$slack_file"

done

if aws s3 cp "$output_file" "s3://$s3_bucket/$output_file"; then
  echo "File uploaded to S3: $s3_bucket/$output_file"
fi

if aws s3 cp "$slack_file" "s3://$s3_bucket/$slack_file"; then
  s3_url="https://$s3_bucket.s3.amazonaws.com/$slack_file"
  payload="{\"text\": \"Service Scaling Report generated. Open Report: $s3_url\"}"
  curl -X POST -H 'Content-type: application/json' --data "$payload" "$slack_webhook_url"
else
  echo "Failed to upload Slack file to S3."
fi

echo "Process completed for all services."
