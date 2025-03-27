#!/bin/bash

# Create test databases for each node
for i in {1..3}; do
    echo "Creating database xiam_test${i}..."
    createdb xiam_test${i}
done

echo "Created test databases for nodes 1-3" 