#!/usr/bin/env python3
"""
Prometheus-based Kubernetes Cluster Historical Visualization
Colorized time-series graphs of cluster performance
"""

import json
import requests
import sys
from datetime import datetime, timedelta
import time

# ANSI color codes
class Colors:
    RED = '\033[91m'
    GREEN = '\033[92m'
    YELLOW = '\033[93m'
    BLUE = '\033[94m'
    MAGENTA = '\033[95m'
    CYAN = '\033[96m'
    WHITE = '\033[97m'
    BOLD = '\033[1m'
    UNDERLINE = '\033[4m'
    END = '\033[0m'
    
    # Background colors
    BG_RED = '\033[101m'
    BG_GREEN = '\033[102m'
    BG_YELLOW = '\033[103m'

def get_prometheus_data(query, hours_back=480):  # 20 days
    """Query Prometheus for historical data"""
    base_url = "http://localhost:9090"
    end_time = int(time.time())
    start_time = end_time - (hours_back * 3600)
    
    params = {
        'query': query,
        'start': start_time,
        'end': end_time,
        'step': '3600'  # 1 hour steps
    }
    
    try:
        response = requests.get(f"{base_url}/api/v1/query_range", params=params, timeout=10)
        if response.status_code == 200:
            return response.json()
        else:
            print(f"Error querying Prometheus: {response.status_code}")
            return None
    except Exception as e:
        print(f"Failed to connect to Prometheus: {e}")
        return None

def get_instant_data(query):
    """Get current instant data from Prometheus"""
    base_url = "http://localhost:9090"
    
    try:
        response = requests.get(f"{base_url}/api/v1/query", params={'query': query}, timeout=10)
        if response.status_code == 200:
            return response.json()
        else:
            return None
    except Exception as e:
        print(f"Failed to get instant data: {e}")
        return None

