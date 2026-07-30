# Intel Arc (XPU) AI/ML & Agent Development Environment

A high-performance, standardized, containerized development environment designed for Intel Arc GPUs (specifically tuned for the Intel Arc Pro B70 on Fedora). This setup provisions a clean workspace containing PyTorch with native XPU acceleration, OpenVINO Model Server for low-latency LLM inference, oneAPI tools, OpenVINO GenAI tools, and the terminal-native OpenClaude coding agent.

---

## 1. System & Hardware Requirements

### Hardware Requirements
* **GPU:** Intel Arc Pro B70 GPU (or other Intel Arc Discrete/Integrated GPUs).
* **VRAM:** 16GB+ recommended (32GB VRAM ideal for 30B LLMs like Qwen3-Coder-30B).
* **Storage:** Fast NVMe SSD with at least 50GB–100GB space (for `.ov_cache` compilation files and quantized models).

### Software Requirements
* **Operating System:** Fedora Workstation (Fedora 44 tested, standard modern Linux distros supported).
* **Linux Kernel:** 6.12+ (Kernel 7.1+ with native `xe` driver support recommended).
* **Driver Stack:** `intel-xe-kmod` / Mesa Level Zero drivers providing `/dev/dri` render nodes.
* **Core Utilities:** `docker`, `sudo`, `bash`, `getent`, `curl`, `git`.

---

## 2. Directory Architecture

Running the setup script establishes a centralized `$HOME/ai` directory structure:

```text
~/ai/
├── ovms/                # Local OpenVINO LLMs & compiled graph cache (.ov_cache)
├── openvino/            # OpenVINO SDK workspace
├── pytorch/             # PyTorch & Jupyter Lab workspace
├── playground/          # Prototyping & web UI workspace
└── scripts/             # Standardized operational wrappers
    ├── setup-intel-ai-env.sh  # Master environment generator
    ├── download-hf-ovms.sh    # HuggingFace model downloader
    ├── run-ovms.sh            # OpenVINO Model Server launcher
    ├── run-openclaude.sh      # OpenClaude coding agent container wrapper
    ├── run-pytorch.sh         # PyTorch/Jupyter environment launcher
    ├── run-openvino.sh        # OpenVINO SDK interactive container launcher
    ├── run-oneapi.sh          # Intel oneAPI BaseKit environment wrapper
    └── run-playground.sh      # AI Playground container wrapper
```

## 3. Master Setup Script (setup-intel-ai-env.sh)

**Purpose**

The setup-intel-ai-env.sh script acts as the single source of truth for the entire setup. It dynamically detects host hardware render groups (video and render GIDs) to configure Docker containers with seamless host GPU hardware access (/dev/dri).

***Usage***

```Bash
# 1. Make the master script executable
chmod +x ~/setup-intel-ai-env.sh

# 2. Run the master script to generate all execution scripts and directory structures
~/setup-intel-ai-env.sh
```

## 4. Generated Scripts & Operational Guide

### 4.1 Model Downloader (download-hf-ovms.sh)

Downloads OpenVINO-quantized HuggingFace models directly into the standard OVMS directory structure while preserving host file ownership.

**Usage:**

```Bash
~/ai/scripts/download-hf-ovms.sh <huggingface-repo-id> <local-model-name>
```

Example:

```Bash
~/ai/scripts/download-hf-ovms.sh OpenVINO/Qwen3-Coder-30B-A3B-Instruct-int4-ov Qwen3-Coder-30B-A3B-Instruct-int4-ov
```

### 4.2 OpenVINO Model Server (run-ovms.sh)

Hosts downloaded LLMs using the official Intel GPU-accelerated OVMS image. It exposes OpenAI-compatible REST API endpoints at http://localhost:8000/v3/.

**Key Capabilities:**

Uses --task text_generation to enable Continuous Batching and Paged Attention.

Compiles high-performance execution graphs directly to Intel Arc via --target_device GPU.

