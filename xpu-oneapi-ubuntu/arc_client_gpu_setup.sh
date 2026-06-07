#/bin/bash

sudo apt-get update -y
sudo apt-get install -y software-properties-common

sudo add-apt-repository -y ppa:kobuk-team/intel-graphics

sudo apt-get install -y libze-intel-gpu1 libze1 intel-metrics-discovery intel-opencl-icd clinfo intel-gsc

sudo apt-get install -y intel-media-va-driver-non-free libmfx-gen1 libvpl2 libvpl-tools libva-glx2 va-driver-all vainfo

sudo apt-get install -y libze-dev intel-ocloc

sudo apt-get install -y libze-intel-gpu-raytracing

clinfo | grep "Device Name"

sudo gpasswd -a ${USER} render
newgrp render

