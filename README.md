# NixOS Intel Ultra 9 185H K3s with SR-IOV GPU Passthrough
## Featuring the Following Projects
* Cert Manager
* Cluster Plex
* ComfyUI (Nvidia)
* Dashboard
* Flame
* Grafana
* Intel SR-IOV Plugins
* Kubevirt
  * Amazon Linux 2023
  * Arch Linux
  * NixOS 24.05 (Intel)
  * Ubuntu 24.04 Ollama (Intel IPEX)
  * Windows 11 (Intel GPU broken)
* Kyverno
* Longhorn
* MariaDB
* Nvidia Container Plugins
* Nvidia Containerd Toolkit
* PHPMyAdmin
* Portainer
* Prometheus
* ReviewBoard
* Traefik
* Unifi Controller
* Wordpress

## Prerequisites
* 3x Intel 14th Gen Processors with the 185H or similar. I use BeeLink 3x GTi14(s).
   * Will also work on ARC dGPUs with a little fiddling.
* Seperate VLAN for your Kube Cluster.

## Installation
* Contained in the repo are the main configurations required to build out each host.
1. [Build a ThumbDrive or PXE Boot NixOS 24.05](https://wiki.nixos.org/wiki/NixOS_Installation_Guide)
   * Complete steps through SWAP setup.
3. `sudo nix-channel --update`
4. `git clone https://github.com/celesrenata/nixos-k3s-configs/`
5. `sudo nixos-generate-config --root /mnt`
6. `cp -r nixos-k3s-configs/nixos-kube-config/gremlin-1/* /mnt/etc/nixos/`
7. sudo nixos-generate-config --root /mnt
   * Yes, again
8. You may now edit your hardware-configuration.nix file to your liking
9. `nixos-install --root /mnt`
10. `sudo nixos-enter`
11. `passwd celes`
12. `exit`
13. `reboot`

### Repeat for Gremlins 2 and 3
Login to and add your own ssh configs to your account, root, and nixremote accounts:
* Add your own authroized keys, you will need these as the fleet does not work without passwordless SSH!

## Networking
1. Set your network to expect `10.1.1.12, 10.1.1.13, 10.1.1.14` for your Cluster

## Configuring NFS
1. These configs are setup for my NFS server, you will have to edit all your PVC files to meet your needs
2. Leaving these details in have been way more useful than not demonstrating how to create truely persistant volumes

## Ensuring Cluster is Happy
1. I have included automation scripts for resetting the fleet to known good states as well as scripts to deploy all the services I have figured out!
2. `./resetfleet.sh`

## Edit the Cluster Deployments
Each script is controlled by a `runmefirst.sh` file in the directory of the service, and is stood up by the following automation script:
* `./runmefirst.sh`
* Edit this file to turn off deployments you do not desire for your Cluster

## Ollama via IPEX
Ollama is controlled via the IPEX fleet within the `kubevirt` directory
If you have more than 32GB of ram per Node you can then use Ipex-LLM Ollama!
`kubevirt/ipex-1x/runmefirst.sh`

## TODO
* Rebuild Unifi Controller
* Resolve Problem (43) in Win11 when passing SR-IOV Intel graphics to it.
