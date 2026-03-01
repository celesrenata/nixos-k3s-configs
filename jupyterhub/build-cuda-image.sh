#!/usr/bin/env bash

REPO="ghcr.io/celesrenata/jupyter-cuda-notebooks"
TAG="12.9"

docker build -f Dockerfile.cuda129 -t ${REPO}:${TAG} .
docker push ${REPO}:${TAG}
