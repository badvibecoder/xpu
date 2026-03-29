#!/bin/bash

# Install ARC drivers beyond what is in the kernel
#sudo apt-get update -y
#sudo apt-get install -y software-properties-common
#sudo add-apt-repository -y ppa:kobuk-team/intel-graphics

# Compute packages
#sudo apt-get install -y libze-intel-gpu1 libze1 intel-metrics-discovery intel-opencl-icd clinfo intel-gsc

# Media packages
#sudo apt-get install -y intel-media-va-driver-non-free libmfx-gen1 libvpl2 libvpl-tools libva-glx2 va-driver-all vainfo

# Required for pytorch
#sudo apt-get install -y libze-dev intel-ocloc

# Add support for raytracing
#sudo apt-get install -y libze-intel-gpu-raytracing

# Verify
#clinfo | grep "Device Name"

# Add user to group render - /dev/dri/renderD*
#sudo gpasswd -a ${USER} render

# Create xpu-ipex container working folder
mkdir -p ~/jupyter-torch-xpu
#mkdir -p ~/jupyter-tensorflow-xpu

# Build custom docker image based on intel torch and tensorflow containers
sudo docker build -t mrchanche-xpu-torch-jupyter:2.8.10 -f ~/Github/xpu/xpu-ubuntu-docker/torch-dockerfile/Dockerfile .
#sudo docker build -t mrchanche-xpu-tensorflow-jupyter:2.15.0 -f ~/Github/xpu/xpu-ubuntu-docker/tensorflow-dockerfile/Dockerfile .
sudo docker build -t mrchanche-vllm:0.14.1-xpu -f ~/Github/xpu/xpu-ubuntu-docker/intel-vllm/Dockerfile .

# Create xpu-ipex-torch-docker.sh in ~/
echo '#!/bin/bash' > ~/xpu-ipex-torch-docker.sh
echo 'sudo docker run -it --rm \' >> ~/xpu-ipex-torch-docker.sh
echo '    -p 8888:8888 \' >> ~/xpu-ipex-torch-docker.sh
echo '    --device /dev/dri \' >> ~/xpu-ipex-torch-docker.sh
echo '    -v /dev/dri/by-path:/dev/dri/by-path \' >> ~/xpu-ipex-torch-docker.sh
# This line maps your host dir to the working dir
echo '    -v ~/jupyter-torch-xpu:/jupyter \' >> ~/xpu-ipex-torch-docker.sh
echo '    -w /jupyter \' >> ~/xpu-ipex-torch-docker.sh
echo '    mrchanche-xpu-torch-jupyter:2.8.10' >> ~/xpu-ipex-torch-docker.sh
chmod +x ~/xpu-ipex-torch-docker.sh

# Create xpu-ipex-tensorflow-docker.sh in ~/
#echo '#!/bin/bash' > ~/xpu-ipex-tensorflow-docker.sh
#echo 'sudo docker run -it --rm \' >> ~/xpu-ipex-tensorflow-docker.sh
#echo '    -p 8888:8888 \' >> ~/xpu-ipex-tensorflow-docker.sh
#echo '    --device /dev/dri \' >> ~/xpu-ipex-tensorflow-docker.sh
#echo '    -v /dev/dri/by-path:/dev/dri/by-path \' >> ~/xpu-ipex-tensorflow-docker.sh
# This line maps your host dir to the working dir
#echo '    -v ~/jupyter-tensorflow-xpu:/jupyter \' >> ~/xpu-ipex-tensorflow-docker.sh
#echo '    -w /jupyter \' >> ~/xpu-ipex-tensorflow-docker.sh
#echo '    mrchanche-xpu-tensorflow-jupyter:2.15.0' >> ~/xpu-ipex-tensorflow-docker.sh
#chmod +x ~/xpu-ipex-tensorflow-docker.sh

# Create intel-vllm-docker.sh in ~/
echo '#!/bin/bash' > ~/intel-vllm-docker.sh
echo 'docker run -d --name vllm-arc \' >> ~/intel-vllm-docker.sh
echo '  --device /dev/dri \' >> ~/intel-vllm-docker.sh
echo '  --net=host \' >> ~/intel-vllm-docker.sh
echo '  --shm-size="32g" \' >> ~/intel-vllm-docker.sh
echo '  --privileged \' >> ~/intel-vllm-docker.sh
echo '  -v ~/.cache/huggingface:/root/.cache/huggingface \' >> ~/intel-vllm-docker.sh
echo '  intel/vllm:0.14.1-xpu \' >> ~/intel-vllm-docker.sh
echo '  vllm serve "Qwen/Qwen2.5-Coder-7B-Instruct" \' >> ~/intel-vllm-docker.sh
echo '  --device xpu \' >> ~/intel-vllm-docker.sh
echo '  --dtype float16 \' >> ~/intel-vllm-docker.sh
echo '  --max-model-len 8192 \' >> ~/intel-vllm-docker.sh
echo '  --gpu-memory-utilization 0.8' >> ~/intel-vllm-docker.sh
chmod +x ~/intel-vllm-docker.sh

# Wrap up
echo "Finished, you may need to logout/login for groups to take effect"
echo " "
echo "Check your home directory for xpu-ipex-docker.sh, this will spin up the Intel XPU-Ipex container"

#newgrp render
