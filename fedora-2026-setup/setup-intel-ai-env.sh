#!/bin/bash
# setup-intel-ai-env.sh
# Master Setup Script: Generates a standardized Intel Arc / XPU Docker environment.

AI_DIR="$HOME/ai"
SCRIPTS_DIR="$AI_DIR/scripts"

echo "Creating folder structure in $AI_DIR..."
mkdir -p "$AI_DIR"/{ovms,openvino,pytorch,playground}
mkdir -p "$SCRIPTS_DIR"/{ovms,openvino,pytorch,oneapi,playground,openclaude}
# Pre-create the cache folder so it is owned by the host user
mkdir -p "$AI_DIR/ovms/.ov_cache"

# ==========================================
# 1. PyTorch (Native XPU) Setup
# ==========================================
echo "Generating PyTorch environment..."
cat << 'EOF' > "$SCRIPTS_DIR/pytorch/Dockerfile"
FROM intel/pytorch:latest

# Added jupyterlab and machine learning packages
RUN pip install --no-cache-dir jupyterlab scikit-learn ipywidgets IProgress transformers matplotlib sentencepiece openai-whisper accelerate

# Install system dependencies
RUN apt update -y && apt install ffmpeg -y && rm -rf /var/lib/apt/lists/*

WORKDIR /jupyter
CMD ["jupyter", "lab", "--ip=0.0.0.0", "--no-browser", "--allow-root", "--NotebookApp.notebook_dir=/jupyter"]
EOF

cat << 'EOF' > "$SCRIPTS_DIR/run-pytorch.sh"
#!/bin/bash
VIDEO_GID=$(getent group video | cut -d: -f3)
RENDER_GID=$(getent group render | cut -d: -f3)

sudo docker build -t xpu-pytorch:latest -f "$HOME/ai/scripts/pytorch/Dockerfile" "$HOME/ai/scripts/pytorch"
sudo docker run -it --rm \
    -p 8888:8888 \
    --device /dev/dri \
    -v /dev/dri/by-path:/dev/dri/by-path \
    --group-add $VIDEO_GID --group-add $RENDER_GID \
    -v "$HOME/ai/pytorch:/jupyter" \
    -w /jupyter \
    xpu-pytorch:latest
EOF

# ==========================================
# 2. OpenVINO Model Server (OVMS) Setup
# ==========================================
echo "Generating OVMS utilities and environment..."

cat << 'EOF' > "$SCRIPTS_DIR/download-hf-ovms.sh"
#!/bin/bash
if [ -z "$1" ] || [ -z "$2" ]; then
    echo "Usage: ./download-hf-ovms.sh <huggingface-repo-id> <local-model-name>"
    echo "Example: ./download-hf-ovms.sh OpenVINO/Qwen1.5-7B-Chat-int8-ov qwen-chat"
    exit 1
fi

REPO_ID=$1
MODEL_NAME=$2
TARGET_DIR="/models/$MODEL_NAME/1"

echo "=========================================================="
echo " Downloading $REPO_ID"
echo " Destination: ~/ai/ovms/$MODEL_NAME/1"
echo "=========================================================="

# We map the user ID here as well so downloaded models are owned by you, not root
sudo docker run -it --rm \
    -u $(id -u):$(id -g) \
    -v "$HOME/ai/ovms:/models" \
    -e HOME="/models" \
    python:3.12-slim \
    bash -c "pip install --quiet --no-cache-dir huggingface_hub && \
             HF_XET_HIGH_PERFORMANCE=1 hf download $REPO_ID --local-dir $TARGET_DIR"

echo "=========================================================="
echo " Success! Start OVMS with: ~/ai/scripts/run-ovms.sh $MODEL_NAME"
echo "=========================================================="
EOF

cat << 'EOF' > "$SCRIPTS_DIR/run-ovms.sh"
#!/bin/bash
if [ -z "$1" ]; then
    echo "Usage: ./run-ovms.sh <model_folder_name>"
    echo "Available models in $HOME/ai/ovms:"
    ls -1 "$HOME/ai/ovms" | grep -v ".ov_cache"
    exit 1
fi

MODEL_NAME=$1

VIDEO_GID=$(getent group video | cut -d: -f3)
RENDER_GID=$(getent group render | cut -d: -f3)

sudo docker pull openvino/model_server:latest-gpu

sudo docker run -it --rm \
    -p 9000:9000 -p 8000:8000 \
    -u $(id -u):$(id -g) \
    --device /dev/dri \
    -v /dev/dri/by-path:/dev/dri/by-path \
    --group-add $VIDEO_GID --group-add $RENDER_GID \
    -v "$HOME/ai/ovms:/models" \
    openvino/model_server:latest-gpu \
    --port 9000 --rest_port 8000 \
    --model_name "$MODEL_NAME" \
    --model_path "/models/$MODEL_NAME/1" \
    --task text_generation \
    --target_device GPU \
    --cache_dir "/models/.ov_cache"
EOF

# ==========================================
# 3. OpenVINO Toolkit Setup
# ==========================================
echo "Generating OpenVINO Toolkit environment..."
cat << 'EOF' > "$SCRIPTS_DIR/openvino/Dockerfile"
FROM ubuntu:24.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update -y && apt-get install -y --no-install-recommends \
    python3-pip python3-venv git curl wget clinfo pciutils && rm -rf /var/lib/apt/lists/*
RUN python3 -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir openvino openvino-genai optimum-intel nncf huggingface_hub transformers
WORKDIR /workspace
CMD ["/bin/bash"]
EOF

cat << 'EOF' > "$SCRIPTS_DIR/run-openvino.sh"
#!/bin/bash
VIDEO_GID=$(getent group video | cut -d: -f3)
RENDER_GID=$(getent group render | cut -d: -f3)

sudo docker build -t xpu-openvino:latest -f "$HOME/ai/scripts/openvino/Dockerfile" "$HOME/ai/scripts/openvino"
sudo docker run -it --rm \
    --device /dev/dri \
    -v /dev/dri/by-path:/dev/dri/by-path \
    --group-add $VIDEO_GID --group-add $RENDER_GID \
    -v "$HOME/ai/openvino:/workspace" \
    -w /workspace \
    xpu-openvino:latest
EOF

# ==========================================
# 4. Intel oneAPI BaseKit Setup
# ==========================================
echo "Generating oneAPI environment..."
cat << 'EOF' > "$SCRIPTS_DIR/run-oneapi.sh"
#!/bin/bash
VIDEO_GID=$(getent group video | cut -d: -f3)
RENDER_GID=$(getent group render | cut -d: -f3)

sudo docker pull intel/oneapi-basekit:latest
sudo docker run -it --rm \
    --device /dev/dri \
    -v /dev/dri/by-path:/dev/dri/by-path \
    --group-add $VIDEO_GID --group-add $RENDER_GID \
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
RUN apt-get update -y && apt-get install -y --no-install-recommends \
    curl wget git python3-pip python3-venv libgl1 libglib2.0-0 clinfo pciutils xz-utils && rm -rf /var/lib/apt/lists/*
RUN python3 -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"
WORKDIR /playground
CMD ["/bin/bash"]
EOF

cat << 'EOF' > "$SCRIPTS_DIR/run-playground.sh"
#!/bin/bash
VIDEO_GID=$(getent group video | cut -d: -f3)
RENDER_GID=$(getent group render | cut -d: -f3)

sudo docker build -t xpu-playground:latest -f "$HOME/ai/scripts/playground/Dockerfile" "$HOME/ai/scripts/playground"
sudo docker run -it --rm \
    -p 7860:7860 \
    --device /dev/dri \
    -v /dev/dri/by-path:/dev/dri/by-path \
    --group-add $VIDEO_GID --group-add $RENDER_GID \
    -v "$HOME/ai/playground:/playground" \
    -w /playground \
    xpu-playground:latest
EOF

# ==========================================
# 6. OpenClaude Coding Agent Setup
# ==========================================
echo "Generating OpenClaude Coding Agent environment..."
cat << 'EOF' > "$SCRIPTS_DIR/openclaude/Dockerfile"
FROM node:22-slim

RUN apt-get update -y && apt-get install -y git ripgrep && rm -rf /var/lib/apt/lists/*
RUN npm install -g @gitlawb/openclaude@latest

# Pre-create the agent's home folder with global write access to prevent silent permission crashes
RUN mkdir -p /home/agent && chmod 777 /home/agent

ENTRYPOINT ["openclaude"]
EOF

cat << 'EOF' > "$SCRIPTS_DIR/run-openclaude.sh"
#!/bin/bash
sudo docker build -t xpu-openclaude:latest -f "$HOME/ai/scripts/openclaude/Dockerfile" "$HOME/ai/scripts/openclaude" -q

mkdir -p "$HOME/.openclaude"

GIT_MOUNT=""
if [ -f "$HOME/.gitconfig" ]; then
    GIT_MOUNT="-v $HOME/.gitconfig:/home/agent/.gitconfig:ro"
fi

# Run natively mapped to your current directory with TTY and User fix
sudo docker run -it --rm \
    --network host \
    -u $(id -u):$(id -g) \
    -v /etc/passwd:/etc/passwd:ro \
    -v /etc/group:/etc/group:ro \
    -e HOME="/home/agent" \
    -e TERM=xterm-256color \
    -v "$HOME/.openclaude:/home/agent/.openclaude" \
    -e CLAUDE_CODE_USE_OPENAI="1" \
    -e OPENAI_BASE_URL="http://127.0.0.1:8000/v3/" \
    -e OPENAI_API_KEY="ovms" \
    -v "$PWD:/workspace" \
    $GIT_MOUNT \
    -w /workspace \
    xpu-openclaude:latest "$@"
EOF

# ==========================================
# Finalize Permissions
# ==========================================
chmod +x "$SCRIPTS_DIR"/*.sh
echo "Setup complete! Ground truth environment updated in $SCRIPTS_DIR."
