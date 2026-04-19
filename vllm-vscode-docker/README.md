# Install b70 driver

URL: https://dgpu-docs.intel.com/driver/client/overview.html

```bash
sudo apt update -y

sudo apt install -y software-properties-common

sudo add-apt-repository -y ppa:kobuk-team/intel-graphics

sudo apt-get install -y libze-intel-gpu1 libze1 intel-metrics-discovery intel-opencl-icd clinfo intel-gsc

sudo apt-get install -y intel-media-va-driver-non-free libmfx-gen1 libvpl2 libvpl-tools libva-glx2 va-driver-all vainfo

sudo apt-get install -y libze-dev intel-ocloc

sudo apt-get install -y libze-intel-gpu-raytracing

clinfo | grep "Device Name"

sudo gpasswd -a ${USER} render

newgrp render

clinfo
```

Edit grub to prevent gpu hangs:

```bash
sudo vim /etc/default/grub
```

On line: `GRUB_CMDLINE_LINUX_DEFAULT="xyz"`

Add: `GRUB_CMDLINE_LINUX_DEFAULT="xyz i915.enable_hangcheck=0"'

Save and exit, then run: `sudo update-grub`

# oneAPI Base Toolkit Installation

URL: https://www.intel.com/content/www/us/en/developer/tools/oneapi/base-toolkit-download.html?packages=oneapi-toolkit&oneapi-toolkit-os=linux&oneapi-lin=apt

Setup the repo

```bash
sudo apt update -y
sudo apt install -y gnupg wget

# download the key to system keyring
wget -O- https://apt.repos.intel.com/intel-gpg-keys/GPG-PUB-KEY-INTEL-SW-PRODUCTS.PUB \
| gpg --dearmor | sudo tee /usr/share/keyrings/oneapi-archive-keyring.gpg > /dev/null

# add signed entry to apt sources and configure the APT client to use Intel repository:
echo "deb [signed-by=/usr/share/keyrings/oneapi-archive-keyring.gpg] https://apt.repos.intel.com/oneapi all main" | sudo tee /etc/apt/sources.list.d/oneAPI.list

sudo apt update -y
```

Install oneAPI: `sudo apt install intel-oneapi-base-toolkit -y`

This may take a while, its a 2+GB download.

Alternatively you can just skip installing oneAPI locally and leverage the docker container. oneAPI in this context is only required if you want to leverage oneAPI backends for local development or features. Everything can also just be ran through a container.

We will setup both.

Additional configurations:

```bash
sudo apt update -y
sudo apt -y install cmake pkg-config build-essential

which cmake pkg-config make gcc g++
```

Set the environment vars: ` /opt/intel/oneapi/2025.3/oneapi-vars.sh`

Create a test, launch: `oneapi-cli`

Select the vector-add test program.

# Build the test program

URL: https://www.intel.com/content/www/us/en/developer/tools/oneapi/base-toolkit-download.html?packages=oneapi-toolkit&oneapi-toolkit-os=linux&oneapi-lin=apt

Open your vector-add dir: `cd ~/Downloads/vector-add`

Run cmake:

```bash
mkdir build
cd build
cmake ..
```

Make with cpu-gpu: `make cpu-gpu`

Run the program: `./vector-add-buffers`

You should see something similar to:

```bash
Running on device: Intel(R) Graphics [0xe223]
Vector size: 10000
[0]: 0 + 0 = 0
[1]: 1 + 1 = 2
[2]: 2 + 2 = 4
...
[9999]: 9999 + 9999 = 19998
Vector add successfully completed on device.
```

This validates oneAPI is building and running on our Arc B70.

# Docker Path

This does not require anything but the driver installation. 

## Intel vLLM Docker for Continue Extension

URL: https://github.com/intel/ai-containers/blob/main/vllm/0.17.0-xpu.md

Pull the image: `docker pull intel/vllm:0.17.0-xpu`

Run the container:

```bash
sudo docker run -it --rm \
  --device /dev/dri:/dev/dri \
  --device /dev/dri/by-path:/dev/dri/by-path \
  --net=host \
  --ipc=host \
  --shm-size="10g" \
  --privileged \
  -v ~/.cache/huggingface:/root/.cache/huggingface \
  -e HF_TOKEN="hf_xxxxxxxxxxxxxxxxxxxxxxxxxx" \
  --entrypoint python3 \
  intel/vllm:0.17.0-xpu \
  -m vllm.entrypoints.openai.api_server \
  --model "Qwen/Qwen3-30B-A3B-GPTQ-Int4" \
  --dtype float16 \
  --max-model-len 32768 \
  --gpu-memory-utilization 0.8 \
  --trust-remote-code
```

You may need to adjust the max-model-len if you are not using a 32GB gpu.

Keep in mind: https://docs.vllm.ai/en/stable/models/hardware_supported_models/xpu/#text-only-language-models

Not all models work with all tools and even less so with intel on those tools. That website will list all tested models.

To configure an extension like continue:

```yaml
name: Intel Arc AI Coding
version: 1.0.0
schema: v1

models:
  - name: "Qwen3-30B-A3B-GPTQ-Int4"
    provider: openai
    model: "Qwen/Qwen3-30B-A3B-GPTQ-Int4"
    apiBase: "http://localhost:8000/v1"
    apiKey: "EMPTY"
    contextLength: 32768

embeddingsProvider:
  provider: transformers.js

contextProviders:
  - name: code
  - name: docs
  - name: diff
  - name: terminal
```

You can list additional models but realistically only load one at a time. You could also spin up another container and load a code completion model on cpu or a very small one on a high vram GPU but that may impact performance.
