#!/usr/bin/env bash
kubectl create namespace vms
archiso='archlinux-x86_64.iso'
if [ ! -f ${archiso} ]; then
	wget https://ftp.osuosl.org/pub/archlinux/iso/latest/${archiso} -O ${archiso}
fi
find_old() {
    while read -r -d '' file; do                  # read the output of find one file at a time
      files+=("$file")                            # append to the array
    done < <(find "${archiso}" -mtime +7 -print0) # generate NUL separated list of files
    if ((${#files[@]} == 0)); then
      # no files found
      return 10
    else
      printf '%s\0' "${files[@]}" | xargs -0 rm -f --
    fi
}

if [[ $(find_old | echo $?) -gt 0 ]]; then
	rm ${archiso}
	wget https://ftp.osuosl.org/pub/archlinux/iso/latest/${archiso} -o ${archiso}
fi
virtctl image-upload --image-path archlinux-x86_64.iso --size=2Gi pvc arch-iso-pvc --access-mode ReadWriteMany --uploadproxy-url https://10.1.1.14:31001 --force-bind --insecure --namespace vms
kubectl apply -f . -n vms 
