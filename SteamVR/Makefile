
# Docker - Plain SteamVR
docker-build:
	docker build --pull --build-arg CACHEBUST=$$(date +%s) -t ghcr.io/celesrenata/steamvr:latest \
		-f docker/Dockerfile .
kube-test:
	docker build -t steamvr:test -f docker/Dockerfile .
	docker push localhost:5000/steamvr:test
	kubectl set image deployment/steamvr steamvr=localhost:5000/steamvr:test -n steamvr-service
docker-push:
	docker push ghcr.io/celesrenata/steamvr:latest
local-push:
	git add . && git commit -m "Local changes" || true
	git push local master
	docker build -t registry.celestium.life/steamvr:latest -f docker/Dockerfile .
	docker push registry.celestium.life/steamvr:latest

