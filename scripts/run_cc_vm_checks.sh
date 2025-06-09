#!/bin/bash

# set -x
set -e

echo "Waiting for CycleCloud to start"
sudo /opt/cycle_server/cycle_server status
sudo /opt/cycle_server/cycle_server await_startup

echo "Verifying CycleCloud running"
curl -k 'https://localhost/'
curl -k 'https://localhost/health_monitor'

echo "Verifying CycleCloud CLI"
cyclecloud initialize --help

echo "Done"
