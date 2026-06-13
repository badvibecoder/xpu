# Set Oneapi / XPU / ARC gpu environment on Fedora44 Kernel 7.0.12-201.fc44.x86_64

### Setup

- 270K Plus
- Arc Pro B70 32GB

### Check for existing mesa drivers

Mesa drivers should already be install. We will just install latest and also include intel specifics.

```bash
sudo dnf install libva-intel-media-driver mesa-dri-drivers mesa-vulkan-drivers mesa-va-drivers
```

The mesa drivers will most likely already be installed. The intel media driver should also be installed, at this point. Intel has most of what we need in the fedora repos:

```bash
sudo dnf install intel-compute-runtime intel-level-zero intel-level-zero-devel intel-ocloc intel-opencl clinfo libva-intel-media-driver libvpl libva-utils

sudo dnf group install development-tools

sudo dnf install cmake pkgconfig
```

Check for the arc GPU:

```bash
clinfo | grep "Device Name"
```

You should see something like:

```bash
Device Name                                   Intel(R) Arc(TM) Pro B70 Graphics
Device Name                                   Intel(R) Arc(TM) Pro B70 Graphics
Device Name                                   Intel(R) Arc(TM) Pro B70 Graphics
Device Name                                   Intel(R) Arc(TM) Pro B70 Graphics
```

Add your user to video/render groups:

```bash
sudo usermod -aG video,render $USER
```

Check and validate the driver is xe and not arc:

```bash
lspci -nnk | grep -A3 VGA
```

If it says arc you may need to set: `i915.enable_hangcheck=0` but for fedora44 kernel 7+ you should only see xe.

### Install oneapi

```bash
sudo dnf install gcc-c++
```

Download latest oneapi toolkit: https://www.intel.com/content/www/us/en/developer/tools/oneapi/oneapi-toolkit-download.html?packages=oneapi-toolkit&oneapi-toolkit-os=linux&oneapi-lin=offline

Execute the offline bash script.

This by default will render the gui installer, follow the prompts, take note that it will display if you are missing any packages. Install those packages and click to the fresh button on the bottom of the installer to resolve dependencies.

### Setup vscode for dpcpp

Install c++ and coderunner extensions for vscode

Enable `code-runner.runInTerminal`

Edit the `executor map` for coderunner

It may already have icpx which will have the same level of sycl as dpcpp but you must add the `-fsycl` flag during compilation. Otherwise you could change the following line to use either icpx or dpcpp.

```bash
"cpp": "cd $dir && icpx $fileName -o $fileNameWithoutExt && $dir$fileNameWithoutExt",
```

or

```bash
"cpp": "cd $dir && dpcpp $fileName -o $fileNameWithoutExt && $dir$fileNameWithoutExt",
```
 
I will use icpx as dpcpp will be deprecated in the near future and replaced with icpx..

### Env Vars

We can use vscode as is in fedora and code will execute on the intel compilers. If you want a more universal approach we can add the oneapi setvars.sh to our .bashrc. Alternatively you can set an alias and invoke the vars as needed.

```bash
alias intelenv="source ~/intel/oneapi/setvars.sh"
``` 

Or

```bash
echo "source ~/intel/oneapi/setvars.sh > /dev/null 2>&1" >> ~/.bashrc
```

At this point try to execute some cpp from vscode, it should now execute in terminal and have access to oneapi.

### Pytorch XPU

Download the following:

```bash

For testing we really only need a single package: https://download.pytorch.org/whl/

Navigate to `torch` and download: 

```bash
wget https://download-r2.pytorch.org/whl/xpu/torch-2.12.0%2Bxpu-cp312-cp312-linux_x86_64.whl

wget https://download-r2.pytorch.org/whl/triton_xpu-3.7.1-cp312-cp312-manylinux_2_27_x86_64.manylinux_2_28_x86_64.whl
```

Sometimes the intel repo is very slow, be patient.

I will use uv to create a python 3.12 venv:

```bash
uv venv .venv --python 3.12

source .venv/bin/activate
```

### Test oneapi compilers

Run: `oneapi-cli`

This may take a minute to load as it pulls data from the repo.

Create a project -> cpp -> Base: Vector Add -> Set your install dir

This is essentially the Hello World.

Navigate to the install dir.

```bash
cd vector-add
mkdir build
cd build
cmake ..
cmake --build .
./vector-add-buffers
```

If you run into errors with CMakeLists.txt you may need to manually edit the CMake version from x to 3.5+.
