#!/usr/bin/env bash

# Update system
sudo dnf update -y
# you should reboot here

# Enable AppStream / Tainted repos for hardware-accelerated codecs
sudo dnf config-manager setopt rpmfusion-free-tainted.enabled=1 rpmfusion-nonfree-tainted.enabled=1

# Install base tools
sudo dnf install vim wget curl git openssh rclone clang cmake pkgconfig gcc-c++ -y

# Install openrgb
sudo dnf install openrgb openrgb-udev-rules
sudo modprobe i2c-dev
sudo modprobe i2c-i801
# Setup rgb, toggle off then static

# Disable wifi and bt
nmcli radio wifi off
#nmcli radio wifi on
rfkill block bluetooth
#rfkill unblock bluetooth

# Download chrome/vscode
wget https://dl.google.com/linux/direct/google-chrome-stable_current_x86_64.rpm
wget https://vscode.download.prss.microsoft.com/dbazure/download/stable/8a7abeba6e03ea3af87bfbce9a1b7e48fed567b8/code-1.129.1-1784303689.el8.x86_64.rpm
# Install chrome/vscode
sudo dnf install ./google-chrome-stable_current_x86_64.rpm ./code-1.129.1-1784303689.el8.x86_64.rpm -y

#enable openssh server
sudo systemctl enable sshd
sudo systemctl start sshd

# Run github setup script

# Set taskbar panel height to 40px

# Install Intel related drivers
sudo dnf install https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm -y
sudo dnf install mesa-dri-drivers mesa-vulkan-drivers mesa-va-drivers -y
sudo dnf install intel-compute-runtime intel-level-zero intel-level-zero-devel intel-ocloc intel-opencl intel-level-zero-gpu-raytracing libvpl clinfo -y
sudo dnf install rpmfusion-nonfree-obsolete-packages -y
sudo dnf install intel-media-driver --repo=rpmfusion-nonfree libva-utils -y
sudo usermod -aG video,render $USER
sudo dnf group install development-tools -y
clinfo | grep "Device Name"
lspci -nnk | grep -A3 VGA
# At this point we can install oneapi with either the yum package or the sh offline script
# yum will install /opt/intel/oneapi vs ~/intel/oneapi for the offline script.
#sudo yum install intel-oneapi-toolkit -y

# Install fake minecraft luanti
flatpak remote-add --if-not-exists flathub https://flathub.org
flatpak install flathub org.luanti.luanti

# Install steam
sudo dnf install steam -y

# Install OBS Studio
sudo dnf install obs-studio -y

# Install uv and ollama
curl -LsSf https://astral.sh/uv/install.sh | sh
curl -fsSL https://ollama.com/install.sh | sh

# Edit ollama service
sudo systemctl edit ollama.service
# Add the following
[Service]
Environment="OLLAMA_VULKAN=1"
Environment="GGML_VK_VISIBLE_DEVICES=0"
# save and exit
sudo systemctl daemon-reload
sudo systemctl restart ollama.service

# Pull some ollama models
# test pull
ollama pull qwen3.5:0.8b

# Setup Docker
sudo dnf remove docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-selinux docker-engine-selinux docker-engine
sudo dnf install -y dnf-plugins-core
sudo dnf config-manager addrepo --from-repofile=https://download.docker.com/linux/fedora/docker-ce.repo
sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo systemctl enable docker
sudo systemctl start docker
sudo docker run hello-world

# Install Odin
sudo dnf copr enable -y sisyphus1813/odin-lang
sudo dnf install -y odin-lang ols

# Install hyperfine
sudo dnf install hyperfine -y
