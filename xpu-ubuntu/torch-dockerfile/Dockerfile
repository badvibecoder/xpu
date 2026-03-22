FROM intel/intel-extension-for-pytorch:2.8.10-xpu-pip-jupyter

# Install additional pip packages
RUN pip install --no-cache-dir scikit-learn ipywidgets IProgress transformers matplotlib sentencepiece openai-whisper accelerate
# RUN pip install --no-cache-dir bitsandbytes openvino openvino-dev keras keras-hub keras-cv
RUN apt update -y && apt install ffmpeg -y

# Set working directory, this is the directory in the container and not the host
WORKDIR /jupyter

# Ensure Jupyter uses /jupyter as notebook directory
CMD ["jupyter", "lab", "--ip=0.0.0.0", "--no-browser", "--allow-root", "--NotebookApp.notebook_dir=/jupyter"]

#sudo docker build -t mrchanche-xpu-torch-jupyter:2.8.10 -f Dockerfile .
