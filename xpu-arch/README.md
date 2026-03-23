# Arch/Garuda XPU Setup

**Tested on Garuda Linux 6.19**

- Assuming you having installed using Mesa drivers.

```bash
sudo pacman -S intel-compute-runtime intel-media-driver level-zero-loader level-zero-headers ocl-icd
```

```bash
sudo gpasswd -a $USER render
sudo gpasswd -a $USER video
```

```bash
newgrp render
```

Either re-source your shell or simply close Konsole and re-open.

Install uv:

```bash
pip install uv
```

Re-source your shell or simply close Konsole and re-open.

Create uv venv folder/s:

```bash
mkdir ~/AI
cd ~/AI
mkdir xpu
cd xpu
```

Create a venv with a hidden folder named `.venv`:

```bash
uv venv .venv python 3.12
source .venv/bin/activate.fish
```

Install PyTorch with XPU support:

```bash
uv pip install torch==2.8.0 torchvision==0.23.0 torchaudio==2.8.0 --index-url https://download.pytorch.org/whl/xpu
```

Install Intel Extension for PyTorch:

```bash
uv pip pip install intel-extension-for-pytorch==2.8.10+xpu --extra-index-url https://pytorch-extension.intel.com/release-whl/stable/xpu/us/
```

Install other needed packages:

```bash
uv pip install jupyterlab accelerate diffusers tqdm IProgress transformers scikit-learn matplotlib pillow numpy pandas safetensors ipywidgets
```