#!/bin/bash

# set -x
set -e

echo "Verifying CycleCloud process"
ps -ef | grep jsvc

echo "Waiting for CycleCloud to start"
sudo /opt/cycle_server/cycle_server status
sudo /opt/cycle_server/cycle_server await_startup

echo "Verifying CycleCloud running"
curl -k 'https://localhost/'
curl -k 'https://localhost/health_monitor'

echo "Verifying CycleCloud CLI"
cyclecloud initialize --help | grep "Usage: cyclecloud initialize"

echo "Done"
