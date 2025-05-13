#!/usr/bin/env python3
"""
Hierarchy API Performance Test Script

This script tests the performance of the XIAM Hierarchy API endpoints with a large
dataset of 125,000+ nodes. It measures response times for various operations including:
- Getting nodes 
- Listing children
- Listing descendants
- Checking access
- Searching nodes

Usage:
    python3 test_hierarchy_performance.py

Requirements:
    pip install requests tabulate statistics matplotlib
"""

import requests
import json
import time
import random
import statistics
from tabulate import tabulate
import argparse
import matplotlib.pyplot as plt
from datetime import datetime
import os

# Configuration
DEFAULT_BASE_URL = "http://localhost:4000/api"
DEFAULT_AUTH_TOKEN = "eyJhbGciOiJIUzI1NiJ9.eyJlbWFpbCI6ImFkbWluQGV4YW1wbGUuY29tIiwiZXhwIjoxNzQ3Njg2NDMwLCJpYXQiOjE3NDcwODE2MzAsInJvbGVfaWQiOjEsInN1YiI6MSwidHlwIjoiYWNjZXNzIn0.GA0bZtQr4AuXw9VyN7ELLjA4bv80u7AFehCKNf_RDz8"  # Replace with a valid token
DEFAULT_RUNS = 5  # Number of times to run each test
DEFAULT_SAMPLE_SIZE = 50  # Number of random nodes to sample for tests

class HierarchyPerformanceTester:
    def __init__(self, base_url, auth_token, runs=DEFAULT_RUNS, sample_size=DEFAULT_SAMPLE_SIZE):
        self.base_url = base_url
        self.auth_token = auth_token
        self.runs = runs
        self.sample_size = sample_size
        self.headers = {
            'Authorization': f'Bearer {auth_token}',
            'Content-Type': 'application/json'
        }
        self.results = {}
        self.node_ids = []
        self.user_ids = []
        
    def run_test(self, name, endpoint, method='GET', payload=None, params=None):
        """Run a test multiple times and collect timing data"""
        times = []
        statuses = []
        data_sizes = []
        
        print(f"Running test: {name}...")
        
        for i in range(self.runs):
            start_time = time.time()
            
            if method == 'GET':
                response = requests.get(f"{self.base_url}{endpoint}", 
                                       headers=self.headers,
                                       params=params)
            elif method == 'POST':
                response = requests.post(f"{self.base_url}{endpoint}", 
                                        headers=self.headers,
                                        json=payload)
            else:
                raise ValueError(f"Unsupported method: {method}")
                
            end_time = time.time()
            execution_time = (end_time - start_time) * 1000  # Convert to ms
            
            times.append(execution_time)
            statuses.append(response.status_code)
            
            try:
                # Try to get content length either from header or by measuring response
                if 'Content-Length' in response.headers:
                    data_size = int(response.headers['Content-Length'])
                else:
                    data_size = len(response.content)
                data_sizes.append(data_size)
            except:
                data_sizes.append(0)
                
            # Add a small delay to avoid overwhelming the server
            time.sleep(0.1)
        
        # Calculate statistics
        avg_time = statistics.mean(times)
        min_time = min(times)
        max_time = max(times)
        median_time = statistics.median(times)
        success_rate = (statuses.count(200) / len(statuses)) * 100
        avg_size = statistics.mean(data_sizes) if data_sizes else 0
        
        self.results[name] = {
            'avg_time': avg_time,
            'min_time': min_time,
            'max_time': max_time,
            'median_time': median_time,
            'success_rate': success_rate,
            'avg_size': avg_size,
            'times': times
        }
        
        print(f"  Average response time: {avg_time:.2f}ms")
        print(f"  Success rate: {success_rate:.2f}%")
        
        return self.results[name]
    
    def collect_sample_nodes(self):
        """Get a sample of node IDs to use for testing"""
        print("Collecting sample nodes...")
        response = requests.get(f"{self.base_url}/hierarchy/nodes", 
                               headers=self.headers)
        
        if response.status_code == 200:
            nodes = response.json().get('data', [])
            # Get a random sample of nodes if there are more than sample_size
            if len(nodes) > self.sample_size:
                self.node_ids = [node['id'] for node in random.sample(nodes, self.sample_size)]
            else:
                self.node_ids = [node['id'] for node in nodes]
            
            print(f"Collected {len(self.node_ids)} sample nodes")
        else:
            print(f"Failed to collect sample nodes: {response.status_code}")
            self.node_ids = []
    
    def collect_sample_users(self):
        """Get a sample of user IDs to use for testing"""
        print("Collecting sample users...")
        response = requests.get(f"{self.base_url}/users", 
                               headers=self.headers)
        
        if response.status_code == 200:
            users = response.json().get('data', [])
            # Get a random sample of users if there are more than sample_size
            if len(users) > self.sample_size:
                self.user_ids = [user['id'] for user in random.sample(users, self.sample_size)]
            else:
                self.user_ids = [user['id'] for user in users]
            
            print(f"Collected {len(self.user_ids)} sample users")
        else:
            print(f"Failed to collect sample users: {response.status_code}")
            self.user_ids = []
    
    def run_all_tests(self):
        """Run all performance tests"""
        self.collect_sample_nodes()
        self.collect_sample_users()
        
        # Base API tests
        self.run_test("List All Nodes", "/hierarchy/nodes")
        # Use the dedicated root nodes endpoint for better performance
        self.run_test("List Root Nodes", "/hierarchy/nodes/roots")
        
        # If we have sample nodes, run tests on them
        if self.node_ids:
            # Get random nodes for testing
            test_nodes = random.sample(self.node_ids, min(10, len(self.node_ids)))
            
            for node_id in test_nodes:
                self.run_test(f"Get Node {node_id}", f"/hierarchy/nodes/{node_id}")
                self.run_test(f"Get Children of Node {node_id}", f"/hierarchy/nodes/{node_id}/children")
                self.run_test(f"Get Descendants of Node {node_id}", f"/hierarchy/nodes/{node_id}/descendants")
            
            # Test search functionality with different terms
            search_terms = ["company", "department", "team", "project"]
            for term in search_terms:
                # The API uses the nodes endpoint with a search parameter
                self.run_test(f"Search Nodes '{term}'", "/hierarchy/nodes", params={"search": term})
            
            # Test access checks if we have user IDs
            if self.user_ids:
                for user_id in random.sample(self.user_ids, min(5, len(self.user_ids))):
                    for node_id in random.sample(self.node_ids, min(5, len(self.node_ids))):
                        self.run_test(
                            f"Check Access User {user_id} to Node {node_id}",
                            f"/hierarchy/check-access",
                            method="POST",
                            payload={"user_id": user_id, "node_id": node_id}
                        )
                
                # Test user's accessible nodes
                for user_id in random.sample(self.user_ids, min(5, len(self.user_ids))):
                    self.run_test(
                        f"List Accessible Nodes for User {user_id}",
                        f"/hierarchy/nodes",
                        params={"accessible_by": user_id}
                    )
        
        return self.results
    
    def print_results(self):
        """Print the test results in a tabular format"""
        if not self.results:
            print("No test results to display")
            return
        
        table_data = []
        for name, result in self.results.items():
            table_data.append([
                name,
                f"{result['avg_time']:.2f}",
                f"{result['median_time']:.2f}",
                f"{result['min_time']:.2f}",
                f"{result['max_time']:.2f}",
                f"{result['success_rate']:.2f}%",
                f"{result['avg_size'] / 1024:.2f} KB" if result['avg_size'] else "N/A"
            ])
        
        headers = ["Test", "Avg Time (ms)", "Median Time (ms)", "Min Time (ms)", 
                  "Max Time (ms)", "Success Rate", "Avg Response Size"]
        
        print("\n=== Performance Test Results ===")
        print(tabulate(table_data, headers=headers, tablefmt="grid"))
    
    def save_results(self, filename=None):
        """Save results to a JSON file"""
        if not filename:
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            filename = f"hierarchy_performance_{timestamp}.json"
        
        with open(filename, 'w') as f:
            json.dump(self.results, f, indent=2)
        
        print(f"Results saved to {filename}")
        return filename
    
    def plot_results(self, filename=None):
        """Generate performance graphs"""
        if not self.results:
            print("No test results to plot")
            return
        
        # Create a bar chart of average response times
        plt.figure(figsize=(12, 8))
        
        # Get top-level tests (not individual node tests)
        main_tests = {k: v for k, v in self.results.items() if not k.startswith("Get Node ") and 
                      not k.startswith("Get Children of Node ") and 
                      not k.startswith("Get Descendants of Node ") and
                      not k.startswith("Check Access User ")}
        
        names = list(main_tests.keys())
        avg_times = [result['avg_time'] for result in main_tests.values()]
        
        plt.bar(names, avg_times)
        plt.xticks(rotation=45, ha='right')
        plt.ylabel('Average Response Time (ms)')
        plt.title('Hierarchy API Performance')
        plt.tight_layout()
        
        if not filename:
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            filename = f"hierarchy_performance_{timestamp}.png"
        
        plt.savefig(filename)
        print(f"Performance chart saved to {filename}")
        
        # Optional: Show the plot
        # plt.show()
        
        return filename

