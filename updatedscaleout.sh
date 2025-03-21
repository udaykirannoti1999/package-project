#!/bin/bash

cluster="my_dev_cluster37"
s3_bucket="nodemode"
current_date=$(date -d "yesterday" '+%Y-%m-%d')
output_file="services_$current_date.txt"
csv_file="alert_$current_date.csv"
service_name="$1"  # service name passed from Groovy
slack_webhook_url=$(aws secretsmanager get-secret-value --secret-id myscreate234 --region ap-south-1 --query SecretString --output text | jq -r '.["slack-webhook"]')

# Clear previous content of the output files
> "$output_file"
> "$csv_file"

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
  echo "Service $service_name scaled down to desired count 0."
fi

# Save the alert information as CSV
if [ ! -f "$csv_file" ]; then
  echo "Service Name,Previous Desired Count,Updated Desired Count,Current Status" > "$csv_file"
fi

echo "$service_name,$previous_count,$updated_count,$status" >> "$csv_file"

# Upload the updated services file and CSV file to S3
if aws s3 cp "$output_file" "s3://$s3_bucket/$output_file" && aws s3 cp "$csv_file" "s3://$s3_bucket/$csv_file"; then
  echo "Files uploaded to S3: $s3_bucket/$output_file and $s3_bucket/$csv_file"

  # Prepare the Slack alert JSON with S3 link
  alert_json=$(cat <<EOF
  {
      "blocks": [
          {
              "type": "section",
              "text": {
                  "type": "mrkdwn",
                  "text": "*🚀 Service Scaling Update*"
              }
          },
          {
              "type": "divider"
          },
          {
              "type": "section",
              "fields": [
                  {
                      "type": "mrkdwn",
                      "text": "*Service Name:* $service_name"
                  },
                  {
                      "type": "mrkdwn",
                      "text": "*Previous Desired Count:* $previous_count"
                  },
                  {
                      "type": "mrkdwn",
                      "text": "*Updated Desired Count:* $updated_count"
                  },
                  {
                      "type": "mrkdwn",
                      "text": "*Current Status:* $status"
                  },
                  {
                      "type": "mrkdwn",
                      "text": "*CSV Report:* https://$s3_bucket.s3.amazonaws.com/$csv_file"
                  }
              ]
          }
      ]
  }
EOF
)

  # Send notification to Slack
  curl -X POST -H 'Content-type: application/json' \
       --data "$alert_json" "$slack_webhook_url"
else
  echo "Failed to upload files to S3."
fi

echo "Process completed for service: $service_name. Saved to $output_file and $csv_file."
