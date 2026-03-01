#!/usr/bin/env python3

"""
Kubernetes Cluster Showcase - Python Edition
A glamorous, space-efficient display of your 3-node NixOS Kubernetes empire!
"""

import subprocess
import json
import time
import sys
import os
from typing import Dict, List, Tuple, Optional
from dataclasses import dataclass
from datetime import datetime
import textwrap

# Rich formatting and colors
class Colors:
    RED = '\033[0;31m'
    GREEN = '\033[0;32m'
    YELLOW = '\033[1;33m'
    BLUE = '\033[0;34m'
    PURPLE = '\033[0;35m'
    CYAN = '\033[0;36m'
    WHITE = '\033[1;37m'
    BOLD = '\033[1m'
    DIM = '\033[2m'
    BLINK = '\033[5m'
    RESET = '\033[0m'
    BG_RED = '\033[41m'
    BG_GREEN = '\033[42m'
    BG_YELLOW = '\033[43m'
    BG_BLUE = '\033[44m'

class TableFormatter:
    """Clean table formatter that handles ANSI codes properly"""
    
    @staticmethod
    def strip_ansi(text: str) -> str:
        """Remove ANSI escape codes from text"""
        import re
        ansi_escape = re.compile(r'\x1B(?:[@-Z\\-_]|\[[0-?]*[ -/]*[@-~])')
        return ansi_escape.sub('', text)
    
    @staticmethod
    def format_table(rows: List[List[str]], widths: List[int], padding: int = 2) -> List[str]:
        """Format rows into a clean, properly aligned table"""
        formatted_rows = []
        
        for row in rows:
            formatted_row = ""
            for i, cell in enumerate(row):
                if i < len(widths):
                    # Calculate actual display width without ANSI codes
                    clean_cell = TableFormatter.strip_ansi(cell)
                    
                    # Handle truncation if needed
                    if len(clean_cell) > widths[i]:
                        truncated = cell[:widths[i]-3] + "..."
                        clean_truncated = TableFormatter.strip_ansi(truncated)
                        cell_width = len(clean_truncated)
                        display_cell = truncated
                    else:
                        cell_width = len(clean_cell)
                        display_cell = cell
                    
                    # Left align with proper spacing
                    spaces_needed = widths[i] - cell_width + padding
                    formatted_row += display_cell + (" " * spaces_needed)
            
            formatted_rows.append(formatted_row.rstrip())
        
        return formatted_rows
    
    @staticmethod
    def create_columns(left_content: str, right_content: str, total_width: int) -> str:
        """Create two-column layout with proper alignment"""
        left_lines = left_content.strip().split('\n')
        right_lines = right_content.strip().split('\n')
        
        # Calculate column widths
        col_width = (total_width - 4) // 2  # Account for separator
        
        # Pad lines to same length
        max_lines = max(len(left_lines), len(right_lines))
        while len(left_lines) < max_lines:
            left_lines.append("")
        while len(right_lines) < max_lines:
            right_lines.append("")
        
        result = []
        for left, right in zip(left_lines, right_lines):
            # Ensure left column is properly padded
            left_clean = TableFormatter.strip_ansi(left)
            left_padding = col_width - len(left_clean)
            if left_padding > 0:
                left += " " * left_padding
            
            result.append(f"{left}  {right}")
        
        return '\n'.join(result)
    
    @staticmethod
    def create_three_columns(left: str, middle: str, right: str, total_width: int) -> str:
        """Create three-column layout with proper alignment"""
        left_lines = left.strip().split('\n')
        middle_lines = middle.strip().split('\n')
        right_lines = right.strip().split('\n')
        
        # Calculate column widths
        col_width = (total_width - 6) // 3  # Account for separators
        
        # Pad lines to same length
        max_lines = max(len(left_lines), len(middle_lines), len(right_lines))
        for lines in [left_lines, middle_lines, right_lines]:
            while len(lines) < max_lines:
                lines.append("")
        
        result = []
        for l, m, r in zip(left_lines, middle_lines, right_lines):
            # Pad each column
            for content, width in [(l, col_width), (m, col_width)]:
                clean_content = TableFormatter.strip_ansi(content)
                padding = width - len(clean_content)
                if content == l:
                    l = content + (" " * max(0, padding))
                else:
                    m = content + (" " * max(0, padding))
            
            result.append(f"{l} {m} {r}")
        
        return '\n'.join(result)

