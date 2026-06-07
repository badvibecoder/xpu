# Ubuntu 26.10 LTS - 7+ Kernel - Oneapi

Officially oneapi latest 2026 is only supported on 24.04 LTS

### Install driver and client packages

```bash
sudo apt-get update
sudo apt-get install -y software-properties-common

sudo add-apt-repository -y ppa:kobuk-team/intel-graphics

sudo apt-get install -y libze-intel-gpu1 libze1 intel-metrics-discovery intel-opencl-icd clinfo intel-gsc

sudo apt-get install -y intel-media-va-driver-non-free libmfx-gen1 libvpl2 libvpl-tools libva-glx2 va-driver-all vainfo

sudo apt-get install -y libze-dev intel-ocloc

sudo apt-get install -y libze-intel-gpu-raytracing

clinfo | grep "Device Name"

sudo gpasswd -a ${USER} render
newgrp render
```
No reboots are neccessary, at this point you should be able to game, run pytorch with xpu support etc...

### Download and install the oneapi toolkit installer

Go to: https://www.intel.com/content/www/us/en/developer/tools/oneapi/oneapi-toolkit-download.html?packages=oneapi-toolkit&oneapi-toolkit-os=linux&oneapi-lin=offline

Download the offline sh script (2GB)

`bash ./intel-oneapi-toolkit-2026.0.0.198_offline.sh`

This will popup the gui installer (testing on kunbuntu 26.10 lts)

The default installation folder will be `/home/yourusername/intel/oneapi` if this is a single user system this is fine, or if you dont want to sudo every oneapi related command. For multiuser systems you will want to find somewhere else like `/opt/intel/oneapi`.

You can intergrate with an IDE, I will skip this on the installer.

Once installed you can read through the getting started docs here: https://www.intel.com/content/www/us/en/docs/oneapi-toolkit/installation-guide-linux/latest/overview.html

### Post toolkit configuration

```bash
sudo apt -y update
sudo apt -y install cmake pkg-config build-essential

which cmake pkg-config make gcc g++
```
We need to edit grub as root/sudo and disable hangcheck for long running gpu kernels.

In `/etc/default/grub` we want to add to the var `GRUB_CMDLINE_LINUX_DEFAULT`

Add: `i915.enable_hangcheck=0` after any existing settings.

```bash
GRUB_CMDLINE_LINUX_DEFAULT='quiet splash i915.enable_hangcheck=0'
```

Save and close the grub file, then run:

```bash
sudo update-grub
```

Reboot your machine.

### Set env vars

Oneapi needs to have env vars set on boot, this will be located in your installation directory, then the specific version of oneapi, and finally the bash script to set the variables will be named `oneapi-vars.sh`

In this case: `source /home/yourusername/intel/oneapi/2026.0/oneapi-vars.sh`

We will need to add this to our .bashrc file:

```bash
echo "source ~/intel/oneapi/2026.0/oneapi-vars.sh" >> ~/.bashrc
```

### Test if oneapi compilers are working

Run: `oneapi-cli`

This may take a minute to load as it pulls data from the repo.

Create a project -> cpp -> Base: Vector Add -> Set your install dir

This is essentially the Hello World.

Navigate to the install dir.

bash```
cd vector-add
mkdir build
cd build
cmake ..
cmake --build .
./vector-add-buffers
```

I ran into the following error:

```bash
CMake Error at CMakeLists.txt:12 (cmake_minimum_required):
  Compatibility with CMake < 3.5 has been removed from CMake.

  Update the VERSION argument <min> value.  Or, use the <min>...<max> syntax
  to tell CMake that the project requires at least <min> but has been updated
  to work with policies introduced by <max> or earlier.

  Or, add -DCMAKE_POLICY_VERSION_MINIMUM=3.5 to try configuring anyway.


-- Configuring incomplete, errors occurred!
```

Looking at our CMakeLists.txt

```bash
~/Github/xpu/xpu-oneapi-ubuntu/vector-add$ more CMakeLists.txt 
if(UNIX)
    # Direct CMake to use icpx rather than the default C++ compiler/linker
    set(CMAKE_CXX_COMPILER icpx)
else() # Windows
    # Force CMake to use icx-cl rather than the default C++ compiler/linker 
    # (needed on Windows only)
    include (CMakeForceCompiler)
    CMAKE_FORCE_CXX_COMPILER (icx-cl IntelDPCPP)
    include (Platform/Windows-Clang)
endif()

cmake_minimum_required (VERSION 3.4)

project(VectorAdd CXX)

set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR})
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR})
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR})

add_subdirectory (src)
```

Lets update line: `cmake_minimum_required (VERSION 3.4)`

To: `cmake_minimum_required (VERSION 3.5)`

Retest.

Success.

```bash
~/Github/xpu/xpu-oneapi-ubuntu/vector-add/build$ ./vector-add-buffers 
Running on device: Intel(R) Arc(TM) Pro B70 Graphics
Vector size: 10000
[0]: 0 + 0 = 0
[1]: 1 + 1 = 2
[2]: 2 + 2 = 4
...
[9999]: 9999 + 9999 = 19998
Vector add successfully completed on device
```

At this point we should have a path to run SYCL/c++ against our arc gpu, pytorch xpu will also work, gaming and raytracing support in linux will work. 
