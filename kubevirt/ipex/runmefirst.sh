#!/usr/bin/env bash
kubectl create namespace ollama-ipex
#find . -type d -exec cd {}; ./runmefirst.sh; cd .. \;
cd 01
./runmefirst.sh
cd ..
cd 02
./runmefirst.sh
cd ..
cd 03
./runmefirst.sh
cd ..
cd 04
./runmefirst.sh
cd ..
cd 05
./runmefirst.sh
cd ..
cd 06
./runmefirst.sh
cd ..
