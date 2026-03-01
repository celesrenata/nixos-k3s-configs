# ClusterJellyfin

## Architecture

```
┌─────────────────────────────────────┐
│          Ingress Controller         │
│        (Traefik/NGINX)              │
└─────────────────────────────────────┘
              │
              ▼
┌─────────────────────────────────────┐
│ Main Jellyfin Pod (Web UI & API)    │
│ ↔ PostgreSQL Database (DB Pod)      │
└─────────────────────────────────────┘
              │
              ▼
┌───────────────────────────────────────────┐
│ Worker Pods (3) - Distributed Transcoders │
└───────────────────────────────────────────┘
```

## Key Features

- ✅ **Ingress Controller**: Dedicated controller for external traffic routing (Traefik/NGINX)
- ✅ **PostgreSQL Database Pod**: Dedicated database pod for production use
- ✅ **Main Jellyfin Pod**: Single pod handling web UI and API orchestration
- ✅ **Distributed Transcoding**: Three worker pods handling all transcoding tasks
- ✅ **Bidirectional Database Connection**: Arrows between Main and DB show bidirectional communication
- ✅ **Scalable Architecture**: Easily add more worker pods as needed

## Installation

Follow the [INSTALL.md](INSTALL.md) guide for detailed setup instructions.

1. **Set up PostgreSQL database (choose one):**
   
   **Option A: External PostgreSQL (recommended for production):**
   ```bash
   # Create database and user on your PostgreSQL server
   createdb clusterjellyfin
   createuser jellyfin
   psql -c "GRANT ALL PRIVILEGES ON DATABASE clusterjellyfin TO jellyfin;"
   psql -c "ALTER USER jellyfin WITH PASSWORD 'your-secure-password';"
   ```
   
   **Option B: Use embedded PostgreSQL (requires CNPG):**
   ```bash
   # Install CloudNativePG operator first
   kubectl apply -f https://raw.githubusercontent.com/cloudnative-pg/cloudnative-pg/release-1.21/releases/cnpg-1.21.0.yaml
   ```
   ```yaml
   # In your values.yaml, set:
   postgresql:
     enabled: true
     instances: 3  # High availability cluster
   ```

## Documentation

- [COMPREHENSIVE_DOCUMENTATION.md](COMPREHENSIVE_DOCUMENTATION.md)
- [PRODUCTION_EXAMPLE.md](PRODUCTION_EXAMPLE.md)
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
