#!/bin/bash

cluster="my_dev_cluster37"
s3_bucket="nodemode"
current_date=$(date '+%Y-%m-%d')
output_file="services_$current_date.txt"

touch "$output_file"

echo "Listing all services with desired count 1..."

aws ecs list-services --cluster "$cluster" | awk -F'"' '{print $2}' | rev | awk -F'/' '{print $1}' | rev | grep -v serviceArns > all_services.txt

services=$(cat all_services.txt)
pids=()

for service in $services; do
  (
    desiredCount=$(aws ecs describe-services --cluster "$cluster" --services "$service" --query "services[0].desiredCount" --output text)

    if [ "$desiredCount" -eq 1 ]; then
     
      #echo "$service" >> "$output_file"

      aws ecs update-service --cluster "$cluster" --service "$service" --desired-count 0 --no-cli-pager > /dev/null
      aws ecs wait services-stable --cluster "$cluster" --services "$service"
      aws s3 cp "$output_file" "s3://$s3_bucket/$output_file"
      
      #echo "File uploaded to S3: $s3_bucket/$output_file"

      echo "Scaled down and stabilized service: $service"
    fi
  ) &
  pids+=("$!")
done

for pid in "${pids[@]}"; do
  wait "$pid"
done

echo "Process completed. Services saved to $output_file."


