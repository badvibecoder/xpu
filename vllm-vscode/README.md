# Goal: Setup vLLM to serve models to VS Code

Things we need:

- VS Code
- Continue extension
- vLLM
- Model
- Arc GPU (B580) and related drivers
- oneAPI base toolkit


Install oneAPI base toolkit

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
