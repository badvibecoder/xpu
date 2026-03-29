# Goal: Setup vLLM to serve models to VS Code

Things we need:

- VS Code
- Continue extension
- vLLM
- openVINO
- Model
- Arc GPU (B580) and related drivers
- oneAPI base toolkit
- Python
- uv


## Install oneAPI base toolkit

```bash
sudo apt update -y
sudo apt install cmake pkg-config build-essential -y
# Verify
which cmake pkg-config make gcc g++
```

Edit your GRUB

```bash
sudo vim /etc/default/grub
```

Look for the line: `GRUB_CMDLINE_LINUX_DEFAULT="quiet splash"`

We need to add `i915.enable_hangcheck=0` at the end after `quiet splash`

The line should look like:

```bash
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash i915.enable_hangcheck=0"
```

Save and exit

Update grub and reboot

```bash
sudo update-grub
sudo reboot
```

Verification

We should see "i915.enable_hangcheck=0"

```bash
cat /proc/cmdline
```

```bash
$ cat /proc/cmdline
BOOT_IMAGE=/boot/vmlinuz-6.17.0-19-generic root=UUID=~~~~~~ ro quiet splash i915.enable_hangcheck=0 vt.handoff=7
```

Install oneAPI with the online installer: <a href="https://www.intel.com/content/www/us/en/developer/tools/oneapi/base-toolkit-download.html?packages=oneapi-toolkit&oneapi-toolkit-os=linux&oneapi-lin=online">Intel® oneAPI Base Toolkit</a>

Download the script and execute. 

```bash
$ bash intel-oneapi-base-toolkit-2025.3.1.36.sh
```

This will popup a gui based installation, follow the prompts.

Verify Installation, in my case it was installed in my home dir under `intel`

Set the environment vars:

```bash
. ~/intel/oneapi/oneapi-vars.sh
```

You should see output similar to:

```bash
:: initializing oneAPI environment ...
   bash: BASH_VERSION = 5.2.21(1)-release
   args: Using "$@" for oneapi-vars.sh arguments: 
:: advisor -- processing etc/advisor/vars.sh
:: ccl -- processing etc/ccl/vars.sh
:: compiler -- processing etc/compiler/vars.sh
:: dal -- processing etc/dal/vars.sh
:: debugger -- processing etc/debugger/vars.sh
:: dnnl -- processing etc/dnnl/vars.sh
:: dpct -- processing etc/dpct/vars.sh
:: dpl -- processing etc/dpl/vars.sh
:: ipp -- processing etc/ipp/vars.sh
:: ippcp -- processing etc/ippcp/vars.sh
:: mkl -- processing etc/mkl/vars.sh
:: mpi -- processing etc/mpi/vars.sh
:: tbb -- processing etc/tbb/vars.sh
:: vtune -- processing etc/vtune/vars.sh
:: oneAPI environment initialized ::
```

Launch the oneAPI samples browser: `oneapi-cli`

Create a project -> cpp -> Base:Vector Add -> Create

This will create a folder where you specified. Lets compile the cpp.

`cd` to `vector-add/src`

We should have the required compilers and tools installed:

```bash
# dpcpp is deprecated use icpx
#dpcpp vector-add-buffers.cpp -o vector_add_buff_app

icpx -fsycl vector-add-buffers.cpp -o vector_add_buff_app
```

You should see similar to the following output: 

```bash
$ ./vector_add_buff_app 
Running on device: Intel(R) Arc(TM) B580 Graphics
Vector size: 10000
[0]: 0 + 0 = 0
[1]: 1 + 1 = 2
[2]: 2 + 2 = 4
...
[9999]: 9999 + 9999 = 19998
Vector add successfully completed on device.
```

## Setup your uv venv Environment

I keep my uv venvs / projects in a directory: `~/Venvs` you can put them where you like but I will reference this folder.

Create a new project dir to home the venv: `mkdir vllm-vscode`

cd to the dir: `cd vllm-vscode`

Create a venv with uv for python 3.13: `uv venv .vllm-intel --python 3.13`

Activate the venv: `source .vllm-intel/bin/activate`

Update pip: `uv pip install --upgrade pip`

These can take a very long time to install, be patient. 

```bash
uv pip install torch==2.8.0 torchvision==0.23.0 torchaudio==2.8.0 --index-url https://download.pytorch.org/whl/xpu

# If the ipex install fails (seems to happen due to a FE website issue) use the whl package directly with the line below
# uv pip install https://download.pytorch-extension.intel.com/ipex_stable/xpu/intel_extension_for_pytorch-2.8.10%2Bxpu-cp313-cp313-linux_x86_64.whl
uv pip install intel-extension-for-pytorch==2.8.10+xpu --extra-index-url https://pytorch-extension.intel.com/release-whl/stable/xpu/us/

uv pip install oneccl_bind_pt==2.8.0+xpu --index-url https://pytorch-extension.intel.com/release-whl/stable/xpu/us/
```

