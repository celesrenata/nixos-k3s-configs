#!/usr/bin/env python3
"""
Kubernetes Cluster Performance Visualization
Colorized display of cluster statistics
"""

import sys
from datetime import datetime

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

def get_status_color(percentage):
    """Return color based on resource usage percentage"""
    if percentage >= 80:
        return Colors.RED
    elif percentage >= 60:
        return Colors.YELLOW
    elif percentage >= 40:
        return Colors.CYAN
    else:
        return Colors.GREEN

def print_header(title):
    """Print a colored header"""
    print(f"\n{Colors.BOLD}{Colors.BLUE}{'='*60}{Colors.END}")
    print(f"{Colors.BOLD}{Colors.WHITE}{title.center(60)}{Colors.END}")
    print(f"{Colors.BOLD}{Colors.BLUE}{'='*60}{Colors.END}")

def print_node_stats():
    """Display node statistics with color coding"""
    print_header("NODE RESOURCE UTILIZATION")
    
    nodes = [
        {"name": "gremlin-1", "cpu_pct": 7, "cpu_cores": "1570m", "mem_pct": 31, "mem_gb": "29GB", "role": "control-plane"},
        {"name": "gremlin-2", "cpu_pct": 11, "cpu_cores": "2420m", "mem_pct": 48, "mem_gb": "45GB", "role": "control-plane"},
        {"name": "gremlin-3", "cpu_pct": 3, "cpu_cores": "706m", "mem_pct": 32, "mem_gb": "30GB", "role": "control-plane"}
    ]
    
    print(f"{Colors.BOLD}{'Node':<12} {'CPU Usage':<15} {'Memory Usage':<15} {'Role':<15}{Colors.END}")
    print(f"{Colors.BLUE}{'-'*60}{Colors.END}")
    
    for node in nodes:
        cpu_color = get_status_color(node["cpu_pct"])
        mem_color = get_status_color(node["mem_pct"])
        
        cpu_bar = create_bar(node["cpu_pct"], cpu_color)
        mem_bar = create_bar(node["mem_pct"], mem_color)
        
        print(f"{Colors.BOLD}{node['name']:<12}{Colors.END} "
              f"{cpu_color}{node['cpu_pct']:>2}% {cpu_bar}{Colors.END} "
              f"{mem_color}{node['mem_pct']:>2}% {mem_bar}{Colors.END} "
              f"{Colors.MAGENTA}{node['role']}{Colors.END}")

def create_bar(percentage, color, width=10):
    """Create a visual bar representation"""
    filled = int(percentage / 10)
    bar = '█' * filled + '░' * (width - filled)
    return f"{color}{bar}{Colors.END}"

def print_top_consumers():
    """Display top resource consumers"""
    print_header("TOP RESOURCE CONSUMERS")
    
    print(f"{Colors.BOLD}{Colors.YELLOW}CPU Intensive Workloads:{Colors.END}")
    cpu_consumers = [
        ("Longhorn Instance Manager", "1879m", 84),
        ("Longhorn Instance Manager", "1031m", 46),
        ("MinIO Operator", "996m", 44),
        ("MinIO Operator", "994m", 44),
        ("Longhorn Instance Manager", "820m", 37),
        ("UniFi Controller", "512m", 23),
        ("MinIO Crawler", "465m", 21)
    ]
    
    for service, cpu, pct in cpu_consumers:
        color = Colors.RED if pct > 70 else Colors.YELLOW if pct > 40 else Colors.GREEN
        bar = create_bar(min(pct, 100), color, 15)
        print(f"  {color}{service:<30}{Colors.END} {color}{cpu:>6}{Colors.END} {bar}")
    
    print(f"\n{Colors.BOLD}{Colors.CYAN}Memory Intensive Workloads:{Colors.END}")
    mem_consumers = [
        ("VM: nixos-nfs", "30.7GB", 100),
        ("VM: ubuntu-nfs", "15.4GB", 50),
        ("VM: rando-nfs", "15.4GB", 50),
        ("Prometheus", "2.1GB", 7),
        ("Longhorn Instance Mgr", "2.0GB", 7),
        ("MinIO Crawler", "1.9GB", 6),
        ("MariaDB", "1.7GB", 6)
    ]
    
    for service, mem, pct in mem_consumers:
        color = Colors.RED if pct > 70 else Colors.YELLOW if pct > 40 else Colors.GREEN
        bar = create_bar(min(pct, 100), color, 15)
        print(f"  {color}{service:<30}{Colors.END} {color}{mem:>7}{Colors.END} {bar}")

