FROM nvidia/cuda:12.8.1-runtime-ubuntu24.04

WORKDIR /python-docker
COPY requirements.txt requirements.txt
RUN apt-get update && apt-get install git python3 pip -y && \
pip3 install --break-system-packages -r requirements.txt && \
pip3 install --break-system-packages "git+https://github.com/openai/whisper.git" && \
apt-get update && apt-get install -y ffmpeg && \
pip3 cache purge && apt-get clean
COPY . .
EXPOSE 8000
CMD ["uvicon", "fastapi_app:app", "--host", "0.0.0.0", "--port", "8000"]
