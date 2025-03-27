#!/bin/bash

# Kill all nodes
for pid_file in node*.pid; do
    if [ -f "$pid_file" ]; then
        pid=$(cat "$pid_file")
        kill $pid 2>/dev/null
        rm "$pid_file"
        echo "Stopped node with PID $pid"
    fi
done

echo "All cluster nodes stopped." 