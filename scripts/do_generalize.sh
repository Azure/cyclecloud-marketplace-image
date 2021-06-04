#!/bin/bash
# CRITICAL: DO THIS IMMEDIATELY BEFORE STOPPING CC and BAKING
# Cleanup initial shared cyclecloud creds
# If this step fails, the image may be baked with fixed credetials for ALL USERS!
# Do NOT restart CycleCloud after this step or credentials may be regenerated

echo "Generalizing to prepare for image or container creation."
echo "WARNING: Generalizing CycleCloud will remove all Users and Credentials."
read -r -p "Do you want to continue? [y/N] " response
response=${response,,}    # tolower
if [[ ! "$response" =~ ^(yes|y)$ ]]; then
    echo "Cancelled."
    exit -1
else
    echo "Generalizing..."
fi

set -xe

# purge users and private records
/opt/cycle_server/cycle_server execute 'purge where AdType in { "AuthenticatedUser", "Credential", "AuthenticatedSession", "Application.Task", "Cloud.ChefNodeData", "Event", "ClusterEvent", "NodeEvent", "ClusterMetrics", "NodeMetrics", "SystemAspect", "Application.Tunnel" }'

# create a data record to identify this installation as a Marketplace VM
cat > /opt/cycle_server/config/data/marketplace_site_id.txt <<EOF
AdType = "Application.Setting"
Name = "generalized"
Value = 1
Status = "internal"
EOF

echo "Stopping CycleCloud..."
echo "WARNING: If you restart CycleCloud after this point, re-run generalize.sh before baking an image or container"
/opt/cycle_server/cycle_server stop
/opt/cycle_server/cycle_server status
rm -f /opt/cycle_server/.ssh/*
rm -f /opt/cycle_server/logs/*