Caches compiled graphs in ~/ai/ovms/.ov_cache to ensure instant subsequent boots.

**Usage:**

```Bash
~/ai/scripts/run-ovms.sh <model_folder_name>
```

**Example:**

```Bash
~/ai/scripts/run-ovms.sh Qwen3-Coder-30B-A3B-Instruct-int4-ov
```

**Verification:**

Open a separate terminal and test the model server endpoint:

```Bash
curl http://localhost:8000/v3/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "Qwen3-Coder-30B-A3B-Instruct-int4-ov",
    "messages": [{"role": "user", "content": "Respond with: Ready"}]
  }'
```

### 4.3 OpenClaude AI Coding Agent (run-openclaude.sh)

Launches the OpenClaude terminal coding agent isolated inside a container while mapping host capabilities.

**Key Capabilities:**

Configured via `-e CLAUDE_CODE_USE_OPENAI="1"` and `-e OPENAI_BASE_URL="http://127.0.0.1:8000/v3/"` to route directly to local OVMS LLMs.

Dynamically mounts your current host working directory (-v "$PWD:/workspace") so it can read and edit code files natively.

Preserves user UID/GID `(-u $(id -u):$(id -g))` and host user mapping (/etc/passwd), ensuring code modified by the agent remains owned by you.

**Usage:**

Navigate to any project directory on your machine and start the agent:

```ash
cd /path/to/your/code-project
~/ai/scripts/run-openclaude.sh --model Qwen3-Coder-30B-A3B-Instruct-int4-ov
```

### 4.4 PyTorch with Native XPU (run-pytorch.sh)

Launches an interactive JupyterLab environment running Intel's official PyTorch image, compiled with native SYCL/XPU device acceleration.

**Usage:**

```Bash
~/ai/scripts/run-pytorch.sh
```

**Access:** Open http://localhost:8888 in your browser.

Verification inside Jupyter:

```Python
import torch
print(torch.xpu.is_available())        # Should return True
print(torch.xpu.get_device_name(0))   # Should output your Intel Arc GPU
```
### 4.5 OpenVINO Toolkit Pipeline (export-hf-to-ovms.sh & run-openvino.sh)

The OpenVINO environment provides a complete pipeline to download, quantize, and export Hugging Face models directly to your OpenVINO Model Server (OVMS) folder structure. It leverages `optimum-cli` to handle the heavy lifting.

### 4.5.1 Automated Export Pipeline (export-hf-to-ovms.sh)
This wrapper automatically downloads a Hugging Face model to a shared cache, translates it to OpenVINO Intermediate Representation (IR), applies quantization, and outputs the final model to your `~/ai/ovms/` directory.

**Usage:**

```bash
~/ai/scripts/export-hf-to-ovms.sh <hf-repo-id> <local-model-name> [precision] [hf-token]
```

Parameters:

- hf-repo-id (Required): The exact Hugging Face model repository ID (e.g., Qwen/Qwen3-Coder-14B-Instruct).
- local-model-name (Required): The name of the folder created in ~/ai/ovms/ to store the model. OVMS expects this to match the --model_name flag when starting the server.
- precision (Optional, Default: int4): The weight format. Supported values include int4, int8, and fp16.  
- hf-token (Optional): A Hugging Face token required to download gated or private models.

Under the Hood:

The script utilizes the following critical flags with optimum-cli:  

-`--task text-generation-with-past`: Ensures the model graph is exported with stateful Key-Value (KV) caching, a strict requirement for efficient text generation on OVMS.
- `--trust-remote-code`: Allows the compiler to execute the model's custom Python code during the translation process.

Example (Exporting Qwen3 Coder 14B at INT8):

```bash
~/ai/scripts/export-hf-to-ovms.sh Qwen/Qwen3-Coder-14B-Instruct qwen3-coder-14b int8 YOUR_HF_TOKEN
```

After a successful export, you can immediately serve the model by running: ./run-ovms.sh qwen3-coder-14b

