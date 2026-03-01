# NixOS K3s Configurations

Kubernetes deployment configurations for a home lab K3s cluster running on NixOS.

> **NixOS System Configurations:** The NixOS system configurations for the cluster nodes are available in the `dev` branch.

## Quick Start

1. Set up your NixOS K3s cluster (see installation guide in existing README.md)
2. Deploy all services:
   ```bash
   ./runmefirst.sh
   ```

## What's Included

### Infrastructure & Networking
- `dashboard` - Kubernetes dashboard
- `longhorn` - Distributed block storage
- `traefik` - Ingress controller
- `cert-manager` - TLS certificate management
- `metallb` - Load balancer
- `kyverno` - Policy engine

### Monitoring & Observability
- `prometheus` - Metrics collection
- `grafana` - Metrics visualization
- `influxdb2` - Time series database
- `kasa-exporter` - Smart device metrics

### Databases & Caching
- `mariadb` - MySQL-compatible database
- `postgresql` - PostgreSQL database
- `mongodb` - NoSQL database
- `redis` - In-memory data store
- `memcached` - Distributed memory caching

### Storage & File Services
- `minio` - S3-compatible object storage
- `nextcloud` - File sharing and collaboration
- `git-server` - Git hosting

### AI/ML & Training
- `ollama` - LLM inference
- `open-webui` - Web UI for LLMs
- `kubeai` - AI model serving
- `comfyui` - Stable Diffusion UI
- `comfyui-ipex` - Intel-optimized ComfyUI
- `whisper` - Speech recognition
- `jupyterhub` - Jupyter notebooks
- `OneTrainer` - AI model training
- `everydream2` - Stable Diffusion training

### Virtualization & Desktop
- `kubevirt/` - Virtual machine management
- `SteamVR` - VR environment
- `Blender` - 3D graphics workstation

### Media & Entertainment
- `clusterjellyfin` - Media server
- `sabnzbd` - Usenet downloader
- `radarr` - Movie management
- `sickchill` - TV show management

### Development & Collaboration
- `portainer` - Container management UI
- `phpmyadmin` - Database management
- `hastebin` - Pastebin service
- `reviewboard` - Code review
- `gerritcr` - Code review system
- `wordpress` - Content management
- `wordpress-dev` - WordPress development
- `localstack` - AWS local testing

### Home Automation
- `homeassistant` - Home automation platform
- `unifi` - Network management

### Utilities & Dashboards
- `flame` - Application dashboard
- `pylaform` - Platform tools
- `redirects` - URL redirects
- `netbootxyz` - Network boot menu
- `sso` - Single sign-on

### Hardware Support
- `intel` - Intel GPU support
- `nvidia` - NVIDIA GPU support
- `gpu-operator` - GPU operator

### Experimental
- `crucible` - Testing environment
- `firecrawl` - Web scraping
- `deepweb-proxy` - Proxy service

## Individual Deployments

Each subdirectory contains a `runmefirst.sh` script:
```bash
cd <project-name>
./runmefirst.sh
```

## Cleanup

Remove temporary files before committing:
```bash
./cleanup.sh
```

## Notes

- Large binaries (ISOs, AI models) are excluded via `.gitignore`
- Secrets should be managed separately
- Multiple cluster configurations available: gremlin, goblin, sandra
