#!/usr/bin/env bash

# Exit immediately if any command fails
set -e

echo "=========================================================="
echo " Starting Intel GPU Hardware Acceleration Setup for OBS   "
echo " Target OS: Fedora 44 Workstation (KDE Plasma / DNF5)     "
echo "=========================================================="

# 1. Ensure user is in the correct groups to access rendering hardware
echo "--> Configuring user hardware group permissions..."
sudo usermod -a -G video,render $USER

# 2. Install RPM Fusion Free and Nonfree Repositories
echo "--> Installing RPM Fusion repositories..."
sudo dnf install -y \
  https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-44.noarch.rpm \
  https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-44.noarch.rpm

# 3. Swap out restricted Intel drivers for full hardware-enabled drivers
echo "--> Replacing restricted media drivers with full-featured versions..."
sudo dnf install -y intel-media-driver --repo=rpmfusion-nonfree

# 4. Swap restricted ffmpeg-free packages for full-featured ffmpeg
# This ensures that standard audio encoders like libfdk AAC and multimedia pipelines work out-of-the-box
echo "--> Swapping system ffmpeg-free to full ffmpeg framework..."
sudo dnf swap -y ffmpeg-free ffmpeg --allowerasing

# 5. Install OBS Studio and VA-API diagnostic utilities
echo "--> Installing OBS Studio and libva utilities..."
sudo dnf install -y obs-studio libva-utils

echo "=========================================================="
echo " Setup Complete! "
echo " Please LOG OUT and LOG BACK IN (or reboot) for group permissions to apply."
echo "=========================================================="
echo ""
echo " To validate success after logging back in, execute: vainfo"
echo " Look for: 'VAProfileH264High : VAEntrypointEncSlice'"
echo ""
echo " In OBS Settings > Output > Recording:"
echo " - Select Video Encoder: 'VAAPI H.264'"
echo " - Select Rate Control: 'ICQ' (Level 20)"
echo " - Select Keyframe Interval: '2 s'"
echo "=========================================================="