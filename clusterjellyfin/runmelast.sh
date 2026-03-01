#!/usr/bin/env bash
set -e

echo "🗑️  Removing ClusterJellyfin..."

# Uninstall helm release
if helm list -n jellyfin-system | grep -q jellyfin; then
    echo "📦 Uninstalling Helm release..."
    helm uninstall jellyfin --namespace jellyfin-system
else
    echo "⚠️  No Helm release found"
fi

# Delete namespace (this removes all resources)
if kubectl get namespace jellyfin-system >/dev/null 2>&1; then
    echo "🧹 Deleting namespace and all resources..."
    kubectl delete namespace jellyfin-system
else
    echo "⚠️  Namespace jellyfin-system not found"
fi

echo "✅ ClusterJellyfin removed successfully!"
echo ""
echo "ℹ️  Note: Persistent volumes may still exist if using external storage"
echo "   Check with: kubectl get pv | grep jellyfin"
