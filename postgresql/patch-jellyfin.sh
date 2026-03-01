#!/usr/bin/env bash
kubectl exec -n postgresql-service -it postgresql-1 -- psql -U postgres -d postgresql -c "CREATE USER jellyfin WITH PASSWORD 'PSCh4ng3me!';"
kubectl exec -n postgresql-service -it postgresql-1 -- createdb -U postgres -O jellyfin clusterjellyfin