Validate the installation: 

```bash
python -c "import torch; import intel_extension_for_pytorch as ipex; print(torch.__version__); print(ipex.__version__); [print(f'[{i}]: {torch.xpu.get_device_properties(i)}') for i in range(torch.xpu.device_count())];"
```

If you run into errors regarding being unable to import `...Venvs/vllm-vscode/.vllm-intel/lib/python3.13/site-packages/torch/lib/../../../../libsycl.so.8`

You may need to export the correct path from your venv: `export LD_LIBRARY_PATH=$HOME/Venvs/vllm-vscode/.vllm-intel/lib:$LD_LIBRARY_PATH`

Rerun the python validation:

You should see similar to: 

```bash
True
2.8.0+xpu
2.8.10+xpu
```

## Install vLLM

Clone the repo: `git clone --depth 1 https://github.com/vllm-project/vllm.git`

**Note:** `--depth 1` will just pull the latest commit and not the entire life of the project

Change to the dir: `cd vllm`

Install the following:

Ensure that `requirements/xpu.txt` is using the targetd torch version `2.8.0+xpu`

```bash
uv pip install -r requirements/xpu.txt
uv pip install setuptools wheel cmake ninja pybind11
uv pip install -r requirements/common.txt
#uv pip install cmake>=3.26.1 wheel packaging ninja setuptools-scm
```

Build vLLM targeting XPU: `VLLM_TARGET_DEVICE=xpu uv pip install --no-build-isolation --no-deps -e .`

Test: `python -c 'import torch; import intel_extension_for_pytorch; from vllm import LLM; print("XPU Initialized!")'`

You should see similar to:

```bash
[W329 16:52:42.522746713 OperatorEntry.cpp:218] Warning: Warning only once for all operators,  other operators may also be overridden.
  Overriding a previously registered kernel for the same operator and the same dispatch key
  operator: aten::geometric_(Tensor(a!) self, float p, *, Generator? generator=None) -> Tensor(a!)
    registered at /pytorch/build/aten/src/ATen/RegisterSchema.cpp:6
  dispatch key: XPU
  previous kernel: registered at /pytorch/aten/src/ATen/VmapModeRegistrations.cpp:37
       new kernel: registered at /build/intel-pytorch-extension/build/Release/csrc/gpu/csrc/gpu/xpu/ATen/RegisterXPU_0.cpp:172 (function operator())
XPU Initialized!
```

## Pip freeze snapshot of a working setup

`uv pip freeze > xpurequirements.txt`

