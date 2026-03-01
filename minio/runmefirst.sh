#!/usr/bin/env bash

set -e  # Exit on any error
set -x

echo "Setting up MinIO Operator and Tenant..."

# Add MinIO Operator Helm repository
echo "Adding MinIO Operator Helm repository..."
helm repo add minio-operator https://operator.min.io
helm repo update

# Install MinIO Operator
echo "Installing MinIO Operator..."
helm upgrade -i \
  --namespace minio-operator \
  --create-namespace \
  operator minio-operator/operator

# Wait for operator to be ready
echo "Waiting for MinIO Operator to be ready..."
sleep 30 

# Create minio-service namespace
echo "Creating minio-service namespace..."
kubectl create namespace minio-service --dry-run=client -o yaml | kubectl apply -f -

# Apply all configurations
echo "Applying MinIO configuration..."
kubectl apply -f . -n minio-service

# Wait for tenant to be ready
echo "Waiting for MinIO Tenant to be ready..."
sleep 60 

# Create buckets (this script will run after MinIO is ready)
cat << 'EOF' > create-buckets.sh
#!/bin/bash
# Wait for MinIO to be fully ready
sleep 30

# Configure mc (MinIO client)
mc alias set minio-crawler https://minio-crawler-hl.minio-service:9000 AKIA6V7J3N9B5P0D2YQH 8fG3!v2rJ7$wN@9mLpQ6zXbC4tKdPqW1 --insecure

# Create buckets
mc mb minio-crawler/crawler-images --ignore-existing --insecure
mc mb minio-crawler/crawler-audio --ignore-existing --insecure
mc mb minio-crawler/crawler-videos --ignore-existing --insecure
mc mb minio-crawler/crawler-media --ignore-existing --insecure

echo "Buckets created successfully!"
EOF

chmod +x create-buckets.sh

# Run bucket creation in a job
kubectl create job create-minio-buckets \
  --image=minio/mc:latest \
  --namespace=minio-service \
  --dry-run=client -o yaml > bucket-job.yaml

cat << 'EOF' >> bucket-job.yaml
  template:
    spec:
      containers:
      - name: create-minio-buckets
        image: minio/mc:latest
        command:
        - /bin/sh
        - -c
        - |
          sleep 30
          mc alias set minio-crawler https://minio-crawler-hl.minio-service:9000 AKIA6V7J3N9B5P0D2YQH 8fG3!v2rJ7$wN@9mLpQ6zXbC4tKdPqW1 --insecure
          mc mb minio-crawler/crawler-images --ignore-existing --insecure || true
          mc mb minio-crawler/crawler-audio --ignore-existing --insecure || true
          mc mb minio-crawler/crawler-videos --ignore-existing --insecure || true
          mc mb minio-crawler/crawler-media --ignore-existing --insecure || true
          echo "Buckets created successfully!"
      restartPolicy: Never
EOF

kubectl apply -f bucket-job.yaml

echo "MinIO setup complete!"
echo ""
echo "To check status:"
echo "  kubectl get pods -n minio-service"
echo "  kubectl get tenants -n minio-service"
echo ""
echo "To get MinIO endpoint:"
echo "  kubectl get svc -n minio-service"
echo ""
echo "To access MinIO Console:"
echo "  kubectl port-forward svc/minio-crawler-console -n minio-service 9001:9001"
echo "  Then visit: https://localhost:9001"
