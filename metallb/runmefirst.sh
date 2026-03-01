#!/usr/bin/env bash
kubectl create namespace metallb-system
helm upgrade --install metallb metallb/metallb --namespace metallb-system -f values.yaml \
  --set speaker.tolerations[0].key=nvidia.com/gpu \
  --set speaker.tolerations[0].operator=Equal \
  --set speaker.tolerations[0].value=present \
  --set speaker.tolerations[0].effect=NoSchedule \
  --set controller.tolerations[0].key=nvidia.com/gpu \
  --set controller.tolerations[0].operator=Equal \
  --set controller.tolerations[0].value=present \
  --set controller.tolerations[0].effect=NoSchedule
