Here is the fully consolidated, single-file setup script, updated with the modern `intel/pytorch` base image.

Following the script is a complete Markdown guide on how to use your new directory structure, execute the containers, and run practical examples for your Intel Arc Pro B70.

### 1. The Master Setup Script

Save this entire block as `setup-intel-ai-env.sh` in your home directory (`~`), make it executable with `chmod +x setup-intel-ai-env.sh`, and run it.

```bash
#!/bin/bash
# setup-intel-ai-env.sh
# Generates a standardized Intel Arc / XPU Docker environment.

AI_DIR="$HOME/ai"
SCRIPTS_DIR="$AI_DIR/scripts"

echo "Creating folder structure in $AI_DIR..."
mkdir -p "$AI_DIR"/{ovms,openvino,pytorch,playground}
mkdir -p "$SCRIPTS_DIR"/{ovms,openvino,pytorch,oneapi,playground}

# ==========================================
# 1. PyTorch (Native XPU) Setup
# ==========================================
echo "Generating PyTorch environment..."
cat << 'EOF' > "$SCRIPTS_DIR/pytorch/Dockerfile"
FROM intel/pytorch:latest

# Install additional pip packages
RUN pip install --no-cache-dir scikit-learn ipywidgets IProgress transformers matplotlib sentencepiece openai-whisper accelerate

# Install system dependencies
RUN apt update -y && apt install ffmpeg -y && rm -rf /var/lib/apt/lists/*

WORKDIR /jupyter

# Ensure Jupyter uses /jupyter as notebook directory
CMD ["jupyter", "lab", "--ip=0.0.0.0", "--no-browser", "--allow-root", "--NotebookApp.notebook_dir=/jupyter"]
EOF

cat << 'EOF' > "$SCRIPTS_DIR/run-pytorch.sh"
#!/bin/bash
sudo docker build -t xpu-pytorch:latest -f "$HOME/ai/scripts/pytorch/Dockerfile" "$HOME/ai/scripts/pytorch"
sudo docker run -it --rm \
    -p 8888:8888 \
    --device /dev/dri \
    -v /dev/dri/by-path:/dev/dri/by-path \
    --group-add video --group-add render \
    -v "$HOME/ai/pytorch:/jupyter" \
    -w /jupyter \
    xpu-pytorch:latest
EOF

# ==========================================
# 2. OpenVINO Model Server (OVMS) Setup
# ==========================================
echo "Generating OVMS environment..."
cat << 'EOF' > "$SCRIPTS_DIR/run-ovms.sh"
#!/bin/bash
sudo docker pull openvino/model_server:latest-gpu

# Maps ~/ai/ovms to /models in the container
# Port 9000 for gRPC, Port 8000 for REST (OpenAI API Compatible)
sudo docker run -it --rm \
    -p 9000:9000 -p 8000:8000 \
    --device /dev/dri \
    -v /dev/dri/by-path:/dev/dri/by-path \
    --group-add video --group-add render \
    -v "$HOME/ai/ovms:/models" \
    openvino/model_server:latest-gpu \
    --port 9000 --rest_port 8000 --model_repository_path /models
EOF

# ==========================================
# 3. OpenVINO Toolkit (GGUF Conversion/Dev)
# ==========================================
echo "Generating OpenVINO Toolkit environment..."
cat << 'EOF' > "$SCRIPTS_DIR/openvino/Dockerfile"
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update -y && apt-get install -y --no-install-recommends \
    python3-pip python3-venv git curl wget clinfo pciutils && \
    rm -rf /var/lib/apt/lists/*

# Setup virtual environment
RUN python3 -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Install OpenVINO, Optimum Intel, and ecosystem packages for GGUF/model conversions
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir openvino openvino-genai optimum-intel nncf huggingface_hub transformers

WORKDIR /workspace
CMD ["/bin/bash"]
EOF

cat << 'EOF' > "$SCRIPTS_DIR/run-openvino.sh"
#!/bin/bash
sudo docker build -t xpu-openvino:latest -f "$HOME/ai/scripts/openvino/Dockerfile" "$HOME/ai/scripts/openvino"
sudo docker run -it --rm \
    --device /dev/dri \
    -v /dev/dri/by-path:/dev/dri/by-path \
    --group-add video --group-add render \
    -v "$HOME/ai/openvino:/workspace" \
    -w /workspace \
    xpu-openvino:latest
EOF

# ==========================================
# 4. Intel oneAPI BaseKit (DPCPP / SYCL)
# ==========================================
echo "Generating oneAPI environment..."
cat << 'EOF' > "$SCRIPTS_DIR/run-oneapi.sh"
#!/bin/bash
sudo docker pull intel/oneapi-basekit:latest

sudo docker run -it --rm \
    --device /dev/dri \
    -v /dev/dri/by-path:/dev/dri/by-path \
    --group-add video --group-add render \
    -v "$HOME/ai:/workspace" \
    -w /workspace \
    intel/oneapi-basekit:latest \
    /bin/bash
EOF

# ==========================================
# 5. Intel AI Playground Setup
# ==========================================
echo "Generating Intel AI Playground environment..."
cat << 'EOF' > "$SCRIPTS_DIR/playground/Dockerfile"
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# AI Playground dependencies (X11, GL, etc.)
RUN apt-get update -y && apt-get install -y --no-install-recommends \
    curl wget git python3-pip python3-venv libgl1 libglib2.0-0 clinfo pciutils xz-utils \
    && rm -rf /var/lib/apt/lists/*

RUN python3 -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

WORKDIR /playground
CMD ["/bin/bash"]
EOF

cat << 'EOF' > "$SCRIPTS_DIR/run-playground.sh"
#!/bin/bash
sudo docker build -t xpu-playground:latest -f "$HOME/ai/scripts/playground/Dockerfile" "$HOME/ai/scripts/playground"

# Maps port 7860 (common for Gradio/Web UIs)
sudo docker run -it --rm \
    -p 7860:7860 \
    --device /dev/dri \
    -v /dev/dri/by-path:/dev/dri/by-path \
    --group-add video --group-add render \
    -v "$HOME/ai/playground:/playground" \
    -w /playground \
    xpu-playground:latest
EOF

# ==========================================
# Finalize Permissions
# ==========================================
chmod +x "$SCRIPTS_DIR"/run-*.sh
echo "Setup complete! All scripts generated in $SCRIPTS_DIR."

```

