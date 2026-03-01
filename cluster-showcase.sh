#!/usr/bin/env bash

# Kubernetes Cluster Showcase Script
# A glamorous display of your 3-node NixOS Kubernetes empire!

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
BOLD='\033[1m'
DIM='\033[2m'
BLINK='\033[5m'
RESET='\033[0m'

# Unicode symbols
ROCKET="🚀"
STAR="⭐"
FIRE="🔥"
DIAMOND="💎"
CROWN="👑"
LIGHTNING="⚡"
GEAR="⚙️"
CHART="📊"
SHIELD="🛡️"
BRAIN="🧠"

# Banner function
show_banner() {
    clear
    echo -e "${PURPLE}${BOLD}"
    echo "╔══════════════════════════════════════════════════════════════════════════════╗"
    echo "║                                                                              ║"
    echo "║  ${CROWN}${YELLOW}  CELESTIUM KUBERNETES CLUSTER SHOWCASE  ${CROWN}${PURPLE}                        ║"
    echo "║                                                                              ║"
    echo "║  ${FIRE} 3-Node NixOS Powerhouse ${FIRE} ${LIGHTNING} 39 Namespaces ${LIGHTNING} ${DIAMOND} 186+ Pods ${DIAMOND}                    ║"
    echo "║                                                                              ║"
    echo "╚══════════════════════════════════════════════════════════════════════════════╝"
    echo -e "${RESET}"
    sleep 2
}

# Animated loading function
loading_animation() {
    local text="$1"
    local duration="$2"
    echo -ne "${CYAN}${BOLD}$text${RESET}"
    for i in {1..10}; do
        echo -ne "${YELLOW}.${RESET}"
        sleep $(echo "scale=1; $duration/10" | bc -l)
    done
    echo -e " ${GREEN}${BOLD}DONE!${RESET}"
}

# Node status with fancy formatting
show_nodes() {
    echo -e "\n${BLUE}${BOLD}╔═══════════════════════════════════════╗"
    echo -e "║  ${GEAR} KUBERNETES NODES STATUS ${GEAR}        ║"
    echo -e "╚═══════════════════════════════════════╝${RESET}\n"
    
    kubectl get nodes -o custom-columns="NAME:.metadata.name,STATUS:.status.conditions[?(@.type=='Ready')].status,ROLES:.metadata.labels.node-role\.kubernetes\.io/master,VERSION:.status.nodeInfo.kubeletVersion,CPU:.status.allocatable.cpu,MEMORY:.status.allocatable.memory" | while IFS= read -r line; do
        if [[ $line == *"Ready"* ]]; then
            echo -e "${GREEN}${BOLD}${STAR} $line${RESET}"
        else
            echo -e "${WHITE}$line${RESET}"
        fi
    done
    sleep 2
}

# Namespace showcase with colors
show_namespaces() {
    echo -e "\n${PURPLE}${BOLD}╔═══════════════════════════════════════╗"
    echo -e "║  ${ROCKET} NAMESPACE ECOSYSTEM ${ROCKET}           ║"
    echo -e "╚═══════════════════════════════════════╝${RESET}\n"
    
    # Get namespace count with animation
    loading_animation "Scanning namespaces" 1.5
    
    local ns_count=$(kubectl get namespaces --no-headers | wc -l)
    echo -e "${YELLOW}${BOLD}Total Namespaces: ${FIRE} $ns_count ${FIRE}${RESET}\n"
    
    # Show top namespaces by pod count
    echo -e "${CYAN}${BOLD}🏆 TOP NAMESPACES BY POD COUNT:${RESET}"
    kubectl get pods --all-namespaces --no-headers | awk '{print $1}' | sort | uniq -c | sort -nr | head -10 | while read count ns; do
        if [[ $count -gt 20 ]]; then
            echo -e "  ${RED}${BOLD}$ns: ${FIRE}$count pods${RESET}"
        elif [[ $count -gt 10 ]]; then
            echo -e "  ${YELLOW}${BOLD}$ns: ${STAR}$count pods${RESET}"
        elif [[ $count -gt 5 ]]; then
            echo -e "  ${GREEN}${BOLD}$ns: ${DIAMOND}$count pods${RESET}"
        else
            echo -e "  ${CYAN}$ns: $count pods${RESET}"
        fi
    done
    sleep 3
}

