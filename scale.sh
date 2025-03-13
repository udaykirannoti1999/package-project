#!/bin/bash

# Define your ECS cluster name
cluster="my_dev_cluster37"

# Clear previous services.txt file
> services.txt

echo "Listing all services with desired count 1 and saving to services.txt..."

# List all services in the cluster and save to file
aws ecs list-services --cluster "$cluster" | awk -F'"' '{print $2}' | rev | awk -F'/' '{print $1}' | rev | grep -v serviceArns > all_services.txt

services=$(cat all_services.txt)

pids=()  # Store process IDs

for service in $services; do
  (
    # Get the desired count
    desiredCount=$(aws ecs describe-services --cluster "$cluster" --services "$service" --query "services[0].desiredCount" --output text)

    if [ "$desiredCount" -eq 1 ]; then
      echo "$service" >> services.txt
      echo "Service $service has desired count 1."

      # Scale down the service and wait for stabilization
      aws ecs update-service --cluster "$cluster" --service "$service" --desired-count 0 --no-cli-pager > /dev/null

      aws ecs wait services-stable --cluster "$cluster" --services "$service"

      echo "Scaled down and stabilized service: $service"
    fi
  ) &  # Run in the background

  pids+=("$!")  # Store the process ID

done

# Wait for all background processes to complete
for pid in "${pids[@]}"; do
  wait "$pid"
done

echo "Process completed. Services with desired count 1 saved to services.txt."
