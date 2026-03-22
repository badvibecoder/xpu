FROM intel/intel-optimized-tensorflow:2.15.0-xpu-pip-jupyter

# Install additional pip packages
#RUN pip install --no-cache-dir scikit-learn ipywidgets IProgress transformers matplotlib sentencepiece openai-whisper accelerate
RUN apt update -y && apt install ffmpeg -y

# Set working directory
WORKDIR /jupyter

# Ensure Jupyter uses /jupyter as notebook directory
CMD ["jupyter", "lab", "--ip=0.0.0.0", "--no-browser", "--allow-root", "--NotebookApp.notebook_dir=/jupyter"]

#sudo docker build -t mrchanche-xpu-tensorflow-jupyter:2.15.0 -f Dockerfile .