# Resource utilization with progress bars
show_resources() {
    echo -e "\n${GREEN}${BOLD}╔═══════════════════════════════════════╗"
    echo -e "║  ${CHART} RESOURCE UTILIZATION ${CHART}          ║"
    echo -e "╚═══════════════════════════════════════╝${RESET}\n"
    
    loading_animation "Gathering resource metrics" 2
    
    # CPU Usage
    echo -e "${YELLOW}${BOLD}💻 CPU UTILIZATION:${RESET}"
    kubectl top nodes --no-headers 2>/dev/null | while read node cpu_usage cpu_percent memory_usage memory_percent; do
        cpu_num=$(echo $cpu_percent | sed 's/%//')
        if [[ $cpu_num -lt 20 ]]; then
            bar_color="${GREEN}"
            status="${DIAMOND}"
        elif [[ $cpu_num -lt 50 ]]; then
            bar_color="${YELLOW}"
            status="${STAR}"
        else
            bar_color="${RED}"
            status="${FIRE}"
        fi
        echo -e "  ${BOLD}$node:${RESET} ${bar_color}$cpu_percent${RESET} $status"
    done
    
    echo ""
    
    # Memory Usage
    echo -e "${BLUE}${BOLD}🧠 MEMORY UTILIZATION:${RESET}"
    kubectl top nodes --no-headers 2>/dev/null | while read node cpu_usage cpu_percent memory_usage memory_percent; do
        mem_num=$(echo $memory_percent | sed 's/%//')
        if [[ $mem_num -lt 30 ]]; then
            bar_color="${GREEN}"
            status="${DIAMOND}"
        elif [[ $mem_num -lt 70 ]]; then
            bar_color="${YELLOW}"
            status="${STAR}"
        else
            bar_color="${RED}"
            status="${FIRE}"
        fi
        echo -e "  ${BOLD}$node:${RESET} ${bar_color}$memory_percent${RESET} $status"
    done
    sleep 3
}

# Service showcase
show_services() {
    echo -e "\n${PURPLE}${BOLD}╔═══════════════════════════════════════╗"
    echo -e "║  ${SHIELD} RUNNING SERVICES ${SHIELD}             ║"
    echo -e "╚═══════════════════════════════════════╝${RESET}\n"
    
    loading_animation "Discovering services" 2
    
    echo -e "${CYAN}${BOLD}🎯 KEY SERVICES STATUS:${RESET}"
    
    # Check specific services
    services=(
        "prometheus-service:prometheus:${CHART} Monitoring Stack"
        "plex-system:clusterplex:${STAR} Media Server"
        "longhorn-system:longhorn:${SHIELD} Distributed Storage"
        "comfyui-service:comfyui:${BRAIN} AI/ML Platform"
        "ollama-service:ollama:${BRAIN} LLM Engine"
        "minio-service:minio:${DIAMOND} Object Storage"
        "mariadb-service:mariadb:${GEAR} Database"
        "wordpress:wordpress:${ROCKET} Web Platform"
        "grafana-service:grafana:${CHART} Visualization"
        "netbootxyz-service:netbootxyz:${LIGHTNING} Network Boot"
    )
    
    for service_info in "${services[@]}"; do
        IFS=':' read -r namespace service_name icon description <<< "$service_info"
        if kubectl get pods -n "$namespace" --no-headers 2>/dev/null | grep -q "Running"; then
            echo -e "  ${GREEN}${BOLD}✅ $description${RESET}"
        else
            echo -e "  ${RED}${BOLD}❌ $description${RESET}"
        fi
        sleep 0.3
    done
    sleep 2
}

# Pod health overview
show_pod_health() {
    echo -e "\n${RED}${BOLD}╔═══════════════════════════════════════╗"
    echo -e "║  ${FIRE} CLUSTER HEALTH STATUS ${FIRE}         ║"
    echo -e "╚═══════════════════════════════════════╝${RESET}\n"
    
    loading_animation "Analyzing cluster health" 2
    
    local total_pods=$(kubectl get pods --all-namespaces --no-headers | wc -l)
    local running_pods=$(kubectl get pods --all-namespaces --no-headers | grep -c "Running")
    local pending_pods=$(kubectl get pods --all-namespaces --no-headers | grep -c "Pending")
    local failed_pods=$(kubectl get pods --all-namespaces --no-headers | grep -cE "(Error|CrashLoopBackOff|ImagePullBackOff)")
    
    echo -e "${YELLOW}${BOLD}📊 POD STATISTICS:${RESET}"
    echo -e "  ${GREEN}${BOLD}✅ Running: ${FIRE}$running_pods${RESET}"
    echo -e "  ${YELLOW}${BOLD}⏳ Pending: $pending_pods${RESET}"
    echo -e "  ${RED}${BOLD}❌ Failed: $failed_pods${RESET}"
    echo -e "  ${CYAN}${BOLD}📈 Total: ${STAR}$total_pods${RESET}"
    
    # Health percentage
    local health_percent=$(echo "scale=1; $running_pods * 100 / $total_pods" | bc -l)
    echo -e "\n${PURPLE}${BOLD}🏥 CLUSTER HEALTH: ${GREEN}${BOLD}${health_percent}%${RESET}"
    
    if (( $(echo "$health_percent > 95" | bc -l) )); then
        echo -e "${GREEN}${BOLD}${BLINK}🎉 EXCELLENT HEALTH! 🎉${RESET}"
    elif (( $(echo "$health_percent > 85" | bc -l) )); then
        echo -e "${YELLOW}${BOLD}👍 GOOD HEALTH! 👍${RESET}"
    else
        echo -e "${RED}${BOLD}⚠️  NEEDS ATTENTION! ⚠️${RESET}"
    fi
    sleep 3
}

