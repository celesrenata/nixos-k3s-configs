#!/bin/bash

# Script to update SteamVR passwords

NAMESPACE="steamvr-service"

if [ $# -ne 2 ]; then
    echo "Usage: $0 <username> <password>"
    echo "Example: $0 celes newpassword"
    exit 1
fi

USERNAME="$1"
PASSWORD="$2"

# Encode credentials to base64
USERNAME_B64=$(echo -n "$USERNAME" | base64)
PASSWORD_B64=$(echo -n "$PASSWORD" | base64)

echo "Updating passwords for user: $USERNAME in namespace: $NAMESPACE"

# Check if namespace exists
if ! kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
    echo "Error: Namespace '$NAMESPACE' does not exist. Run ./runmefirst.sh first."
    exit 1
fi

# Update the Secret
echo "Updating Secret..."
kubectl patch secret steamvr-auth -n "$NAMESPACE" -p="{\"data\":{\"web-user\":\"$USERNAME_B64\",\"web-password\":\"$PASSWORD_B64\"}}"

# Update the ConfigMap
echo "Updating ConfigMap..."
kubectl patch configmap steamvr-createusers -n "$NAMESPACE" -p="{\"data\":{\"createusers.txt\":\"$USERNAME:$PASSWORD:Y\"}}"

echo "Password updated successfully!"
echo "Restarting deployment to apply changes..."

# Restart the deployment to pick up new credentials
kubectl rollout restart deployment/steamvr -n "$NAMESPACE"

echo "Deployment restarted. New credentials:"
echo "- Username: $USERNAME"
echo "- Password: $PASSWORD"
echo ""
echo "Waiting for pod to restart..."
kubectl rollout status deployment/steamvr -n "$NAMESPACE" --timeout=300s

echo ""
echo "You can now use these credentials to log in to:"
echo "- Web UI"
echo "- SSH access"
echo "- VNC access"
echo "- RDP access"