---

### 2. XPU Docker Environment Usage Guide

Once the script completes, your `~/ai` directory is the central hub for all Intel Arc operations.

#### Directory Overview

* `~/ai/scripts/`: Contains the run scripts (`run-pytorch.sh`, etc.) and subfolders with their respective Dockerfiles. If you ever need to add a Python package to PyTorch, edit `~/ai/scripts/pytorch/Dockerfile`, and the run script will automatically rebuild the image on the next launch.
* `~/ai/pytorch/`: Your persistent Jupyter workspace. Notebooks saved here survive container restarts.
* `~/ai/openvino/`: Your workspace for downloading and converting models via Optimum Intel.
* `~/ai/ovms/`: Drop your converted OpenVINO models here to serve them.
* `~/ai/playground/`: A persistent folder for downloading the AI Playground `.deb` and storing its configurations.

#### Example 1: Running PyTorch & Jupyter Lab

1. Run the script: `~/ai/scripts/run-pytorch.sh`
2. The terminal will output a Jupyter Lab URL with a token (e.g., `[http://127.0.0.1:8888/lab?token=](http://127.0.0.1:8888/lab?token=)...`).
3. Open that URL in your browser.
4. **Test the GPU:** Open a new notebook and verify PyTorch sees the Arc Pro B70:
```python
import torch
print(f"XPU available: {torch.xpu.is_available()}")
print(f"Device name: {torch.xpu.get_device_name(0)}")

```



#### Example 2: Converting a Model with OpenVINO

To serve a model, you often need to optimize it first.

1. Run the OpenVINO toolkit container: `~/ai/scripts/run-openvino.sh`
2. You will drop into an interactive bash shell in the container.
3. Download and export a model (like Llama 3 or Mistral) to OpenVINO format using Optimum CLI:
```bash
optimum-cli export openvino --model "TinyLlama/TinyLlama-1.1B-Chat-v1.0" --weight-format int8 /workspace/tinyllama-ov

```


4. Exit the container. The converted model is now safely stored on your host in `~/ai/openvino/tinyllama-ov`.

#### Example 3: Serving a Model via OVMS and Connecting via API

1. Move the converted model from the previous step into the OVMS directory:
```bash
mv ~/ai/openvino/tinyllama-ov ~/ai/ovms/tinyllama

```


2. Launch the Model Server: `~/ai/scripts/run-ovms.sh`
3. The server is now listening on port 8000.
4. **Connect a Client (e.g., Continue Extension):** Open your `~/.continue/config.json` and configure it to point to your local OVMS setup:
```json
{
  "models": [
    {
      "title": "Local Arc B70 Model",
      "provider": "openai",
      "model": "tinyllama",
      "apiKey": "empty",
      "apiBase": "http://localhost:8000/v3" 
    }
  ]
}

```


*Because OVMS acts as an OpenAI API drop-in replacement, tools like Continue, Cursor, or the Claude CLI will connect seamlessly.*

#### Example 4: Compiling Native SYCL/DPC++ Code

1. Launch the oneAPI BaseKit container: `~/ai/scripts/run-oneapi.sh`
2. This container maps the *entire* `~/ai` folder to `/workspace`.
3. Create a file `hello.cpp` in `/workspace`:
```cpp
#include <sycl/sycl.hpp>
#include <iostream>
int main() {
    sycl::queue q(sycl::gpu_selector_v);
    std::cout << "Running on: " << q.get_device().get_info<sycl::info::device::name>() << "\n";
    return 0;
}

```


4. Compile and run using the Intel compiler:
```bash
icpx -fsycl hello.cpp -o hello
./hello

```


*It should output: `Running on: Intel(R) Arc(TM) Pro B70 Graphics`.*

#### Example 5: Intel AI Playground

1. Download the latest Intel AI Playground Ubuntu `.deb` file directly to `~/ai/playground` on your host machine.
2. Launch the container: `~/ai/scripts/run-playground.sh`
3. Inside the container shell, install the package:
```bash
dpkg -i /playground/intel-ai-playground_*.deb
apt-get install -f # To resolve any missing dependencies automatically

```


4. Launch the playground web UI inside the container. Since the run script maps port `7860`, you can access the UI in your host's web browser at `
