# Hierarchy API Performance Testing

This directory contains a script for testing the performance of the XIAM Hierarchy API with large datasets (125,000+ nodes).

## Prerequisites

1. The XIAM application server must be running
2. You need Python 3.7+ installed
3. Install required Python packages:

```bash
pip install requests tabulate statistics matplotlib
```

## Usage

### Basic Usage

Run the script with default settings:

```bash
cd /Users/sander/dev/xiam
./scripts/test_hierarchy_performance.py
```

### Authentication

Before running, update the authentication token in the script or provide it as a command-line argument:

```bash
./scripts/test_hierarchy_performance.py --token YOUR_AUTH_TOKEN
```

### Additional Options

The script supports several command-line arguments:

```
--url BASE_URL       Base API URL (default: http://localhost:4000/api)
--token TOKEN        Authentication token
--runs N             Number of test runs per endpoint (default: 5)
--sample N           Number of nodes to sample for testing (default: 50)
--output DIR         Output directory for results (default: current directory)
```

Example with all options:

```bash
./scripts/test_hierarchy_performance.py \
  --url http://localhost:4000/api \
  --token YOUR_AUTH_TOKEN \
  --runs 10 \
  --sample 100 \
  --output ./performance_results
```

## Understanding Results

The script will:

1. Output detailed timing information for each API call
2. Generate a summary table of all test results
3. Save test results to a JSON file for further analysis
4. Create a bar chart visualization of response times

## What is Being Tested

The script tests the following operations:

1. Listing all nodes and root nodes
2. Retrieving specific nodes by ID
3. Getting children and descendants of nodes
4. Searching nodes by various terms
5. Checking access permissions for users to nodes
6. Listing accessible nodes for various users

## Performance Metrics

For each operation, the script collects:

- Average response time (ms)
- Median response time (ms)
- Minimum and maximum response times
- Success rate
- Average response size (KB)

## Sample Output

```
=== Performance Test Results ===
+-----------------------------------+---------------+------------------+---------------+---------------+--------------+-------------------+
| Test                              | Avg Time (ms) | Median Time (ms) | Min Time (ms) | Max Time (ms) | Success Rate | Avg Response Size |
+===================================+===============+==================+===============+===============+==============+===================+
| List All Nodes                    | 1354.21       | 1245.67          | 987.45        | 1723.89       | 100.00%      | 2465.78 KB        |
+-----------------------------------+---------------+------------------+---------------+---------------+--------------+-------------------+
| List Root Nodes                   | 112.45        | 104.32           | 78.91         | 163.78        | 100.00%      | 34.56 KB          |
+-----------------------------------+---------------+------------------+---------------+---------------+--------------+-------------------+
| Search Nodes 'company'            | 234.67        | 221.34           | 187.45        | 312.67        | 100.00%      | 145.67 KB         |
+-----------------------------------+---------------+------------------+---------------+---------------+--------------+-------------------+
```

## Interpreting Results

- Higher response times indicate potential performance bottlenecks
- Response size gives insight into data volume being transferred
- Differences between average and median times indicate variability
- Compare results before and after caching implementation to see improvements
