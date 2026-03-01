#!/bin/bash
# Patch Traefik with extended timeouts for large file uploads

kubectl patch deployment traefik -n kube-system --type='json' -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--entryPoints.websecure.transport.respondingTimeouts.readTimeout=7200s"}]'

kubectl patch deployment traefik -n kube-system --type='json' -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--entryPoints.websecure.transport.respondingTimeouts.writeTimeout=7200s"}]'

echo "Traefik patched with 2-hour timeouts for large uploads"