# Unicode symbols
SYMBOLS = {
    'rocket': '🚀', 'star': '⭐', 'fire': '🔥', 'diamond': '💎',
    'crown': '👑', 'lightning': '⚡', 'gear': '⚙️', 'chart': '📊',
    'shield': '🛡️', 'brain': '🧠', 'heart': '❤️', 'check': '✅',
    'cross': '❌', 'warning': '⚠️', 'info': 'ℹ️', 'cpu': '💻',
    'memory': '🧠', 'storage': '💾', 'network': '🌐', 'pod': '📦',
    'node': '🖥️', 'namespace': '📁', 'service': '🔗', 'volume': '💿'
}

@dataclass
class NodeInfo:
    name: str
    status: str
    cpu_cores: str
    memory: str
    cpu_usage: float = 0.0
    memory_usage: float = 0.0

@dataclass
class NamespaceInfo:
    name: str
    pod_count: int
    status: str = "Active"

@dataclass
class ServiceInfo:
    name: str
    namespace: str
    status: str
    description: str

class KubernetesShowcase:
    def __init__(self):
        self.terminal_width = self._get_terminal_width()
        self.half_width = self.terminal_width // 2 - 2
        self.third_width = self.terminal_width // 3 - 2
        
    def _get_terminal_width(self) -> int:
        """Get terminal width, default to 120 if unable to determine"""
        try:
            return os.get_terminal_size().columns
        except:
            return 120
    
    def _run_kubectl(self, cmd: str) -> str:
        """Execute kubectl command and return output"""
        try:
            # Use full path to kubectl for NixOS
            kubectl_path = "/run/current-system/sw/bin/kubectl"
            result = subprocess.run(f"{kubectl_path} {cmd}", shell=True, 
                                  capture_output=True, text=True, timeout=30)
            return result.stdout.strip() if result.returncode == 0 else ""
        except subprocess.TimeoutExpired:
            return ""
        except Exception:
            return ""
    
    def _create_box(self, content: str, width: int, title: str = "", 
                   color: str = Colors.CYAN) -> str:
        """Create a bordered box with content"""
        lines = content.split('\n')
        box_width = max(width - 2, 20)  # Ensure minimum width
        
        # Top border
        if title:
            title_len = len(title) + 4  # Account for spaces and symbols
            padding = max((box_width - title_len) // 2, 0)
            remaining = max(box_width - padding - title_len, 0)
            top = f"╔{'═' * padding} {title} {'═' * remaining}╗"
        else:
            top = f"╔{'═' * box_width}╗"
        
        # Content lines
        content_lines = []
        for line in lines:
            # Remove ANSI codes for length calculation
            clean_line = self._strip_ansi(line)
            if len(clean_line) > box_width:
                # Truncate if too long
                truncated = line[:box_width-3] + "..."
                clean_truncated = self._strip_ansi(truncated)
                padding = max(box_width - len(clean_truncated), 0)
                content_lines.append(f"║{truncated}{' ' * padding}║")
            else:
                padding = max(box_width - len(clean_line), 0)
                content_lines.append(f"║{line}{' ' * padding}║")
        
        # Bottom border
        bottom = f"╚{'═' * box_width}╝"
        
        return f"{color}{Colors.BOLD}{top}{Colors.RESET}\n" + \
               "\n".join(content_lines) + f"\n{color}{Colors.BOLD}{bottom}{Colors.RESET}"
    
    def _strip_ansi(self, text: str) -> str:
        """Remove ANSI escape codes from text"""
        return TableFormatter.strip_ansi(text)
    
    def _create_progress_bar(self, percentage: float, width: int = 20, 
                           filled_char: str = '█', empty_char: str = '░') -> str:
        """Create a visual progress bar"""
        filled_length = int(width * percentage / 100)
        bar = filled_char * filled_length + empty_char * (width - filled_length)
        
        if percentage < 30:
            color = Colors.GREEN
        elif percentage < 70:
            color = Colors.YELLOW
        else:
            color = Colors.RED
            
        return f"{color}{bar}{Colors.RESET}"
    
    def _animate_text(self, text: str, delay: float = 0.05):
        """Animate text character by character"""
        for char in text:
            print(char, end='', flush=True)
            time.sleep(delay)
        print()
    
    def show_banner(self):
        """Display the main banner"""
        os.system('clear')
        banner_width = min(self.terminal_width, 100)
        
        banner = f"""
{Colors.PURPLE}{Colors.BOLD}{'═' * banner_width}
{' ' * ((banner_width - 50) // 2)}{SYMBOLS['crown']} CELESTIUM KUBERNETES CLUSTER SHOWCASE {SYMBOLS['crown']}
{' ' * ((banner_width - 60) // 2)}{SYMBOLS['fire']} 3-Node NixOS Powerhouse {SYMBOLS['lightning']} Production Ready {SYMBOLS['diamond']}
{'═' * banner_width}{Colors.RESET}
        """
        print(banner)
        time.sleep(2)
    
    def get_node_info(self) -> List[NodeInfo]:
        """Gather node information"""
        nodes = []
        node_output = self._run_kubectl("get nodes -o json")
        
        if node_output:
            try:
                data = json.loads(node_output)
                for item in data.get('items', []):
                    name = item['metadata']['name']
                    status = 'Ready' if any(
                        cond['type'] == 'Ready' and cond['status'] == 'True'
                        for cond in item['status']['conditions']
                    ) else 'NotReady'
                    
                    cpu = item['status']['allocatable'].get('cpu', '0')
                    memory = item['status']['allocatable'].get('memory', '0Ki')
                    
                    nodes.append(NodeInfo(name, status, cpu, memory))
            except json.JSONDecodeError:
                pass
        
        # Get resource usage
        top_output = self._run_kubectl("top nodes --no-headers")
        if top_output:
            for line in top_output.split('\n'):
                parts = line.split()
                if len(parts) >= 5:
                    node_name = parts[0]
                    cpu_usage = float(parts[2].rstrip('%'))
                    memory_usage = float(parts[4].rstrip('%'))
                    
                    for node in nodes:
                        if node.name == node_name:
                            node.cpu_usage = cpu_usage
                            node.memory_usage = memory_usage
        
        return nodes
    
    def get_namespace_info(self) -> List[NamespaceInfo]:
        """Gather namespace information"""
        namespaces = []
        
        # Get all pods grouped by namespace
        pod_output = self._run_kubectl("get pods --all-namespaces --no-headers")
        namespace_counts = {}
        
        if pod_output:
            for line in pod_output.split('\n'):
                if line.strip():
                    parts = line.split()
                    if len(parts) >= 2:
                        ns = parts[0]
                        namespace_counts[ns] = namespace_counts.get(ns, 0) + 1
        
        # Sort by pod count
        sorted_ns = sorted(namespace_counts.items(), key=lambda x: x[1], reverse=True)
        
        for ns_name, pod_count in sorted_ns:
            namespaces.append(NamespaceInfo(ns_name, pod_count))
        
        return namespaces
    
    def get_storage_info(self) -> Dict[str, any]:
        """Gather comprehensive storage information"""
        storage_info = {
            'total_pv': 0,
            'total_pvc': 0,
            'longhorn_volumes': 0,
            'longhorn_capacity_gi': 0,
            'nfs_volumes': 0,
            'nfs_capacity_gi': 0,
            'longhorn_status': 'INACTIVE',
            'nfs_status': 'INACTIVE'
        }
        
        # Get all persistent volumes
        pv_output = self._run_kubectl("get pv --no-headers")
        if pv_output:
            pv_lines = [line for line in pv_output.split('\n') if line.strip()]
            storage_info['total_pv'] = len(pv_lines)
            
            # Parse each PV for storage details
            for line in pv_lines:
                parts = line.split()
                if len(parts) >= 2:
                    capacity_str = parts[1]
                    
                    # Convert capacity to Gi for consistent calculation
                    capacity_gi = 0
                    if 'Ti' in capacity_str:
                        capacity_gi = float(capacity_str.replace('Ti', '')) * 1024
                    elif 'Gi' in capacity_str:
                        capacity_gi = float(capacity_str.replace('Gi', ''))
                    elif 'Mi' in capacity_str:
                        capacity_gi = float(capacity_str.replace('Mi', '')) / 1024
                    
                    # Categorize by storage type
                    if 'longhorn' in line.lower():
                        storage_info['longhorn_volumes'] += 1
                        storage_info['longhorn_capacity_gi'] += capacity_gi
                        storage_info['longhorn_status'] = 'ACTIVE'
                    elif 'nfs' in line.lower():
                        storage_info['nfs_volumes'] += 1
                        storage_info['nfs_capacity_gi'] += capacity_gi
                        storage_info['nfs_status'] = 'ACTIVE'
        
        # Get PVC count
        pvc_output = self._run_kubectl("get pvc --all-namespaces --no-headers")
        if pvc_output:
            pvc_lines = [line for line in pvc_output.split('\n') if line.strip()]
            storage_info['total_pvc'] = len(pvc_lines)
        
        return storage_info
    
    def get_service_status(self) -> List[ServiceInfo]:
        """Check status of key services"""
        services = [
            ("prometheus-service", "prometheus", "📊 Monitoring Stack"),
            ("plex-system", "clusterplex", "⭐ Media Server"),
            ("longhorn-system", "longhorn", "🛡️ Distributed Storage"),
            ("comfyui-service", "comfyui", "🧠 AI/ML Platform"),
            ("ollama-service", "ollama", "🧠 LLM Engine"),
            ("minio-service", "minio", "💎 Object Storage"),
            ("mariadb-service", "mariadb", "⚙️ Database"),
            ("wordpress", "wordpress", "🚀 Web Platform"),
            ("grafana-service", "grafana", "📊 Visualization"),
            ("netbootxyz-service", "netbootxyz", "⚡ Network Boot")
        ]
        
        service_status = []
        for namespace, service_name, description in services:
            pod_output = self._run_kubectl(f"get pods -n {namespace} --no-headers 2>/dev/null")
            status = "Running" if pod_output and "Running" in pod_output else "Not Found"
            service_status.append(ServiceInfo(service_name, namespace, status, description))
        
        return service_status
        """Check status of key services"""
        services = [
            ("prometheus-service", "prometheus", "📊 Monitoring Stack"),
            ("plex-system", "clusterplex", "⭐ Media Server"),
            ("longhorn-system", "longhorn", "🛡️ Distributed Storage"),
            ("comfyui-service", "comfyui", "🧠 AI/ML Platform"),
            ("ollama-service", "ollama", "🧠 LLM Engine"),
            ("minio-service", "minio", "💎 Object Storage"),
            ("mariadb-service", "mariadb", "⚙️ Database"),
            ("wordpress", "wordpress", "🚀 Web Platform"),
            ("grafana-service", "grafana", "📊 Visualization"),
            ("netbootxyz-service", "netbootxyz", "⚡ Network Boot")
        ]
        
        service_status = []
        for namespace, service_name, description in services:
            pod_output = self._run_kubectl(f"get pods -n {namespace} --no-headers 2>/dev/null")
            status = "Running" if pod_output and "Running" in pod_output else "Not Found"
            service_status.append(ServiceInfo(service_name, namespace, status, description))
        
        return service_status
    
    def show_nodes_and_resources(self):
        """Display nodes and resource utilization side by side"""
        print(f"\n{Colors.BLUE}{Colors.BOLD}{'═' * self.terminal_width}")
        print(f"{' ' * (self.terminal_width // 2 - 15)}{SYMBOLS['node']} CLUSTER INFRASTRUCTURE {SYMBOLS['gear']}")
        print(f"{'═' * self.terminal_width}{Colors.RESET}\n")
        
        nodes = self.get_node_info()
        
        # Left side - Node Status (using table format)
        node_rows = []
        node_rows.append([f"{Colors.CYAN}{Colors.BOLD}{SYMBOLS['node']} NODE STATUS{Colors.RESET}", ""])
        node_rows.append(["", ""])  # Empty row
        
        for node in nodes:
            status_color = Colors.GREEN if node.status == 'Ready' else Colors.RED
            status_symbol = SYMBOLS['check'] if node.status == 'Ready' else SYMBOLS['cross']
            
            node_rows.append([f"{status_color}{status_symbol} {Colors.BOLD}{node.name}{Colors.RESET}", ""])
            node_rows.append([f"  Status: {status_color}{node.status}{Colors.RESET}", ""])
            node_rows.append([f"  CPU: {Colors.YELLOW}{node.cpu_cores} cores{Colors.RESET}", ""])
            node_rows.append([f"  Memory: {Colors.BLUE}{node.memory}{Colors.RESET}", ""])
            node_rows.append(["", ""])  # Empty row
        
        left_content = '\n'.join(TableFormatter.format_table(node_rows, [40, 10]))
        
        # Right side - Resource Utilization (using table format)
        resource_rows = []
        resource_rows.append([f"{Colors.YELLOW}{Colors.BOLD}{SYMBOLS['chart']} RESOURCE USAGE{Colors.RESET}", ""])
        resource_rows.append(["", ""])  # Empty row
        
        for node in nodes:
            resource_rows.append([f"{Colors.BOLD}{node.name}:{Colors.RESET}", ""])
            
            # CPU usage bar
            cpu_bar = self._create_progress_bar(node.cpu_usage, 15)
            resource_rows.append([f"  {SYMBOLS['cpu']} CPU: {cpu_bar} {node.cpu_usage:.1f}%", ""])
            
            # Memory usage bar
            mem_bar = self._create_progress_bar(node.memory_usage, 15)
            resource_rows.append([f"  {SYMBOLS['memory']} MEM: {mem_bar} {node.memory_usage:.1f}%", ""])
            resource_rows.append(["", ""])  # Empty row
        
        right_content = '\n'.join(TableFormatter.format_table(resource_rows, [45, 5]))
        
        # Display using simple two-column layout
        two_column_display = TableFormatter.create_columns(left_content, right_content, self.terminal_width)
        print(two_column_display)
        
        time.sleep(3)
    
    def show_namespaces_and_services(self):
        """Display namespaces and services in three columns"""
        print(f"\n{Colors.PURPLE}{Colors.BOLD}{'═' * self.terminal_width}")
        print(f"{' ' * (self.terminal_width // 2 - 20)}{SYMBOLS['namespace']} ECOSYSTEM OVERVIEW {SYMBOLS['service']}")
        print(f"{'═' * self.terminal_width}{Colors.RESET}\n")
        
        namespaces = self.get_namespace_info()
        services = self.get_service_status()
        
        # Left column - Top Namespaces (using table format)
        namespace_rows = []
        namespace_rows.append([f"{Colors.CYAN}{Colors.BOLD}{SYMBOLS['namespace']} TOP NAMESPACES{Colors.RESET}", ""])
        namespace_rows.append(["", ""])  # Empty row
        
        for i, ns in enumerate(namespaces[:10]):
            if ns.pod_count > 20:
                color, symbol = Colors.RED, SYMBOLS['fire']
            elif ns.pod_count > 10:
                color, symbol = Colors.YELLOW, SYMBOLS['star']
            elif ns.pod_count > 5:
                color, symbol = Colors.GREEN, SYMBOLS['diamond']
            else:
                color, symbol = Colors.CYAN, SYMBOLS['pod']
            
            namespace_rows.append([
                f"{color}{symbol} {ns.name}{Colors.RESET}",
                f"{ns.pod_count} pods"
            ])
        
        left_content = '\n'.join(TableFormatter.format_table(namespace_rows, [25, 8]))
        
        # Middle column - Service Status (using table format)
        service_rows = []
        service_rows.append([f"{Colors.GREEN}{Colors.BOLD}{SYMBOLS['service']} KEY SERVICES{Colors.RESET}", ""])
        service_rows.append(["", ""])  # Empty row
        
        for service in services:
            if service.status == "Running":
                status_color, status_symbol = Colors.GREEN, SYMBOLS['check']
            else:
                status_color, status_symbol = Colors.RED, SYMBOLS['cross']
            
            service_rows.append([
                f"{status_color}{status_symbol} {service.description}{Colors.RESET}",
                ""
            ])
        
        middle_content = '\n'.join(TableFormatter.format_table(service_rows, [30, 5]))
        
        # Right column - Cluster Stats (enhanced with storage info)
        total_pods = sum(ns.pod_count for ns in namespaces)
        running_pods = len([line for line in self._run_kubectl("get pods --all-namespaces --no-headers").split('\n') 
                           if 'Running' in line])
        storage_info = self.get_storage_info()
        
        right_content = f"{Colors.YELLOW}{Colors.BOLD}{SYMBOLS['chart']} CLUSTER STATS{Colors.RESET}\n\n"
        right_content += f"{SYMBOLS['namespace']} Namespaces: {Colors.BOLD}{len(namespaces)}{Colors.RESET}\n"
        right_content += f"{SYMBOLS['pod']} Total Pods: {Colors.BOLD}{total_pods}{Colors.RESET}\n"
        right_content += f"{SYMBOLS['check']} Running: {Colors.GREEN}{Colors.BOLD}{running_pods}{Colors.RESET}\n"
        right_content += f"{SYMBOLS['service']} Services: {Colors.BLUE}{Colors.BOLD}{len(services)}{Colors.RESET}\n"
        
        # Add storage summary
        if storage_info['longhorn_status'] == 'ACTIVE':
            longhorn_gb = storage_info['longhorn_capacity_gi']
            right_content += f"{SYMBOLS['storage']} Longhorn: {Colors.PURPLE}{Colors.BOLD}{longhorn_gb:.0f}Gi{Colors.RESET}\n"
        if storage_info['nfs_status'] == 'ACTIVE':
            nfs_gb = storage_info['nfs_capacity_gi']
            right_content += f"{SYMBOLS['volume']} NFS Storage: {Colors.CYAN}{Colors.BOLD}{nfs_gb:.0f}Gi{Colors.RESET}\n"
        
        right_content += f"\n"
        
        # Health percentage
        health_pct = (running_pods / total_pods * 100) if total_pods > 0 else 0
        health_bar = self._create_progress_bar(health_pct, 20)
        right_content += f"{SYMBOLS['heart']} Health: {health_bar}\n"
        right_content += f"           {Colors.BOLD}{health_pct:.1f}%{Colors.RESET}\n\n"
        
        if health_pct > 95:
            right_content += f"{Colors.GREEN}{Colors.BLINK}{SYMBOLS['star']} EXCELLENT! {SYMBOLS['star']}{Colors.RESET}\n"
        elif health_pct > 85:
            right_content += f"{Colors.YELLOW}{SYMBOLS['check']} GOOD HEALTH{Colors.RESET}\n"
        else:
            right_content += f"{Colors.RED}{SYMBOLS['warning']} NEEDS ATTENTION{Colors.RESET}\n"
        
        # Create simple three-column layout
        three_column_display = TableFormatter.create_three_columns(
            left_content, middle_content, right_content, self.terminal_width
        )
        
        print(three_column_display)
        
        time.sleep(4)
    
    def show_storage_and_network(self):
        """Display storage and network information side by side"""
        print(f"\n{Colors.CYAN}{Colors.BOLD}{'═' * self.terminal_width}")
        print(f"{' ' * (self.terminal_width // 2 - 20)}{SYMBOLS['storage']} INFRASTRUCTURE DETAILS {SYMBOLS['network']}")
        print(f"{'═' * self.terminal_width}{Colors.RESET}\n")
        
        # Left side - Storage (comprehensive storage information)
        storage_info = self.get_storage_info()
        
        left_content = f"{Colors.BLUE}{Colors.BOLD}{SYMBOLS['storage']} STORAGE OVERVIEW{Colors.RESET}\n\n"
        left_content += f"{SYMBOLS['volume']} Total Persistent Volumes: {Colors.YELLOW}{Colors.BOLD}{storage_info['total_pv']}{Colors.RESET}\n"
        left_content += f"{SYMBOLS['pod']} Total Volume Claims: {Colors.GREEN}{Colors.BOLD}{storage_info['total_pvc']}{Colors.RESET}\n\n"
        
        # Longhorn storage details
        if storage_info['longhorn_status'] == "ACTIVE":
            longhorn_capacity = f"{storage_info['longhorn_capacity_gi']:.0f}Gi"
            left_content += f"{Colors.GREEN}{SYMBOLS['check']} Longhorn Distributed: {Colors.BOLD}ACTIVE{Colors.RESET}\n"
            left_content += f"  └─ Volumes: {Colors.CYAN}{storage_info['longhorn_volumes']}{Colors.RESET} | Capacity: {Colors.PURPLE}{longhorn_capacity}{Colors.RESET}\n"
        else:
            left_content += f"{Colors.RED}{SYMBOLS['cross']} Longhorn Distributed: {Colors.BOLD}INACTIVE{Colors.RESET}\n"
        
        # NFS storage details
        if storage_info['nfs_status'] == "ACTIVE":
            nfs_capacity = f"{storage_info['nfs_capacity_gi']:.0f}Gi"
            left_content += f"{Colors.GREEN}{SYMBOLS['check']} NFS External Storage: {Colors.BOLD}ACTIVE{Colors.RESET}\n"
            left_content += f"  └─ Volumes: {Colors.CYAN}{storage_info['nfs_volumes']}{Colors.RESET} | Capacity: {Colors.PURPLE}{nfs_capacity}{Colors.RESET}\n"
        else:
            left_content += f"{Colors.RED}{SYMBOLS['cross']} NFS External Storage: {Colors.BOLD}INACTIVE{Colors.RESET}\n"
        
        left_content += f"\n{Colors.DIM}Multi-tier storage architecture{Colors.RESET}\n"
        left_content += f"{Colors.DIM}Distributed + external storage ready{Colors.RESET}\n"
        
        # Right side - Network (simplified)
        ingress_output = self._run_kubectl("get ingress --all-namespaces --no-headers 2>/dev/null")
        svc_output = self._run_kubectl("get svc --all-namespaces --no-headers")
        ingress_count = len(ingress_output.split('\n')) if ingress_output else 0
        svc_count = len(svc_output.split('\n')) if svc_output else 0
        
        flannel_status = "OPERATIONAL" if "Running" in self._run_kubectl("get pods -n kube-flannel -l app=flannel --no-headers 2>/dev/null") else "INACTIVE"
        
        right_content = f"{Colors.GREEN}{Colors.BOLD}{SYMBOLS['network']} NETWORK OVERVIEW{Colors.RESET}\n\n"
        right_content += f"{SYMBOLS['service']} Services: {Colors.BLUE}{Colors.BOLD}{svc_count}{Colors.RESET}\n"
        right_content += f"{SYMBOLS['lightning']} Ingress Routes: {Colors.YELLOW}{Colors.BOLD}{ingress_count}{Colors.RESET}\n\n"
        
        if flannel_status == "OPERATIONAL":
            right_content += f"{Colors.GREEN}{SYMBOLS['check']} Flannel CNI: {Colors.BOLD}ACTIVE{Colors.RESET}\n"
        else:
            right_content += f"{Colors.RED}{SYMBOLS['cross']} Flannel CNI: {Colors.BOLD}INACTIVE{Colors.RESET}\n"
        
        right_content += f"\n{Colors.DIM}Pod-to-pod networking ready{Colors.RESET}\n"
        right_content += f"{Colors.DIM}Overlay network operational{Colors.RESET}\n"
        
        # Display using simple two-column layout
        two_column_display = TableFormatter.create_columns(left_content, right_content, self.terminal_width)
        print(two_column_display)
        
        time.sleep(3)
    
    def show_finale(self):
        """Display the grand finale"""
        print(f"\n{Colors.YELLOW}{Colors.BOLD}{'═' * self.terminal_width}")
        print(f"{' ' * (self.terminal_width // 2 - 25)}{SYMBOLS['crown']} KUBERNETES MASTERY ACHIEVED {SYMBOLS['crown']}")
        print(f"{'═' * self.terminal_width}{Colors.RESET}\n")
        
        finale_text = f"""
{Colors.PURPLE}{Colors.BOLD}{SYMBOLS['fire']} Your 3-node NixOS Kubernetes cluster represents the pinnacle of {SYMBOLS['fire']}
{Colors.PURPLE}{Colors.BOLD}   cloud-native engineering excellence! {Colors.RESET}

{Colors.GREEN}{SYMBOLS['star']} Production-grade infrastructure {SYMBOLS['star']} {Colors.BLUE}{SYMBOLS['brain']} AI/ML capabilities {SYMBOLS['brain']} {Colors.YELLOW}{SYMBOLS['shield']} Enterprise security {SYMBOLS['shield']}{Colors.RESET}

{Colors.CYAN}{Colors.BOLD}From ComfyUI to Prometheus, from Plex to KubeVirt - you've orchestrated{Colors.RESET}
{Colors.CYAN}{Colors.BOLD}a symphony of containerized services that would make any DevOps team proud!{Colors.RESET}

{Colors.RED}{Colors.BLINK}{SYMBOLS['diamond']} CLUSTER SHOWCASE COMPLETE! {SYMBOLS['diamond']}{Colors.RESET}
        """
        
        # Animate the finale text
        for line in finale_text.split('\n'):
            if line.strip():
                print(line.center(self.terminal_width))
                time.sleep(0.5)
        
        print(f"\n{Colors.DIM}Generated on: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}{Colors.RESET}")
        print(f"{Colors.DIM}Cluster: 3-node NixOS Kubernetes with enterprise workloads{Colors.RESET}\n")
    
    def run(self):
        """Run the complete showcase"""
        try:
            # Check if kubectl is available
            kubectl_path = "/run/current-system/sw/bin/kubectl"
            if not os.path.exists(kubectl_path):
                print(f"{Colors.RED}{Colors.BOLD}❌ kubectl not found at {kubectl_path}! Please check installation.{Colors.RESET}")
                sys.exit(1)
            
            self.show_banner()
            self.show_nodes_and_resources()
            self.show_namespaces_and_services()
            self.show_storage_and_network()
            self.show_finale()
            
        except KeyboardInterrupt:
            print(f"\n{Colors.YELLOW}Showcase interrupted by user.{Colors.RESET}")
            sys.exit(0)
        except Exception as e:
            print(f"{Colors.RED}Error during showcase: {e}{Colors.RESET}")
            sys.exit(1)

if __name__ == "__main__":
    showcase = KubernetesShowcase()
    showcase.run()
