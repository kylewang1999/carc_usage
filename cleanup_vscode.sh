#!/usr/bin/env bash
set -euo pipefail

user="${USER:-$(whoami)}"
host="$(hostname -s)"

echo "Cleaning VS Code server processes for user '$user' on host '$host'..."

# Find PIDs that look like vscode-server or node processes spawned by it
pids=$(
  ps -u "$user" -o pid=,cmd= \
    | grep -E "(vscode-server|node .*vscode|node .*\.vscode-server)" \
    | grep -v "grep" \
    | awk '{print $1}'
)

if [ -z "$pids" ]; then
  echo "No VS Code / vscode-server processes found for user '$user'."
  exit 0
fi

echo "Found PIDs: $pids"
echo "Sending SIGTERM..."
echo "$pids" | xargs -r kill

# Give them a moment to exit gracefully
sleep 2

# Check again; force kill any survivors
pids_left=$(
  ps -u "$user" -o pid=,cmd= \
    | grep -E "(vscode-server|node .*vscode|node .*\.vscode-server)" \
    | grep -v "grep" \
    | awk '{print $1}'
)

if [ -n "$pids_left" ]; then
  echo "Some processes still alive, sending SIGKILL..."
  echo "$pids_left" | xargs -r kill -9
else
  echo "All VS Code processes terminated cleanly."
fi

echo "Optional: remove any temporary VS Code server files (be careful):"
echo "  rm -rf ~/.vscode-server"
