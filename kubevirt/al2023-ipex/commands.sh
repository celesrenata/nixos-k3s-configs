curl -O https://repo.anaconda.com/archive/Anaconda3-2024.06-1-Linux-x86_64.sh
chmod +x Anaconda3-2024.06-1-Linux-x86_64.sh
./Anaconda3-2024.06-1-Linux-x86_64.sh
#install it
conda create -n llm python=3.11 libuv
conda activate llm


# Configure oneAPI environment variables. Required step for APT or offline installed oneAPI.
# Skip this step for PIP-installed oneAPI since the environment has already been configured in LD_LIBRARY_PATH.
source /opt/intel/oneapi/setvars.sh

export SYCL_CACHE_PERSISTENT=1
export BIGDL_LLM_XMX_DISABLED=1


