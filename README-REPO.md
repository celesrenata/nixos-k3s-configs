# NixOS K3s Configurations

This repository contains Kubernetes deployment configurations for a home lab cluster running on NixOS with K3s.

> **Note:** The NixOS system configurations for the Kubernetes cluster nodes are available in the `dev` branch.

## Structure

Each subdirectory contains a Kubernetes project with:
- `runmefirst.sh` - Deployment script that applies configurations
- YAML manifests for deployments, services, ingress, etc.
- Optional `values.yaml` for Helm charts

## Main Deployment Script

- `runmefirst.sh.gremlin` - Master deployment script for the gremlin cluster
- `runmefirst.sh` - Simplified deployment script

## Key Projects

### Infrastructure
- `dashboard` - Kubernetes dashboard
- `longhorn` - Distributed block storage
- `traefik` - Ingress controller
- `cert-manager` - TLS certificate management
- `prometheus` - Monitoring
- `grafana` - Metrics visualization
- `metallb` - Load balancer

### Storage & Databases
- `mariadb` - MySQL-compatible database
- `postgresql` - PostgreSQL database
- `mongodb` - NoSQL database
- `redis` - In-memory data store
- `minio` - S3-compatible object storage

### Applications
- `nextcloud` - File sharing and collaboration
- `wordpress` - Content management
- `portainer` - Container management UI
- `phpmyadmin` - Database management
- `flame` - Application dashboard
- `hastebin` - Pastebin service
- `git-server` - Git hosting

### AI/ML
- `ollama` - LLM inference
- `open-webui` - Web UI for LLMs
- `comfyui` - Stable Diffusion UI
- `whisper` - Speech recognition
- `jupyterhub` - Jupyter notebooks

### Virtualization
- `kubevirt/` - Virtual machine management
  - `arch-nfs` - Arch Linux VMs
  - `ubuntu-nfs` - Ubuntu VMs
  - `winvm-nfs` - Windows VMs
  - `nixos` - NixOS VMs

### Media
- `clusterjellyfin` - Media server
- `sabnzbd` - Usenet downloader
- `radarr` - Movie management
- `sickchill` - TV show management

### Hardware Support
- `intel` - Intel GPU support
- `nvidia` - NVIDIA GPU support

## Deployment

### Initial Setup
1. Follow the NixOS setup in the main README.md
2. Ensure all nodes are running and kubectl is configured
3. Run the master deployment script:
   ```bash
   ./runmefirst.sh.gremlin
   ```

### Individual Projects
Deploy a single project:
```bash
cd <project-name>
./runmefirst.sh
```

## Cleanup

Before committing to git, run the cleanup script to remove temporary files:
```bash
./cleanup.sh
```

This removes:
- Vim swap files
- Python virtual environments
- Backup directories (*.bak, *.old, etc.)
- Large binary files (ISOs, model files, tar archives)
- Build artifacts

## Git Workflow

```bash
# Initialize repository
git init

# Add files (respects .gitignore)
git add .

# Commit
git commit -m "Initial commit"

# Add remote (if desired)
git remote add origin <your-repo-url>
git push -u origin main
```

## Notes

- Large binary files (ISOs, AI models) are excluded via .gitignore
- Store these separately or download on-demand
- Secrets should be managed separately (not committed to git)
- Each project's runmefirst.sh handles its own dependencies
