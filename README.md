# NixOS Intel Ultra 9 185H K3s with SR-IOV GPU Passthrough
## Featuring the Following Projects
* Blender
* Cert Manager
* Cluster Plex
* ComfyUI
* Dashboard
* EveryDream2
* Flame
* Grafana
* Hastebin
* Home Assistant
* Influx2
* Intel SR-IOV Plugins
* Kubevirt
  * Win11-NFS VM (Intel Arc Acceleration still in development)
  * Arch-NFS VM
  * NixOS-NFS VM
  * Ubuntu-NFS VM (Directions to come for Intel Arc GPU XRDP acceleration) 
* Kyverno
* Longhorn
* MariaDB
* MongoDB
* Nvidia-Device-Plugin
* Ollama
* OneTrainer
* Open-WebUI (For Ollama)
* PHPMyAdmin
* Portainer
* Prometheus
* ReviewBoard
* Stable Diffusion
* SteamVR
* Traefik
* Unifi Controller
* Wordpress

## Startup on a Stick Projects
* DrawIO
* Hastebin
* NextCloud
* Wekan Kanban Board
* WikiJS

### Features

* Support for Nvidia Drivers Version: 570.86.16
* Support for Let's Encrypt
* Added startup-drawio project
* Added startup-hastebin
* Added startup-nextcloud
  * Added Support for Nvidia Docker Containers on Gremlin-1
  * Added Support for Self Signed email servers (we're not using it though!)
  * Added Support for deploy daemon and manual-install
* Added startup-reviewboard
  * Added Gmail SMTP Relay Support
* Added startup-wekan
* Added startup-wikijs

### Todo
* Add directions to setup deploy daemon w/ CUDA to Gremlin-1
* Add directions to setup manual-install daemon w/ CUDA to Gremlin-1
* Add directions to deploy modified llm2 container

## Prerequisites
* 3x Intel 13th Gen Processors with the 185H or similar. I use BeeLink.
   * Will also work on ARC dGPUs with a little fiddling
* Seperate VLAN for your Kube Cluster

## Installation
* Contained in the repo are the main configurations required to build out each host.
1. [Build a ThumbDrive or PXE Boot NixOS 24.05](https://wiki.nixos.org/wiki/NixOS_Installation_Guide)
   * Complete steps through SWAP setup
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

## Setup SteamVR or Blender
* Navigate to the SteamVR/Blender directory
* `cd etc`
* `./generate_password.sh`
* Edit the `Makefile` to point to your own repo
* `make docker-build`
* `make docker-push`
* Modify `deployment.yaml` to point to your repo
  * Make sure to map the package to your repo
  * Make sure to mark the package public

## Setup Ubuntu / Arch / NixOS / Win11 KubeVirts
* Each of the VMs make use of (X)RDP and the software display isn't necessary after installation of the OSes
1. Install the OS on each host you need
2. Install (X)RDP Support
3. Verify (X)RDP Connects
4. Shutdown the VM
5. run `kubectl -n vms get vms`
6. run `kubectl -n vms delete vm vmname`
7. edit the `vm.yaml` in its corresponding `kubevirt/OSNAME-nfs` directory and uncomment the designated line
8. rerun `runmefirst.sh` in the corresponding `kubevirt/OSNAME-nfs` directory

## Setup NextCloud
### Setup Daemons
1. Configure the proxy daemon
  * ![Proxy Deploy Daemon Install](https://github.com/celesrenata/nixos-k3s-configs/blob/nvidia/resources/docker-manual-install.png?raw=true)
2. Configure the manual install daemon
  * ![Docker Manual Daemon Install](https://github.com/celesrenata/nixos-k3s-configs/blob/nvidia/resources/docker-manual-install.png?raw=true)

## TODO
* Resolve Problem (43) in Win11 when passing SR-IOV Intel graphics to it.
* Write Ubuntu Intel Arc Build Process