def create_ascii_graph(values, width=60, height=10):
    """Create ASCII graph with color coding"""
    if not values:
        return ["No data available"]
    
    max_val = max(values) if values else 1
    min_val = min(values) if values else 0
    
    # Normalize values to graph height
    normalized = []
    for val in values:
        if max_val == min_val:
            normalized.append(height // 2)
        else:
            norm_val = int(((val - min_val) / (max_val - min_val)) * (height - 1))
            normalized.append(norm_val)
    
    # Create graph
    graph = []
    for row in range(height - 1, -1, -1):
        line = ""
        for i, norm_val in enumerate(normalized):
            if i < len(normalized):
                if norm_val >= row:
                    # Color based on value
                    original_val = values[i]
                    if original_val >= 80:
                        color = Colors.RED
                    elif original_val >= 60:
                        color = Colors.YELLOW
                    elif original_val >= 40:
                        color = Colors.CYAN
                    else:
                        color = Colors.GREEN
                    line += f"{color}█{Colors.END}"
                else:
                    line += " "
        
        # Add scale
        scale_val = min_val + (row / (height - 1)) * (max_val - min_val)
        graph.append(f"{scale_val:6.1f}│{line}")
    
    # Add time axis
    time_axis = "      └" + "─" * len(normalized)
    graph.append(time_axis)
    
    return graph

def print_header(title):
    """Print a colored header"""
    print(f"\n{Colors.BOLD}{Colors.BLUE}{'='*80}{Colors.END}")
    print(f"{Colors.BOLD}{Colors.WHITE}{title.center(80)}{Colors.END}")
    print(f"{Colors.BOLD}{Colors.BLUE}{'='*80}{Colors.END}")

def visualize_node_cpu_history():
    """Visualize CPU usage history for all nodes"""
    print_header("NODE CPU USAGE HISTORY (20 DAYS)")
    
    # Query for each node
    nodes = ['gremlin-1', 'gremlin-2', 'gremlin-3']
    
    for node in nodes:
        print(f"\n{Colors.BOLD}{Colors.CYAN}📊 {node.upper()} CPU Usage %{Colors.END}")
        
        query = f'100 - (avg by (instance) (irate(node_cpu_seconds_total{{mode="idle",instance=~".*{node}.*"}}[5m])) * 100)'
        data = get_prometheus_data(query)
        
        if data and data.get('status') == 'success' and data['data']['result']:
            values = []
            timestamps = []
            
            for result in data['data']['result']:
                if 'values' in result:
                    for timestamp, value in result['values']:
                        timestamps.append(timestamp)
                        try:
                            values.append(float(value))
                        except (ValueError, TypeError):
                            values.append(0)
            
            if values:
                graph = create_ascii_graph(values, width=60, height=8)
                for line in graph:
                    print(f"  {line}")
                
                avg_cpu = sum(values) / len(values)
                max_cpu = max(values)
                min_cpu = min(values)
                
                print(f"  {Colors.BOLD}Stats:{Colors.END} Avg: {Colors.CYAN}{avg_cpu:.1f}%{Colors.END} | "
                      f"Max: {Colors.RED if max_cpu > 80 else Colors.YELLOW if max_cpu > 60 else Colors.GREEN}{max_cpu:.1f}%{Colors.END} | "
                      f"Min: {Colors.GREEN}{min_cpu:.1f}%{Colors.END}")
            else:
                print(f"  {Colors.YELLOW}No CPU data available for {node}{Colors.END}")
        else:
            print(f"  {Colors.RED}Failed to retrieve CPU data for {node}{Colors.END}")

def visualize_node_memory_history():
    """Visualize memory usage history for all nodes"""
    print_header("NODE MEMORY USAGE HISTORY (20 DAYS)")
    
    nodes = ['gremlin-1', 'gremlin-2', 'gremlin-3']
    
    for node in nodes:
        print(f"\n{Colors.BOLD}{Colors.MAGENTA}💾 {node.upper()} Memory Usage %{Colors.END}")
        
        query = f'(1 - (node_memory_MemAvailable_bytes{{instance=~".*{node}.*"}} / node_memory_MemTotal_bytes{{instance=~".*{node}.*"}})) * 100'
        data = get_prometheus_data(query)
        
        if data and data.get('status') == 'success' and data['data']['result']:
            values = []
            
            for result in data['data']['result']:
                if 'values' in result:
                    for timestamp, value in result['values']:
                        try:
                            values.append(float(value))
                        except (ValueError, TypeError):
                            values.append(0)
            
            if values:
                graph = create_ascii_graph(values, width=60, height=8)
                for line in graph:
                    print(f"  {line}")
                
                avg_mem = sum(values) / len(values)
                max_mem = max(values)
                min_mem = min(values)
                
                print(f"  {Colors.BOLD}Stats:{Colors.END} Avg: {Colors.CYAN}{avg_mem:.1f}%{Colors.END} | "
                      f"Max: {Colors.RED if max_mem > 80 else Colors.YELLOW if max_mem > 60 else Colors.GREEN}{max_mem:.1f}%{Colors.END} | "
                      f"Min: {Colors.GREEN}{min_mem:.1f}%{Colors.END}")
            else:
                print(f"  {Colors.YELLOW}No memory data available for {node}{Colors.END}")
        else:
            print(f"  {Colors.RED}Failed to retrieve memory data for {node}{Colors.END}")

def visualize_pod_count_history():
    """Visualize pod count history"""
    print_header("CLUSTER POD COUNT HISTORY (20 DAYS)")
    
    query = 'sum(kube_pod_info)'
    data = get_prometheus_data(query)
    
    if data and data.get('status') == 'success' and data['data']['result']:
        values = []
        
        for result in data['data']['result']:
            if 'values' in result:
                for timestamp, value in result['values']:
                    try:
                        values.append(float(value))
                    except (ValueError, TypeError):
                        values.append(0)
        
        if values:
            print(f"\n{Colors.BOLD}{Colors.GREEN}🚀 Total Pod Count Over Time{Colors.END}")
            
            # Adjust graph for pod counts (different scale)
            graph = create_ascii_graph(values, width=60, height=8)
            for line in graph:
                print(f"  {line}")
            
            avg_pods = sum(values) / len(values)
            max_pods = max(values)
            min_pods = min(values)
            
            print(f"  {Colors.BOLD}Stats:{Colors.END} Avg: {Colors.CYAN}{avg_pods:.0f} pods{Colors.END} | "
                  f"Max: {Colors.GREEN}{max_pods:.0f} pods{Colors.END} | "
                  f"Min: {Colors.YELLOW}{min_pods:.0f} pods{Colors.END}")
        else:
            print(f"  {Colors.YELLOW}No pod count data available{Colors.END}")
    else:
        print(f"  {Colors.RED}Failed to retrieve pod count data{Colors.END}")

def visualize_cluster_overview():
    """Show current cluster status with Prometheus data"""
    print_header("CURRENT CLUSTER STATUS FROM PROMETHEUS")
    
    # Get current node count
    node_query = 'count(up{job="node-exporter"})'
    node_data = get_instant_data(node_query)
    
    # Get current pod count
    pod_query = 'sum(kube_pod_info)'
    pod_data = get_instant_data(pod_query)
    
    # Get current namespace count
    ns_query = 'count(kube_namespace_info)'
    ns_data = get_instant_data(ns_query)
    
    print(f"\n{Colors.BOLD}📊 Real-time Metrics:{Colors.END}")
    
    if node_data and node_data.get('status') == 'success':
        node_count = node_data['data']['result'][0]['value'][1] if node_data['data']['result'] else 'N/A'
        print(f"  Active Nodes: {Colors.GREEN}{node_count}{Colors.END}")
    
    if pod_data and pod_data.get('status') == 'success':
        pod_count = pod_data['data']['result'][0]['value'][1] if pod_data['data']['result'] else 'N/A'
        print(f"  Total Pods: {Colors.CYAN}{pod_count}{Colors.END}")
    
    if ns_data and ns_data.get('status') == 'success':
        ns_count = ns_data['data']['result'][0]['value'][1] if ns_data['data']['result'] else 'N/A'
        print(f"  Namespaces: {Colors.MAGENTA}{ns_count}{Colors.END}")

def print_legend():
    """Print color legend"""
    print_header("COLOR LEGEND")
    print(f"  {Colors.GREEN}█ Green{Colors.END}  : 0-40%   (Healthy)")
    print(f"  {Colors.CYAN}█ Cyan{Colors.END}   : 40-60%  (Moderate)")
    print(f"  {Colors.YELLOW}█ Yellow{Colors.END} : 60-80%  (High)")
    print(f"  {Colors.RED}█ Red{Colors.END}    : 80-100% (Critical)")

def main():
    """Main visualization function"""
    print(f"{Colors.BOLD}{Colors.MAGENTA}")
    print("╔════════════════════════════════════════════════════════════════════════════════╗")
    print("║                    PROMETHEUS CLUSTER HISTORICAL ANALYSIS                      ║")
    print("║                          NixOS K3s Fleet - 20 Day History                     ║")
    print("╚════════════════════════════════════════════════════════════════════════════════╝")
    print(f"{Colors.END}")
    
    print(f"{Colors.CYAN}Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S UTC')}{Colors.END}")
    print(f"{Colors.YELLOW}Data Source: Prometheus (localhost:9090){Colors.END}")
    
    # Test Prometheus connectivity
    test_data = get_instant_data('up')
    if not test_data:
        print(f"\n{Colors.RED}❌ Cannot connect to Prometheus. Make sure port-forward is running:{Colors.END}")
        print(f"{Colors.YELLOW}kubectl port-forward -n prometheus-service prometheus-prometheus-kube-prometheus-prometheus-0 9090:9090{Colors.END}")
        return
    
    print(f"{Colors.GREEN}✅ Prometheus connection successful{Colors.END}")
    
    visualize_cluster_overview()
    visualize_node_cpu_history()
    visualize_node_memory_history()
    visualize_pod_count_history()
    print_legend()
    
    print(f"\n{Colors.BOLD}{Colors.BLUE}{'='*80}{Colors.END}")
    print(f"{Colors.GREEN}✓ Historical analysis complete{Colors.END}")
    print(f"{Colors.BOLD}{Colors.BLUE}{'='*80}{Colors.END}\n")

if __name__ == "__main__":
    main()
