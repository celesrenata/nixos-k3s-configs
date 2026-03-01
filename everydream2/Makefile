MODEL_PATH ?= $(HOME)/models
COMFYUI_VERSION ?= 5e29e7a
COMFYUI_MANAGER_VERSION ?= 17e2565


# Cluster
cluster:
	@[ -d "$(MODEL_PATH)" ] || { echo "Please set MODEL_PATH"; exit 1; }
	# minikube v1.32.0-beta.0 or later (docker driver only).
	minikube start --driver docker --container-runtime docker \
		--memory=max --cpus=max \
		--gpus all \
		--mount \
		--mount-string $(MODEL_PATH):/minikube-host/models
	# we use custom nvidia-device-plugin helm chart to enable GPU sharing.
	minikube addons disable nvidia-device-plugin

cluster-removal:
	minikube delete


# Docker - Plain ComfyUI
docker-build:
	docker build --pull --no-cache -t ghcr.io/celesrenata/onetrainer:latest \
		-f docker/Dockerfile .

docker-push:
	docker push ghcr.io/celesrenata/onetrainer:latest

docker-run:
	docker run -it --gpus all -p 50000:50000 \
		-v $(HOME)/models:/home/workspace/ComfyUI/models \
		ghcr.io/celesrenata/comfyui-onprem-k8s:comfyui-$(COMFYUI_VERSION)


# Docker - Jupyter ComfyUI
docker-build-jupyter:
	docker build --pull --no-cache -t ghcr.io/celesrenata/onetrainer:latest-cuda-jupyter \
		--build-arg BASE_IMAGE=ghcr.io/celesrenata/onetrainer:latest \
		-f docker/comfyui-jupyter.Dockerfile .

docker-push-jupyter:
	docker push ghcr.io/celesrenata/onetrainer:latest-cuda-jupyter

docker-run-jupyter:
	docker run -it --gpus all -p 8888:8888 \
		-v $(HOME)/models:/home/workspace/ComfyUI/models \
		ghcr.io/celesrenata/comfyui-onprem-k8s:comfyui-jupyter-$(COMFYUI_VERSION)


# Utils
tunnel:
	minikube tunnel --bind-address="0.0.0.0"