### 4.5.2 Interactive Shell (run-openvino.sh)

Provides an interactive container shell pre-loaded with openvino, openvino-genai, optimum-intel, nncf, and transformers. This is useful for manual model conversion, advanced graph tweaking, or offline benchmarking.

Usage:

```bash
~/ai/scripts/run-openvino.sh
```

This maps your local ~/ai/openvino/ directory into the container's /workspace/ folder.

### 4.6 Intel oneAPI IDE Integration (VS Code Dev Containers)

For native C++ and SYCL development targeting Intel Arc GPUs, you can mount project folders directly into an isolated VS Code Dev Container using the unified `intel/oneapi-toolkit` environment.

#### Required VS Code Extensions
From the VS Code Marketplace, search for and install:
* **Dev Containers** (`ms-vscode-remote.remote-containers`)

#### Project Directory Setup
To create a clean workspace with container isolation, navigate to your desired project location and initialize the required folder structure:

```bash
# 1. Create and navigate into your project root
mkdir -p ~/projects/sycl-demo && cd ~/projects/sycl-demo

# 2. Create the hidden .devcontainer configuration directory
mkdir -p .devcontainer
```

Creating `.devcontainer/devcontainer.json`

Inside `.devcontainer/devcontainer.json`, define the container configuration, GPU device mappings, and automatic extension installation:

```json
{
  "name": "Intel oneAPI XPU Environment",
  "image": "intel/oneapi-toolkit:latest",
  "containerUser": "root",
  "runArgs": [
    "--device=/dev/dri",
    "--net=host"
  ],
  "customizations": {
    "vscode": {
      "extensions": [
        "ms-vscode.cpptools",
        "ms-vscode.cmake-tools",
        "intel-corporation.oneapi-analysis-configurator"
      ]
    }
  },
  "postStartCommand": "echo 'source /opt/intel/oneapi/setvars.sh' >> ~/.bashrc"
}
```

Engaging the Container Environment in VS Code

Open VS Code: `code ~/projects/sycl-demo`

Open the Command Palette `(Ctrl + Shift + P)`.

Run: `Dev Containers: Reopen in Container`.

VS Code will pull/build the image and re-attach the workspace inside the container.

Manual Terminal Build & Run Workflow
Once attached to the container, open the integrated terminal `(Ctrl + ~)`. The setvars.sh environment script will automatically source, providing full access to `icpx`.

Create a test SYCL file `(main.cpp)`:

#include <sycl/sycl.hpp>
#include <iostream>

```cpp
int main() {
    sycl::queue q;
    std::cout << "Selected Device: " 
              << q.get_device().get_info<sycl::info::device::name>() 
              << std::endl;
    return 0;
}
```

Compile with `icpx` (SYCL flag enabled):

```bash
icpx -fsycl main.cpp -o sycl_app
```

Execute the binary:

```bash
./sycl_app
```

### 4.7 AI Playground (run-playground.sh)
A utility environment prepared for hosting local Web UIs (Gradio, Streamlit, or Intel AI Playground) mapped to port 7860.

**Usage:**

```Bash
~/ai/scripts/run-playground.sh
```

## 5. Typical Workflow Example

**Bootstrap Environment:**

```Bash
chmod +x setup-intel-ai-env.sh
./setup-intel-ai-env.sh
```

**Download an OpenVINO Model:**

```Bash
~/ai/scripts/download-hf-ovms.sh OpenVINO/Qwen3-Coder-30B-A3B-Instruct-int4-ov Qwen3-Coder-30B-A3B-Instruct-int4-ov
```

**Start the OpenVINO GPU Server:**

```Bash
~/ai/scripts/run-ovms.sh Qwen3-Coder-30B-A3B-Instruct-int4-ov
```

**Launch OpenClaude Agent in a Project Folder:**

```Bash
cd ~/Github/my-python-app
~/ai/scripts/run-openclaude.sh --model Qwen3-Coder-30B-A3B-Instruct-int4-ov
```
