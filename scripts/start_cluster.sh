#!/bin/bash

# Function to check if a port is in use
check_port() {
    local port=$1
    if lsof -i :$port > /dev/null; then
        return 0  # Port is in use
    else
        return 1  # Port is free
    fi
}

# Function to kill process using a port
kill_port() {
    local port=$1
    lsof -ti :$port | xargs kill -9 2>/dev/null
}

# Generate a single cookie for all nodes
CLUSTER_COOKIE=$(mix phx.gen.secret)
export CLUSTER_COOKIE

# Function to start a node
start_node() {
    local node_num=$1
    local port=$((4000 + node_num))
    local node_name="node${node_num}@127.0.0.1"
    local config_file="config/nodes/node${node_num}.exs"
    
    # Check if port is in use
    if check_port $port; then
        echo "Port $port is in use. Attempting to free it..."
        kill_port $port
        sleep 2  # Wait for port to be freed
        if check_port $port; then
            echo "Failed to free port $port. Please check what's using it."
            return 1
        fi
    fi
    
    # Set the environment variables for the node
    export XIAM_NODE_NUM=$node_num
    export CLUSTER_ENABLED=true
    export RELEASE_COOKIE=$CLUSTER_COOKIE
    export ELIXIR_ERL_OPTIONS="-kernel inet_dist_listen_min 9100 inet_dist_listen_max 9105"
    
    # Start the node in the background with specific config
    elixir --name $node_name \
           --cookie $CLUSTER_COOKIE \
           --erl "-kernel inet_dist_listen_min 9100 inet_dist_listen_max 9105" \
           --erl "-kernel inet_dist_use_interface {127,0,0,1}" \
           --erl "-kernel logger_level debug" \
           -S mix phx.server --config $config_file &
    
    # Store the process ID
    echo $! > "node${node_num}.pid"
    
    # Wait for the server to start
    echo "Waiting for node $node_name to start on port $port..."
    for i in {1..30}; do
        if check_port $port; then
            echo "Started node $node_name on port $port"
            # Add a small delay to ensure the node is fully started
            sleep 2
            return 0
        fi
        sleep 1
    done
    
    echo "Failed to start node $node_name on port $port"
    return 1
}

# Kill any existing nodes
echo "Cleaning up existing nodes..."
for pid_file in node*.pid; do
    if [ -f "$pid_file" ]; then
        pid=$(cat "$pid_file")
        kill $pid 2>/dev/null
        rm "$pid_file"
    fi
done

# Kill any processes using our ports
for port in 4001 4002 4003; do
    if check_port $port; then
        echo "Killing process using port $port..."
        kill_port $port
        sleep 2
    fi
done

# Generate node configs
echo "Generating node configurations..."
./scripts/generate_node_configs.sh

# Create test database
echo "Creating test database..."
./scripts/create_test_dbs.sh

# Run migrations and seeds for the database
echo "Running migrations and seeds for xiam_test1..."
export MIX_TEST_PARTITION=1
export XIAM_DATABASE=xiam_test1
MIX_ENV=test mix ecto.migrate -r XIAM.Repo
MIX_ENV=test mix run priv/repo/seeds.exs

# Start three nodes with delays between them
echo "Starting cluster nodes..."
start_node 1 && sleep 10 && \
start_node 2 && sleep 10 && \
start_node 3

echo "Cluster started. Press Ctrl+C to stop all nodes."
echo "Debug: Check the logs for node connection attempts"

# Wait for user input
trap 'kill $(cat node*.pid) 2>/dev/null; rm node*.pid; exit' INT
wait 