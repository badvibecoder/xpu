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
# 4. Intel oneAPI Toolkit Setup
# ==========================================
echo "Generating oneAPI environment..."
cat << 'EOF' > "$SCRIPTS_DIR/run-oneapi.sh"
#!/bin/bash
VIDEO_GID=$(getent group video | cut -d: -f3)
RENDER_GID=$(getent group render | cut -d: -f3)

sudo docker pull intel/oneapi-toolkit:latest
sudo docker run -it --rm \
    --device /dev/dri \
    -v /dev/dri/by-path:/dev/dri/by-path \
    --group-add $VIDEO_GID --group-add $RENDER_GID \
    -v "$HOME/ai:/workspace" \
    -w /workspace \
    intel/oneapi-toolkit:latest \
    /bin/bash
EOF

# ==========================================
# 5. Intel AI Playground Setup (GUI & Web)
# ==========================================
echo "Generating Intel AI Playground environment..."
cat << 'EOF' > "$SCRIPTS_DIR/playground/Dockerfile"
FROM ubuntu:24.04
ENV DEBIAN_FRONTEND=noninteractive

# 1. Install prerequisites: GUI, Audio, Intel Compute Runtime, and OpenVINO Backend Dependencies
RUN apt-get update -y && apt-get install -y --no-install-recommends \
    curl wget git python3-pip python3-venv libgl1 libglib2.0-0 \
    clinfo pciutils xz-utils ca-certificates \
    libx11-6 libxext6 libxrender1 libxrandr2 libxtst6 libxi6 \
    libasound2t64 libasound2-data \
    intel-opencl-icd intel-level-zero-gpu level-zero \
    build-essential python3-dev libtbb12 libhwloc15 libgomp1 libnuma1 libpython3.12 \
    && rm -rf /var/lib/apt/lists/*

# 2. Download and install the AI Playground .deb package
RUN wget -q "https://github.com/intel/AI-Playground/releases/download/v3.1.2-beta_hf3/AI-Playground-installer.deb" -O /tmp/ai-playground.deb && \
    apt-get update -y && \
    apt-get install -y /tmp/ai-playground.deb && \
    rm /tmp/ai-playground.deb && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /playground

# 3. Auto-launch the Electron app with the mandatory Docker sandbox flag
CMD ["ai-playground", "--no-sandbox"]
EOF

cat << 'EOF' > "$SCRIPTS_DIR/run-playground.sh"
#!/bin/bash
VIDEO_GID=$(getent group video | cut -d: -f3)
RENDER_GID=$(getent group render | cut -d: -f3)

# Allow local Docker containers to connect to the host's X11 display server
xhost +local:docker > /dev/null 2>&1

# FORCE a clean build to ensure the missing libraries are actually downloaded
sudo docker build --no-cache -t xpu-playground:latest -f "$HOME/ai/scripts/playground/Dockerfile" "$HOME/ai/scripts/playground"

# Launch the app with full X11 mapping and local persistence
sudo docker run -it --rm \
    --network host \
    -e DISPLAY=$DISPLAY \
    -v /tmp/.X11-unix:/tmp/.X11-unix:ro \
    --device /dev/dri \
    -v /dev/dri/by-path:/dev/dri/by-path \
    --group-add $VIDEO_GID --group-add $RENDER_GID \
    -u $(id -u):$(id -g) \
    -v /etc/passwd:/etc/passwd:ro \
    -v /etc/group:/etc/group:ro \
    -v "$HOME/ai/playground:/playground" \
    -e HOME="/playground" \
    -w /playground \
    xpu-playground:latest
EOF

# ==========================================
# 6. OpenClaude "Supercharged" Agent Setup
# ==========================================
echo "Generating OpenClaude Coding Agent environment..."
cat << 'EOF' > "$SCRIPTS_DIR/openclaude/Dockerfile"
# Use Intel oneAPI Toolkit as the base so the agent has native C++, Python, and SYCL/Level Zero drivers
FROM intel/oneapi-toolkit:latest

ENV DEBIAN_FRONTEND=noninteractive

# 1. Install Node.js 22, Network Tools, and Dev Utilities
RUN apt-get update -y && \
    apt-get install -y ca-certificates curl gnupg && \
    mkdir -p /etc/apt/keyrings && \
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg && \
    echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_22.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list && \
    apt-get update -y && \
    apt-get install -y \
        nodejs \
        iputils-ping dnsutils openssh-client telnet netcat-openbsd curl wget iproute2 \
        build-essential gdb cmake git ripgrep jq bash \
        python3 python3-pip && \
    rm -rf /var/lib/apt/lists/*

# 2. Install Odin Compiler (Pulls the latest Linux/AMD64 release)
RUN cd /opt && \
    LATEST_URL=$(curl -sL https://api.github.com/repos/odin-lang/Odin/releases/latest | grep -o '"browser_download_url": "[^"]*linux[^"]*amd64[^"]*\.tar\.gz"' | head -1 | cut -d'"' -f4) && \
    if [ -z "$LATEST_URL" ]; then \
        echo "Falling back to known Odin release..."; \
        LATEST_URL="https://github.com/odin-lang/Odin/releases/download/dev-2025-12a/odin-linux-amd64-dev-2025-12a.tar.gz"; \
    fi && \
    wget -q "$LATEST_URL" -O odin.tar.gz && \
    mkdir odin && \
    tar -xzf odin.tar.gz -C odin --strip-components=1 && \
    ln -s /opt/odin/odin /usr/local/bin/odin && \
    rm odin.tar.gz

# 3. Install OpenClaude
RUN npm install -g @gitlawb/openclaude@latest

# 4. Pre-create the agent's home folder with global write access
RUN mkdir -p /home/agent && chmod 777 /home/agent

ENTRYPOINT ["openclaude"]
EOF

cat << 'EOF' > "$SCRIPTS_DIR/run-openclaude.sh"
#!/bin/bash
VIDEO_GID=$(getent group video | cut -d: -f3)
RENDER_GID=$(getent group render | cut -d: -f3)

sudo docker build -t xpu-openclaude:latest -f "$HOME/ai/scripts/openclaude/Dockerfile" "$HOME/ai/scripts/openclaude" -q

mkdir -p "$HOME/.openclaude"

GIT_MOUNT=""
if [ -f "$HOME/.gitconfig" ]; then
    GIT_MOUNT="-v $HOME/.gitconfig:/home/agent/.gitconfig:ro"
fi

# Run mapped to current directory with GPU access, networking, and User fix
sudo docker run -it --rm \
    --network host \
    --device /dev/dri \
    -v /dev/dri/by-path:/dev/dri/by-path \
    --group-add $VIDEO_GID --group-add $RENDER_GID \
    -u $(id -u):$(id -g) \
    -v /etc/passwd:/etc/passwd:ro \
    -v /etc/group:/etc/group:ro \
    -e HOME="/home/agent" \
    -e TERM=xterm-256color \
    -v "$HOME/.openclaude:/home/agent/.openclaude" \
    -e CLAUDE_CODE_USE_OPENAI="1" \
    -e OPENAI_BASE_URL="http://127.0.0.1:8000/v3/" \
    -e OPENAI_API_KEY="ovms" \
    -e CLAUDE_PROJECT_DETECTION="loose" \
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
