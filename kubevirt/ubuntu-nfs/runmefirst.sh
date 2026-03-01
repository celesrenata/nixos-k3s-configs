#!/usr/bin/env bash

# Create namespace
kubectl create namespace vms

VERSION='24.04.2'
#if [ ! -f "ubuntu-${VERSION}-desktop-amd64.iso" ]; then
#	wget "https://releases.ubuntu.com/${VERSION}/ubuntu-${VERSION}-desktop-amd64.iso" -O "ubuntu-${VERSION}-desktop-amd64.iso"
#fi
#find_old() {
#    while read -r -d '' file; do                  # read the output of find one file at a time
#      files+=("$file")                            # append to the array
#    done < <(find "ubuntu-${VERSION}-desktop-amd64.iso" -mtime +7 -print0) # generate NUL separated list of files
#    if ((${#files[@]} == 0)); then
#      # no files found
#      return 10
#    else
#      printf '%s\0' "${files[@]}" | xargs -0 rm -f --
#    fi
#}
#
#if [[ $(find_old | echo $?) -gt 0 ]]; then
#	rm "ubuntu-${VERSION}-desktop-amd64.iso"
#	wget "https://releases.ubuntu.com/${VERSION}/ubuntu-${VERSION}-desktop-amd64.iso" -O "ubuntu
#-${VERSION}-desktop-amd64.iso"
#fi

# Start port-forward to CDI upload proxy in background
echo "Setting up port-forward to CDI upload proxy..."
kubectl port-forward -n cdi svc/cdi-uploadproxy 18443:443 &
PF_PID=$!

# Wait a moment for port-forward to establish
sleep 3

# Function to cleanup port-forward on exit
cleanup() {
    echo "Cleaning up port-forward..."
    kill $PF_PID 2>/dev/null
}
trap cleanup EXIT

# Upload image using localhost port-forward
virtctl image-upload --image-path "ubuntu-${VERSION}-live-server-amd64.iso" --size=6Gi pvc ubuntu-server-iso-pvc --access-mode ReadWriteMany --uploadproxy-url https://localhost:18443 --force-bind --insecure --namespace vms

# Apply remaining resources
kubectl apply -f . -n vms 