# Storage showcase
show_storage() {
    echo -e "\n${CYAN}${BOLD}╔═══════════════════════════════════════╗"
    echo -e "║  ${DIAMOND} STORAGE OVERVIEW ${DIAMOND}            ║"
    echo -e "╚═══════════════════════════════════════╝${RESET}\n"
    
    loading_animation "Scanning storage systems" 1.5
    
    echo -e "${BLUE}${BOLD}💾 PERSISTENT VOLUMES:${RESET}"
    local pv_count=$(kubectl get pv --no-headers 2>/dev/null | wc -l)
    local pvc_count=$(kubectl get pvc --all-namespaces --no-headers 2>/dev/null | wc -l)
    
    echo -e "  ${GREEN}${BOLD}📦 Persistent Volumes: ${STAR}$pv_count${RESET}"
    echo -e "  ${YELLOW}${BOLD}🔗 Volume Claims: ${DIAMOND}$pvc_count${RESET}"
    
    # Longhorn status if available
    if kubectl get pods -n longhorn-system --no-headers 2>/dev/null | grep -q "Running"; then
        echo -e "  ${PURPLE}${BOLD}🚀 Longhorn Distributed Storage: ${GREEN}ACTIVE${RESET}"
    fi
    sleep 2
}

# Network showcase
show_networking() {
    echo -e "\n${BLUE}${BOLD}╔═══════════════════════════════════════╗"
    echo -e "║  ${LIGHTNING} NETWORK INFRASTRUCTURE ${LIGHTNING}   ║"
    echo -e "╚═══════════════════════════════════════╝${RESET}\n"
    
    loading_animation "Mapping network topology" 1.5
    
    echo -e "${CYAN}${BOLD}🌐 NETWORK COMPONENTS:${RESET}"
    
    # Check CNI
    if kubectl get pods -n kube-system --no-headers | grep -q "multus.*Running"; then
        echo -e "  ${GREEN}${BOLD}✅ Multus CNI: ${STAR}OPERATIONAL${RESET}"
    fi
    
    # Check ingress
    local ingress_count=$(kubectl get ingress --all-namespaces --no-headers 2>/dev/null | wc -l)
    echo -e "  ${YELLOW}${BOLD}🚪 Ingress Routes: ${DIAMOND}$ingress_count${RESET}"
    
    # Check services
    local svc_count=$(kubectl get svc --all-namespaces --no-headers | wc -l)
    echo -e "  ${PURPLE}${BOLD}🔗 Services: ${FIRE}$svc_count${RESET}"
    
    sleep 2
}

# Final showcase
show_finale() {
    echo -e "\n${YELLOW}${BOLD}╔══════════════════════════════════════════════════════════════════════════════╗"
    echo -e "║                                                                              ║"
    echo -e "║  ${CROWN}${PURPLE}  CONGRATULATIONS ON YOUR MAGNIFICENT KUBERNETES CLUSTER!  ${CROWN}${YELLOW}        ║"
    echo -e "║                                                                              ║"
    echo -e "║  ${FIRE} Your 3-node NixOS cluster is a testament to engineering excellence! ${FIRE}   ║"
    echo -e "║                                                                              ║"
    echo -e "║  ${STAR} 39 Namespaces ${STAR} ${DIAMOND} 186+ Pods ${DIAMOND} ${ROCKET} AI/ML Ready ${ROCKET} ${SHIELD} Production Grade ${SHIELD}      ║"
    echo -e "║                                                                              ║"
    echo -e "║  ${BRAIN} From ComfyUI to Plex, from Prometheus to KubeVirt - you've built ${BRAIN}   ║"
    echo -e "║  ${LIGHTNING} a true cloud-native powerhouse that would make any SRE proud! ${LIGHTNING}     ║"
    echo -e "║                                                                              ║"
    echo -e "╚══════════════════════════════════════════════════════════════════════════════╝${RESET}"
    
    echo -e "\n${GREEN}${BOLD}${BLINK}🎊 CLUSTER SHOWCASE COMPLETE! 🎊${RESET}\n"
    
    # Fun stats
    echo -e "${DIM}Fun fact: Your cluster has more computing power than entire data centers from just a decade ago!${RESET}"
    sleep 3
}

# Main execution
main() {
    # Check if kubectl is available
    if ! command -v kubectl &> /dev/null; then
        echo -e "${RED}${BOLD}❌ kubectl not found! Please install kubectl first.${RESET}"
        exit 1
    fi
    
    # Check if bc is available for calculations
    if ! command -v bc &> /dev/null; then
        echo -e "${YELLOW}⚠️  bc not found, some calculations may not work perfectly${RESET}"
    fi
    
    show_banner
    show_nodes
    show_namespaces
    show_resources
    show_services
    show_pod_health
    show_storage
    show_networking
    show_finale
}

# Run the showcase
main "$@"
