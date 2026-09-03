#!/bin/bash

TODAY=$(date "+%A %d %B %Y, %H:%M:%S")
MACHINE=$(hostname)
WHO=$(whoami)
UP=$(uptime | sed 's/^ *//')

echo "===================================="
echo "       SYSTEM INFORMATION"
echo "===================================="
printf "%-10s : %s\n" "Date"     "$TODAY"
printf "%-10s : %s\n" "Hostname" "$MACHINE"
printf "%-10s : %s\n" "User"     "$WHO"
printf "%-10s : %s\n" "Uptime"   "$UP"
echo

echo "--- Disk usage ---"
df -h
echo

echo "--- Running processes (first 8) ---"
ps -eo pid,user,%cpu,%mem,comm | head -9
echo

read -p "Directory to save the report in [system-report]: " REPORT_DIR
read -p "File name for the process list [processes.txt]: " REPORT_FILE

REPORT_DIR=${REPORT_DIR:-system-report}
REPORT_FILE=${REPORT_FILE:-processes.txt}

mkdir -p "$REPORT_DIR"
touch "$REPORT_DIR/$REPORT_FILE"

ps aux > "$REPORT_DIR/$REPORT_FILE"

echo
echo "--- Report saved ---"
printf "%-10s : %s\n" "Directory" "$REPORT_DIR"
printf "%-10s : %s\n" "File"      "$REPORT_DIR/$REPORT_FILE"
printf "%-10s : %s\n" "Processes" "$(($(wc -l < "$REPORT_DIR/$REPORT_FILE") - 1))"
echo "Done."
