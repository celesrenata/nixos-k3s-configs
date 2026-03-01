# PostgreSQL Cluster

## Deployment
```bash
./runmefirst.sh
```

## Connection Details
- **Host**: 10.1.1.12 (or 10.1.1.13, 10.1.1.14)
- **Port**: 5432
- **Databases**: postgresql (default), testdb, clusterjellyfin
- **Users**: root, celes, jellyfin
- **Password**: PSCh4ng3me!

## Connection Examples
```bash
# psql command line (root user)
psql -h 10.1.1.12 -p 5432 -U root -d postgresql

# psql command line (celes user)
psql -h 10.1.1.12 -p 5432 -U celes -d postgresql

# psql command line (jellyfin user)
psql -h 10.1.1.12 -p 5432 -U jellyfin -d clusterjellyfin

# Connection strings
postgresql://root:PSCh4ng3me!@10.1.1.12:5432/postgresql
postgresql://celes:PSCh4ng3me!@10.1.1.12:5432/postgresql
postgresql://jellyfin:PSCh4ng3me!@10.1.1.12:5432/clusterjellyfin
```

## Cleanup
```bash
./runmelast.sh
```