def main():
    parser = argparse.ArgumentParser(description='Test XIAM Hierarchy API performance')
    parser.add_argument('--url', default=DEFAULT_BASE_URL, help=f'Base API URL (default: {DEFAULT_BASE_URL})')
    parser.add_argument('--token', default=DEFAULT_AUTH_TOKEN, help='Authentication token')
    parser.add_argument('--runs', type=int, default=DEFAULT_RUNS, help=f'Number of test runs (default: {DEFAULT_RUNS})')
    parser.add_argument('--sample', type=int, default=DEFAULT_SAMPLE_SIZE, 
                       help=f'Number of nodes to sample (default: {DEFAULT_SAMPLE_SIZE})')
    parser.add_argument('--output', help='Output directory for results (default: current directory)')
    
    args = parser.parse_args()
    
    # Create output directory if specified
    output_dir = args.output or "."
    if not os.path.exists(output_dir):
        os.makedirs(output_dir)
    
    tester = HierarchyPerformanceTester(
        base_url=args.url,
        auth_token=args.token,
        runs=args.runs,
        sample_size=args.sample
    )
    
    try:
        tester.run_all_tests()
        tester.print_results()
        
        # Save results
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        json_file = os.path.join(output_dir, f"hierarchy_performance_{timestamp}.json")
        chart_file = os.path.join(output_dir, f"hierarchy_performance_{timestamp}.png")
        
        tester.save_results(json_file)
        tester.plot_results(chart_file)
        
    except KeyboardInterrupt:
        print("\nTest interrupted by user")
        if tester.results:
            tester.print_results()
    except Exception as e:
        print(f"Error during testing: {e}")

if __name__ == "__main__":
    main()