def print_cluster_overview():
    """Display cluster overview"""
    print_header("CLUSTER OVERVIEW")
    
    print(f"{Colors.BOLD}Cluster Health:{Colors.END}")
    print(f"  {Colors.GREEN}✓{Colors.END} Control Plane: {Colors.GREEN}Healthy{Colors.END}")
    print(f"  {Colors.GREEN}✓{Colors.END} All Nodes: {Colors.GREEN}Ready{Colors.END}")
    print(f"  {Colors.GREEN}✓{Colors.END} K3s Version: {Colors.CYAN}v1.32.5{Colors.END}")
    
    print(f"\n{Colors.BOLD}Workload Distribution:{Colors.END}")
    print(f"  Total Pods: {Colors.YELLOW}229{Colors.END} ({Colors.GREEN}202 Running{Colors.END}, {Colors.YELLOW}27 Other{Colors.END})")
    print(f"  Active Namespaces: {Colors.CYAN}50+{Colors.END}")
    print(f"  Persistent Volumes: {Colors.MAGENTA}93{Colors.END}")
    print(f"  Persistent Volume Claims: {Colors.MAGENTA}92{Colors.END}")

def print_resource_allocation():
    """Display resource allocation with warnings"""
    print_header("RESOURCE ALLOCATION ANALYSIS")
    
    allocations = [
        {"node": "gremlin-1", "cpu_req": 35, "cpu_lim": 153, "mem_req": 30, "status": "OVERCOMMITTED"},
        {"node": "gremlin-2", "cpu_req": 32, "cpu_lim": 40, "mem_req": 43, "status": "BALANCED"},
        {"node": "gremlin-3", "cpu_req": 36, "cpu_lim": 51, "mem_req": 25, "status": "BALANCED"}
    ]
    
    print(f"{Colors.BOLD}{'Node':<12} {'CPU Req':<10} {'CPU Lim':<10} {'Mem Req':<10} {'Status':<15}{Colors.END}")
    print(f"{Colors.BLUE}{'-'*65}{Colors.END}")
    
    for alloc in allocations:
        cpu_req_color = get_status_color(alloc["cpu_req"])
        cpu_lim_color = Colors.RED if alloc["cpu_lim"] > 100 else get_status_color(alloc["cpu_lim"])
        mem_req_color = get_status_color(alloc["mem_req"])
        status_color = Colors.RED if alloc["status"] == "OVERCOMMITTED" else Colors.GREEN
        
        print(f"{Colors.BOLD}{alloc['node']:<12}{Colors.END} "
              f"{cpu_req_color}{alloc['cpu_req']:>3}%{Colors.END}      "
              f"{cpu_lim_color}{alloc['cpu_lim']:>3}%{Colors.END}      "
              f"{mem_req_color}{alloc['mem_req']:>3}%{Colors.END}      "
              f"{status_color}{alloc['status']}{Colors.END}")

def print_warnings():
    """Display important warnings and recommendations"""
    print_header("WARNINGS & RECOMMENDATIONS")
    
    print(f"{Colors.RED}⚠️  CRITICAL ISSUES:{Colors.END}")
    print(f"  {Colors.RED}•{Colors.END} gremlin-1 CPU limits at {Colors.RED}153%{Colors.END} - Risk of resource contention")
    print(f"  {Colors.YELLOW}•{Colors.END} gremlin-2 memory usage at {Colors.YELLOW}48%{Colors.END} - Higher than other nodes")
    
    print(f"\n{Colors.CYAN}💡 RECOMMENDATIONS:{Colors.END}")
    print(f"  {Colors.GREEN}•{Colors.END} Consider rebalancing memory-intensive workloads from gremlin-2")
    print(f"  {Colors.GREEN}•{Colors.END} Review CPU limit overcommitment on gremlin-1")
    print(f"  {Colors.GREEN}•{Colors.END} Monitor Longhorn storage performance impact")
    print(f"  {Colors.GREEN}•{Colors.END} Consider node affinity rules for VM workloads")

def main():
    """Main visualization function"""
    print(f"{Colors.BOLD}{Colors.MAGENTA}")
    print("╔══════════════════════════════════════════════════════════╗")
    print("║           KUBERNETES CLUSTER PERFORMANCE DASHBOARD        ║")
    print("║                    NixOS K3s Fleet                        ║")
    print("╚══════════════════════════════════════════════════════════╝")
    print(f"{Colors.END}")
    
    print(f"{Colors.CYAN}Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S UTC')}{Colors.END}")
    
    print_cluster_overview()
    print_node_stats()
    print_top_consumers()
    print_resource_allocation()
    print_warnings()
    
    print(f"\n{Colors.BOLD}{Colors.BLUE}{'='*60}{Colors.END}")
    print(f"{Colors.GREEN}✓ Cluster analysis complete{Colors.END}")
    print(f"{Colors.BOLD}{Colors.BLUE}{'='*60}{Colors.END}\n")

if __name__ == "__main__":
    main()
