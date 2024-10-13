#!/usr/bin/env bash
kubectl create namespace ollama-ipex
kubectl apply -f monitoring.yaml -n ollama-ipex
sleep 5
#find . -type d -exec cd {}; ./runmefirst.sh; cd .. \;
cd 01
./runmefirst.sh
cd ..
sleep 5
cd 02
./runmefirst.sh
cd ..
sleep 5
cd 03
./runmefirst.sh
cd ..
sleep 300
./bootstrap-ipex-fleet.sh
