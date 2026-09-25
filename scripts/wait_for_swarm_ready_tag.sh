#---
# Excerpted from "Engineering Elixir Applications",
# published by The Pragmatic Bookshelf.
# Copyrights apply to this code. It may not be used to create training material,
# courses, books, articles, and the like. Contact us if you are in doubt.
# We make no guarantees that this code is fit for any purpose.
# Visit https://pragprog.com/titles/beamops for more book information.
#---

#!/usr/bin/env bash

# in scripts/wait_for_swarm_ready_tag.sh

while true; do
    MANAGER_IP=$(aws ec2 describe-instances \
        --filters "Name=tag:Name,Values=$INSTANCE_MANAGER_TAG" \
                  "Name=instance-state-name,Values=running" \
                  "Name=tag:SwarmReady,Values=true" \
        --query "Reservations[0].Instances[0].PublicIpAddress" \
        --region "$AWS_REGION" --output text)

    if [ -n "$MANAGER_IP" ] && [ "$MANAGER_IP" != "None" ]; then
        break
    fi
    echo "No instances with SwarmReady tag yet. Retrying in 2 seconds..."
    sleep 2
done