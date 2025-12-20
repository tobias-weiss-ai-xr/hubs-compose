#!/bin/bash
# System Test Daemon
# Runs test-system.sh every 5 minutes and logs output

LOGFILE="/var/log/system-test.log"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
TEST_SCRIPT="${SCRIPT_DIR}/test-system.sh"

echo "Starting System Test Daemon at $(date)" >> "$LOGFILE"

while true; do
    echo "--- Test Run Started: $(date) ---" >> "$LOGFILE"
    "$TEST_SCRIPT" >> "$LOGFILE" 2>&1
    echo "--- Test Run Finished: $(date) ---" >> "$LOGFILE"
    echo "" >> "$LOGFILE"
    sleep 300
done
