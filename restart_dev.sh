#!/bin/bash

# Find and kill any process listening on port 4000
echo "Finding and killing any Phoenix processes on port 4000..."
pid=$(lsof -i :4000 | grep LISTEN | awk '{print $2}')
if [ -n "$pid" ]; then
  echo "Killing process $pid"
  kill -9 $pid 2>/dev/null
  echo "Process killed successfully"
else
  echo "No Phoenix process found running on port 4000"
fi

# Start Phoenix server in background
echo "Starting Phoenix server in background..."
cd "$(dirname "$0")" && nohup mix phx.server > logs/phoenix.log 2>&1 &

# Store the PID
echo $! > .phoenix.pid
echo "Phoenix server started with PID: $!"
echo "You can view the logs with: tail -f logs/phoenix.log"
echo "To stop the server later, run: kill -9 $(cat .phoenix.pid)"
echo "Server is available at: http://localhost:4000"
