#!/bin/bash

# Find and kill any process listening on port 4000
lsof -i :4000 | grep LISTEN | awk '{print $2}' | xargs kill -9 2>/dev/null || true

# Start Phoenix server
cd "$(dirname "$0")" && mix phx.server
