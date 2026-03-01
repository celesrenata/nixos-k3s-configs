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