```bash
aiohappyeyeballs==2.6.1
aiohttp==3.13.4
aiosignal==1.4.0
annotated-doc==0.0.4
annotated-types==0.7.0
anthropic==0.86.0
anyio==4.13.0
astor==0.8.1
attrs==26.1.0
blake3==1.0.8
cachetools==7.0.5
cbor2==5.9.0
certifi==2026.2.25
cffi==2.0.0
charset-normalizer==3.4.6
click==8.3.1
cloudpickle==3.1.2
cmake==4.3.0
compressed-tensors==0.14.0.1
cryptography==46.0.6
datasets==4.8.4
depyf==0.20.0
dill==0.4.1
diskcache==5.6.3
distro==1.9.0
dnspython==2.8.0
docstring-parser==0.17.0
dpcpp-cpp-rt==2025.1.1
einops==0.8.2
email-validator==2.3.0
fastapi==0.135.2
fastapi-cli==0.0.24
fastapi-cloud-cli==0.15.1
fastar==0.9.0
filelock==3.25.2
frozenlist==1.8.0
fsspec==2026.2.0
gguf==0.18.0
googleapis-common-protos==1.73.1
grpcio==1.78.0
h11==0.16.0
hf-xet==1.4.2
httpcore==1.0.9
httptools==0.7.1
httpx==0.28.1
httpx-sse==0.4.3
huggingface-hub==0.36.2
idna==3.11
ijson==3.5.0
impi-rt==2021.15.0
importlib-metadata==8.7.1
intel-cmplr-lib-rt==2025.1.1
intel-cmplr-lib-ur==2025.1.1
intel-cmplr-lic-rt==2025.1.1
intel-extension-for-pytorch @ https://download.pytorch-extension.intel.com/ipex_stable/xpu/intel_extension
_for_pytorch-2.8.10%2Bxpu-cp313-cp313-linux_x86_64.whl
intel-opencl-rt==2025.1.1
intel-openmp==2025.1.1
intel-pti==0.12.3
intel-sycl-rt==2025.1.1
interegular==0.3.3
jinja2==3.1.6
jiter==0.13.0
jmespath==1.1.0
jsonschema==4.26.0
jsonschema-specifications==2025.9.1
lark==1.2.2
llguidance==1.3.0
llvmlite==0.44.0
lm-format-enforcer==0.11.3
loguru==0.7.3
markdown-it-py==4.0.0
markupsafe==3.0.3
mcp==1.26.0
mdurl==0.1.2
mistral-common==1.10.0
mkl==2025.1.0
model-hosting-container-standards==0.1.14
mpmath==1.3.0
msgpack==1.1.2
msgspec==0.20.0
multidict==6.7.1
multiprocess==0.70.19
networkx==3.6.1
ninja==1.13.0
numba==0.61.2
numpy==2.2.6
oneccl==2021.15.2
oneccl-bind-pt==2.8.0+xpu
oneccl-devel==2021.15.2
onemkl-license==2025.3.0
onemkl-sycl-blas==2025.1.0
onemkl-sycl-dft==2025.1.0
onemkl-sycl-lapack==2025.1.0
onemkl-sycl-rng==2025.1.0
onemkl-sycl-sparse==2025.1.0
openai==2.30.0
openai-harmony==0.0.8
opencv-python-headless==4.13.0.92
opentelemetry-api==1.40.0
opentelemetry-exporter-otlp==1.40.0
opentelemetry-exporter-otlp-proto-common==1.40.0
opentelemetry-exporter-otlp-proto-grpc==1.40.0
opentelemetry-exporter-otlp-proto-http==1.40.0
opentelemetry-proto==1.40.0
opentelemetry-sdk==1.40.0
opentelemetry-semantic-conventions==0.61b0
opentelemetry-semantic-conventions-ai==0.5.1
outlines-core==0.2.11
packaging==26.0
pandas==3.0.1
partial-json-parser==0.2.1.1.post7
pillow==12.1.1
prometheus-client==0.24.1
prometheus-fastapi-instrumentator==7.1.0
propcache==0.4.1
protobuf==6.33.6
psutil==7.2.2
py-cpuinfo==9.0.0
pyarrow==23.0.1
pybase64==1.4.3
pybind11==3.0.2
pycountry==26.2.16
pycparser==3.0
pydantic==2.12.5
pydantic-core==2.41.5
pydantic-extra-types==2.11.1
pydantic-settings==2.13.1
pyelftools==0.32
pygments==2.20.0
pyjwt==2.12.1
python-dateutil==2.9.0.post0
python-dotenv==1.2.2
python-json-logger==4.1.0
python-multipart==0.0.22
pytorch-triton-xpu==3.4.0
pyyaml==6.0.3
pyzmq==27.1.0
ray==2.54.1
referencing==0.37.0
regex==2026.3.32
requests==2.33.0
rich==14.3.3
rich-toolkit==0.19.7
rignore==0.7.6
rpds-py==0.30.0
safetensors==0.7.0
sentencepiece==0.2.1
sentry-sdk==2.56.0
setproctitle==1.3.7
setuptools==80.10.2
setuptools-scm==10.0.5
shellingham==1.5.4
six==1.17.0
sniffio==1.3.1
sse-starlette==3.3.4
starlette==0.52.1
supervisor==4.3.0
sympy==1.14.0
tbb==2022.1.0
tcmlib==1.3.0
tiktoken==0.12.0
tokenizers==0.22.2
torch==2.8.0+xpu
torchaudio==2.8.0+xpu
torchvision==0.23.0+xpu
tqdm==4.67.3
transformers==4.57.6
triton==3.6.0
triton-xpu==3.6.0
typer==0.24.1
typing-extensions==4.15.0
typing-inspection==0.4.2
umf==0.10.0
urllib3==2.6.3
uvicorn==0.42.0
uvloop==0.22.1
vcs-versioning==1.1.1
-e file:///home/pcarroll/Venvs/vllm-vscode/vllm
vllm-xpu-kernels @ https://github.com/vllm-project/vllm-xpu-kernels/releases/download/v0.1.4/vllm_xpu_kern
els-0.1.4-cp38-abi3-manylinux_2_28_x86_64.whl
watchfiles==1.1.1
websockets==16.0
wheel==0.46.3
xgrammar==0.1.33
xxhash==3.6.0
yarl==1.23.0
zipp==3.23.0
```

**Note:** The first time this may take an extremely long time to download and resolve depedencies.



## Start the vLLM server

# The 32B model is a powerhouse for code feedback

```bash
vllm serve "Qwen/Qwen2.5-Coder-7B-Instruct-GPTQ-Int4" \
    --device xpu \
    --dtype auto \
    --max-model-len 16384
```

vllm serve "Qwen/Qwen2.5-Coder-7B-Instruct-GPTQ-Int4" --device xpu --dtype auto --max-model-len 8192 --quantization gptq
