#!/usr/bin/env bash
sudo docker run -ti -v /var/run/docker.sock:/var/run/docker.sock -e APP_ID=llm2 -e APP_HOST=0.0.0.0 -e APP_PORT=9080 -e APP_SECRET='PSCh4ng3me!!' -e APP_VERSION=2.3.3 -e NEXTCLOUD_URL='https://nextcloud.splinterstice.celestium.life' -e CUDA_VISIBLE_DEVICES=0 -p 9080:9080 --gpus 1 --detach ghcr.io/celesrenata/llm2:latest
