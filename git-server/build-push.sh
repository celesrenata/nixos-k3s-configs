#!/bin/bash

if [ $# -ne 2 ]; then
    echo "Usage: $0 <image-name> <dockerfile-path>"
    exit 1
fi

IMAGE_NAME=$1
DOCKERFILE_PATH=$2
REGISTRY="NODE_IP:30500"

# Build and push to local registry
docker build -t $IMAGE_NAME -f $DOCKERFILE_PATH .
docker tag $IMAGE_NAME $REGISTRY/$IMAGE_NAME
docker push $REGISTRY/$IMAGE_NAME

echo "Image pushed to $REGISTRY/$IMAGE_NAME"
