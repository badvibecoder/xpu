
# Update Fedora and reboot
# # # # # # # # # # # # # #
#sudo dnf update -y
#sudo reboot
# # # # # # # # # # # # # #

# Basic Utilities
sudo dnf install vim wget curl git openssh rclone openrgb openrgb-udev-rules -y

# Enable SSH server
sudo systemctl enable sshd
sudo systemctl start sshd

# OpenRGB modeprobe
sudo modprobe i2c-dev
sudo modprobe i2c-i801
# Open OpenRGB, configure - when prompted 12 leds for each zone, save close

# Download chrome/vscode
wget -O ~/Downloads/chrome.rpm https://dl.google.com/linux/direct/google-chrome-stable_current_x86_64.rpm
wget -O ~/Downloads/code.rpm https://vscode.download.prss.microsoft.com/dbazure/download/stable/8a7abeba6e03ea3af87bfbce9a1b7e48fed567b8/code-1.129.1-1784303689.el8.x86_64.rpm
# Install chrome/vscode
sudo dnf install ~/Downloads/chrome.rpm ~/Downloads/code.rpm -y
# Login to chrome, login to msft account

# Install Odin
sudo dnf copr enable sisyphus1813/odin-lang -y
sudo dnf install odin-lang ols clang -y
echo 'export ODIN_ROOT="/usr/lib/odin"' >> ~/.bashrc
####
# In coderunner
#
# In "Echo-runner.executorMap":{
# add 
# "odin": "cd $dir && odin build $fileName -file -out:$fileNameWithoutExt && ./$fileNameWithoutExt; rm -f $fileNameWithoutExt",
#
# In "code-runner.executorMapByFileExtension": {
# add
# ".odin": "cd $dir && odin build $fileName -file -out:$fileNameWithoutExt && ./$fileNameWithoutExt; rm -f $fileNameWithoutExt",
#
####

# Rclone setup - Setup your browser and login to msft account first
mkdir ~/OneDrive
rclone config

# Create rclone service file
sudo tee /etc/systemd/system/onedrive.service <<'EOF'
[Unit]
Description=OneDrive over rclone Daemon
After=network-online.target
Wants=network-online.target

[Service]
User=pcarroll
Type=simple
ExecStart=/usr/bin/rclone --vfs-cache-mode writes mount OneDrive: /home/pcarroll/OneDrive/ --config /home/pcarroll/.config/rclone/rclone.conf
ExecReload=/bin/kill -s HUP $MAINPID
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
# Enable and start service
sudo systemctl daemon-reload && sudo systemctl enable onedrive.service && sudo systemctl start onedrive.service && sudo systemctl status onedrive.service

# Intel ARC Driver and Related Packages - Some of these will already be installed
sudo dnf install libva-intel-media-driver mesa-dri-drivers mesa-vulkan-drivers mesa-va-drivers -y
sudo dnf install intel-compute-runtime intel-level-zero intel-level-zero-devel intel-ocloc intel-opencl clinfo libvpl libva-utils intel-level-zero-gpu-raytracing -y
# Enable nonfree repo
sudo dnf install https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm -y
# Oneapi required items
sudo dnf group install development-tools -y
sudo dnf install cmake pkgconfig -y
sudo dnf install gcc-c++ -y
# Add user to video,render groups, this will be required for other uses
sudo usermod -aG video,render $USER
# Validate GPU is showing
clinfo | grep "Device Name"
lspci -nnk | grep -A3 VGA
# Validate primary GPU is listed as GPU0
vulkaninfo --summary
# Update Fedora and reboot
# # # # # # # # # # # # # #
# At this point we can install oneapi basetoolkit with either the yum package or the sh offline script
# yum will install /opt/intel/oneapi vs ~/intel/oneapi for the offline script.
# sudo yum install intel-oneapi-toolkit -y
# # # # # # # # # # # # # #

# Docker Installation and test
sudo dnf remove docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-selinux docker-engine-selinux docker-engine -y
sudo dnf install dnf-plugins-core -y
sudo dnf config-manager addrepo --from-repofile=https://download.docker.com/linux/fedora/docker-ce.repo
sudo dnf install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y
sudo systemctl enable docker
sudo systemctl start docker
sudo docker run hello-world

# Install uv and atuin
curl -LsSf https://astral.sh/uv/install.sh | sh
curl --proto '=https' --tlsv1.2 -LsSf https://setup.atuin.sh | sh
# Sometimes atuin will not setup ~/.bashrc correctly, make sure you have this:
####
. "$HOME/.atuin/bin/env"
eval "$(atuin init bash)"
####

# Install Ollama and configure for Vulkan (ARC GPU)
curl -fsSL https://ollama.com/install.sh | sh
# Edit ollama service
sudo systemctl edit ollama.service
####
[Service]
Environment="OLLAMA_VULKAN=1"
Environment="GGML_VK_VISIBLE_DEVICES=0"
Environment="OLLAMA_FLASH_ATTENTION=1"
Environment="OLLAMA_KV_CACHE_TYPE=q8_0"
####
# save and exit
sudo systemctl daemon-reload && sudo systemctl restart ollama.service

# Install Steam
sudo dnf install steam -y

# Install OBS
sudo dnf install obs-studio -y
####
#In OBS Settings > Output > Recording:
#Select Recording Format: 'Maktroska'
#Select Audio Encoder: 'libfdk AAC'
#Select Video Encoder: 'Quicksync H.264'
#Select Rate Control: 'ICQ' (Level 20)
#Select Target Usage: 'TU1"
#Select Keyframe Interval: '2 s'"
#Select B-Frames: '3'"
####

# Install Luanti (Minecraft)
flatpak remote-add --if-not-exists flathub https://flathub.org
flatpak install flathub org.luanti.luanti

# Install Open WebUI
sudo dnf install snapd
sudo snap install open-webui

# Go ahead and reboot again
sudo reboot
