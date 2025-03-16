#!/usr/bin/env bash
kubectl create namespace vms
VERSION='24.04.1'
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
virtctl image-upload --image-path "ubuntu-${VERSION}-live-server-amd64.iso" --size=6Gi pvc ubuntu-server-iso-pvc --access-mode ReadWriteMany --uploadproxy-url https://10.1.1.14:31001 --force-bind --insecure --namespace vms
kubectl apply -f . -n vms 
