FROM intel/vllm:0.14.1-xpu

# Install additional pip packages
#RUN pip install --no-cache-dir scikit-learn ipywidgets IProgress transformers matplotlib sentencepiece openai-whisper accelerate
# RUN pip install --no-cache-dir bitsandbytes openvino openvino-dev keras keras-hub keras-cv
#RUN apt update -y && apt install ffmpeg -y

# Set working directory, this is the directory in the container and not the host
#WORKDIR /jupyter

# Ensure Jupyter uses /jupyter as notebook directory
#CMD ["jupyter", "lab", "--ip=0.0.0.0", "--no-browser", "--allow-root", "--NotebookApp.notebook_dir=/jupyter"]

#sudo docker build -t mrchanche-xpu-torch-jupyter:2.8.10 -f Dockerfile .



sudo docker run -it --rm \
  --device /dev/dri:/dev/dri \
  --device /dev/dri/by-path:/dev/dri/by-path \
  --net=host \
  --ipc=host \
  --shm-size="10g" \
  --privileged \
  -v ~/.cache/huggingface:/root/.cache/huggingface \
  --entrypoint python3 \
  intel/vllm:0.10.0-xpu \
  -m vllm.entrypoints.openai.api_server \
  --model "Qwen/Qwen2.5-Coder-7B-Instruct-GPTQ-Int4" \
  --dtype float16 \
  --max-model-len 8192 \
  --gpu-memory-utilization 0.8 \
  --trust-remote-code



name: Intel Arc AI Coding
version: 1.0.0
schema: v1

models:
  - name: "Arc B580 - Qwen Coder"
    provider: openai
    model: "Qwen/Qwen2.5-Coder-7B-Instruct-GPTQ-Int4"
    apiBase: "http://localhost:8000/v1"
    apiKey: "EMPTY"
    contextLength: 8192

tabAutocomplete:
  name: "Arc B580 Autocomplete"
  provider: openai
  model: "Qwen/Qwen2.5-Coder-7B-Instruct-GPTQ-Int4"
  apiBase: "http://localhost:8000/v1"
  apiKey: "EMPTY"

# This stops Continue from trying to use OpenAI's paid API for indexing your files
embeddingsProvider:
  provider: transformers.js

contextProviders:
  - name: code
  - name: docs
  - name: diff
  - name: terminal