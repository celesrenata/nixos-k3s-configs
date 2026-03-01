#!/usr/bin/env bash

# NetBootXYZ VLAN IP Management Script
# This script ensures only the node running netbootxyz has the VLAN IP

set -e

echo "=== NetBootXYZ VLAN IP Management ==="
echo ""

# Get current pod location
CURRENT_NODE=$(kubectl get pods -l io.kompose.service=netbootxyz -o jsonpath='{.items[0].spec.nodeName}' 2>/dev/null)

if [ -z "$CURRENT_NODE" ]; then
    echo "❌ NetBootXYZ pod not found!"
    exit 1
fi

echo "📍 NetBootXYZ pod is running on: $CURRENT_NODE"
echo ""

# Manage VLAN interfaces on all nodes
for node in gremlin-1 gremlin-2 gremlin-3; do
    echo "🔧 Managing VLAN interface on $node..."
    
    if [ "$node" = "$CURRENT_NODE" ]; then
        echo "  ✅ ACTIVE NODE: Setting up VLAN with IP"
        ssh root@$node "
            # Ensure VLAN interface exists
            ip link add link bond0 name bond0.100 type vlan id 100 2>/dev/null || true
            
            # Remove any existing IP first to avoid conflicts
            ip addr flush dev bond0.100 2>/dev/null || true
            
            # Add the IP
            ip addr add 192.168.42.16/24 dev bond0.100
            ip link set bond0.100 up
            
            echo '    IP assigned: 192.168.42.16/24'
        "
    else
        echo "  🔧 INACTIVE NODE: Ensuring VLAN exists but no IP"
        ssh root@$node "
            # Ensure VLAN interface exists
            ip link add link bond0 name bond0.100 type vlan id 100 2>/dev/null || true
            
            # Remove IP if it exists
            ip addr flush dev bond0.100 2>/dev/null || true
            ip link set bond0.100 up
            
            echo '    VLAN ready (no IP)'
        "
    fi
done

echo ""
echo "🔍 Verification:"
echo "Active node ($CURRENT_NODE) VLAN status:"
ssh root@$CURRENT_NODE "ip addr show bond0.100 | grep 'inet '"

echo ""
echo "Testing connectivity:"
sleep 3
if ping -c 2 192.168.42.16 >/dev/null 2>&1; then
    echo "✅ Ping: Success"
else
    echo "❌ Ping: Failed"
fi

if curl -s -o /dev/null -w "%{http_code}" http://192.168.42.16:3000 2>/dev/null | grep -q "200"; then
    echo "✅ Web UI: Responding"
else
    echo "❌ Web UI: Not responding"
fi

echo ""
echo "🎯 NetBootXYZ should now be accessible at:"
echo "   - Web UI: http://192.168.42.16:3000"
echo "   - HTTP Boot: http://192.168.42.16:8080"
echo "   - TFTP: 192.168.42.16:69"
