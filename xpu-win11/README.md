# Setting Up ARC B50/B60/B570/B580 GPUs with Full Mixed Precision and Intel IPEX Acceleration in PyTorch with Jupyter Labs (Windows)

These instructions have gone through many iterations since the A770 release. While the Alchemist generation can be pretty quick using openvino for specific models inference the training has always been slow. Battlemage is on the opposite end, it tends to punch wildly above its weight class in specific training scenarios. 

Previously you needed to install the full version of oneAPI along with Visual Studio, this is no longer the case. These instruction have been greatly reduced to bring it to the current 2026 state of xpu/ipex for pytorch.

### Caveats

- Install latest driver, Pro or Gaming depending on your card. 
- No multi-GPU support in Windows
    - You will not be able to utilize any distributed training technologies for Intel GPUs in windows, this is available via the intel xpu docker container in linux. 
    - This also applies to WSL2, which cannot assign more than a single gpu anyways.
    - You **can** use multi-gpu for software like LM Studio which will aggregate devices together for inference when using Vulcan as the backend.

## Step 1: Install Miniconda
1. <a href="https://docs.anaconda.com/miniconda/install/">https://docs.anaconda.com/miniconda/install/</a>
2. All the default options during installation should be fine to use.

## Step 2: Create a folder we will use for our Jupyter Labs
1. I will open powershell or cmd and navigate to my dev drive and create a "JUPYTER" folder. This will be the root folder used by Jupyter Labs. You can accomplish this many different ways, using the GUI is probably the easiest.
```
cmd
cd d:
mkdir JUPYTER
cd JUPYTER
mkdir XPU
exit
```

## Step 3: Open an Anaconda Prompt (miniconda)
1. Navigate to your XPU folder
  - In my case this would be `D:\JUPYTER\XPU`
2. Create a conda environment with python 3.13, named xpu, and then activate the environment.
3. When activating the conda environment you maybe prompted to accept multiple terms of service line items. 

```
conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/main
```

```
conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/r
```

```
conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/msys2
```

```
conda create -n xpu python=3.13 -y
```

```
conda activate xpu
```

## Step 4: Install the required torch packages via pip

For latest: <a href="https://github.com/intel/intel-extension-for-pytorch">https://github.com/intel/intel-extension-for-pytorch</a>

1. Run the following commands to install the intel torch packages
```
python -m pip install torch==2.8.0 torchvision==0.23.0 torchaudio==2.8.0 --index-url https://download.pytorch.org/whl/xpu
```

```
python -m pip install intel-extension-for-pytorch==2.8.10+xpu --extra-index-url https://pytorch-extension.intel.com/release-whl/stable/xpu/us/
```

2. Run the following command to install other important packages
```
pip install jupyterlab accelerate diffusers tqdm IProgress transformers scikit-learn matplotlib pillow numpy pandas safetensors ipywidgets
```

3. Install OpenVINO if you plan on optimizing models for Intel hardware **(OPTIONAL)**
```
conda install -c conda-forge openvino=2025.4.0
```
Additionally install OpenVINO GenAI if you plan to optimize generative models
```
pip install openvino-genai
```
Download OpenVINO GenAI archives
```
curl -L https://storage.openvinotoolkit.org/repositories/openvino_genai/packages/2025.4/windows/openvino_genai_windows_2025.4.0.0_x86_64.zip --output openvino_genai_2025.4.0.0.zip
```

4. Run Jupyter Lab, this is a python environment that makes it easy to write code with markdown in a cell based format for rapid testing and visualization.
```
jupyter lab
```

## Step 5: Validate XPU is available, run the following in a jupyter lab code cell.
- This may take a few minutes to complete the first run.
```
import torch
import intel_extension_for_pytorch as ipex

# This will return True if everything is working
print(torch.xpu.is_available())
print(torch.__version__)

# Validate ipex version
print(ipex.__version__)
```

You should  see output similar to:

```
True
2.8.0
2.8.10+xpu
```

## Step 6: Train your model using torch.amp.autocast('xpu'). Here is an example of 3 code cells.

1. Lets generate some data to test with.
```
import os
import json
import random

# Constants
TRAIN_GOOD_FILE_COUNT = 250
TEST_GOOD_FILE_COUNT = 50
TRAIN_BAD_FILE_COUNT = 250
TEST_BAD_FILE_COUNT = 50
DATA_FOLDER = "data"
WDSDataset_FOLDER = os.path.join(DATA_FOLDER, "benchmark_dataset")

# Generate Good files
good_files = []
for i in range(TRAIN_GOOD_FILE_COUNT + TEST_GOOD_FILE_COUNT):
    data = {
        "id": random.randint(100000, 999999),
        "name": {
            "first": f"John",
            "last": f"Doe {i+1}"
        },
        "age": random.randint(18, 60),
        "score": {
            "math": round(random.uniform(0.6, 1.0), 2),
            "science": round(random.uniform(0.6, 1.0), 2),
            "english": round(random.uniform(0.6, 1.0), 2)
        },
        "address": {
            "street": f"{random.randint(100, 999)} Main St",
            "city": "Anytown",
            "state": "CA",
            "zip": f"{random.randint(10000, 99999)}"
        },
        "contacts": [
            {"type": "email", "value": f"john.doe{i+1}@example.com"},
            {"type": "phone", "value": f"555-{random.randint(1000, 9999)}"}
        ]
    }
    good_files.append(json.dumps(data))

# Generate Bad files
bad_files = []
for i in range(TRAIN_BAD_FILE_COUNT + TEST_BAD_FILE_COUNT):
    data = {
        "id": random.randint(100000, 999999),
        "name": {
            "first": f"John",
            "last": f"Doe {i+1}"
        },
        "age": random.randint(18, 60),
        "score": {
            "math": round(random.uniform(0.4, 0.9), 2),
            "science": round(random.uniform(0.4, 0.9), 2),
            "english": round(random.uniform(0.4, 0.9), 2)
        },
        "address": {
            "street": f"{random.randint(100, 999)} Main St",
            "city": "Anytown",
            "state": "CA",
            "zip": f"{random.randint(10000, 99999)}"
        },
        "contacts": [
            {"type": "email", "value": f"john.doe{i+1}@example.com"},
            {"type": "phone", "value": f"555-{random.randint(1000, 9999)}"}
        ],
        "feedback": ["bad", "not good", "block"][random.randint(0, 2)]
    }
    bad_files.append(json.dumps(data))

# Create train and test folder structure
train_good_folder_path = os.path.join(WDSDataset_FOLDER, "train", "good")
train_bad_folder_path = os.path.join(WDSDataset_FOLDER, "train", "bad")
test_good_folder_path = os.path.join(WDSDataset_FOLDER, "test", "good")
test_bad_folder_path = os.path.join(WDSDataset_FOLDER, "test", "bad")

os.makedirs(train_good_folder_path, exist_ok=True)
os.makedirs(train_bad_folder_path, exist_ok=True)
os.makedirs(test_good_folder_path, exist_ok=True)
os.makedirs(test_bad_folder_path, exist_ok=True)

# Save Good files 
for i in range(TRAIN_GOOD_FILE_COUNT):
    good_file_path = os.path.join(train_good_folder_path, f"good{i+1}.json")
    with open(good_file_path, "w") as f:
        f.write(good_files[i])

for i in range(TEST_GOOD_FILE_COUNT):
    # FIXED: Changed train_good_folder_path to test_good_folder_path
    good_file_path = os.path.join(test_good_folder_path, f"good{i+1}.json") 
    with open(good_file_path, "w") as f:
        f.write(good_files[TRAIN_GOOD_FILE_COUNT + i])

# Save Bad files
for i in range(TRAIN_BAD_FILE_COUNT):
    bad_file_path = os.path.join(train_bad_folder_path, f"bad{i+1}.json")
    with open(bad_file_path, "w") as f:
        f.write(bad_files[i])

for i in range(TEST_BAD_FILE_COUNT):
    # FIXED: Changed train_bad_folder_path to test_bad_folder_path
    bad_file_path = os.path.join(test_bad_folder_path, f"bad{i+1}.json")
    with open(bad_file_path, "w") as f:
        f.write(bad_files[TRAIN_BAD_FILE_COUNT + i])
```
2. Lets train a model with mixed precision using our XPU device.
```
import os
import json
import numpy as np
from sklearn.model_selection import train_test_split
from sklearn.metrics import accuracy_score, classification_report
import torch
from torch.utils.data import Dataset, DataLoader
from transformers import BertTokenizer, BertForSequenceClassification
from torch.cuda.amp import GradScaler, autocast
from torch.optim import AdamW
from torch.amp import GradScaler
# Import IPEX
import intel_extension_for_pytorch as ipex
import time
import tqdm
import warnings

warnings.filterwarnings("ignore")

# Function to set the number of CPU threads
def set_cpu_thread_cap(num_threads):
    torch.set_num_threads(num_threads)
    torch.set_num_interop_threads(num_threads)
    print(f"Set max CPU threads to: {num_threads}")

# Set the device type and device ID
device_type = "xpu" if torch.xpu.is_available() else "cuda" if torch.cuda.is_available() else "cpu"
device_id = 0  # Change this to the desired device index, e.g., 0 or 1
# Combine device type and device ID to create the device variable
device = torch.device(f"{device_type}:{device_id}" if device_type else "cpu")
print(f"Device: {device}")
# If running on CPU, set this manually, otherwise comment out
#device = "cpu"

# If running on CPU, set the number of threads
if device == 'cpu':
    set_cpu_thread_cap(8)  # Set this to the desired number of CPU threads


class JSONDataset(Dataset):
    def __init__(self, data_dir, tokenizer, max_length=512):
        self.data_dir = data_dir
        self.tokenizer = tokenizer
        self.max_length = max_length
        self.data = []

        # Load and preprocess data
        for label in ['good', 'bad']:
            label_dir = os.path.join(data_dir, label)
            for file_name in os.listdir(label_dir):
                if file_name.endswith('.json'):
                    file_path = os.path.join(label_dir, file_name)
                    with open(file_path, 'r') as f:
                        script_data = json.load(f)
                        # Convert JSON data to a string (simple approach, can be improved)
                        text = str(script_data)

                        self.data.append((text, label))

    def __len__(self):
        return len(self.data)

    def __getitem__(self, idx):
        text, label = self.data[idx]

        # Tokenize the text
        encoding = self.tokenizer(
            text,
            add_special_tokens=True,
            max_length=self.max_length,
            return_token_type_ids=False,
            padding='max_length',
            truncation=True,
            return_attention_mask=True,
            return_tensors='pt',
        )

        # Convert to tensors
        item = {
            'input_ids': encoding['input_ids'].flatten(),
            'attention_mask': encoding['attention_mask'].flatten(),
            'labels': torch.tensor(1 if label == 'good' else 0, dtype=torch.long)
        }

        return item

# Load tokenizer and model
tokenizer = BertTokenizer.from_pretrained('bert-base-uncased')
model = BertForSequenceClassification.from_pretrained('bert-base-uncased', num_labels=2)

# Move the model to the device
model.to(device)

# Dataset and DataLoader
train_dir = os.path.join("data", "benchmark_dataset", "train")
test_dir = os.path.join("data", "benchmark_dataset", "test")

train_dataset = JSONDataset(train_dir, tokenizer)
test_dataset = JSONDataset(test_dir, tokenizer)

train_loader = DataLoader(train_dataset, batch_size=5, shuffle=True)
test_loader = DataLoader(test_dataset, batch_size=5, shuffle=False)

# Optimizer
optimizer = AdamW(model.parameters(), lr=2e-5)



# Training function
def train_epoch(model, train_loader, optimizer):
    model.train()

    # Optimize the model with ipex.optimizer
    # This must be done when the model is set to train
    model, optimizer = ipex.optimize(model, optimizer=optimizer)
    
    total_loss = 0

    for step, batch in enumerate(train_loader):
        input_ids = batch['input_ids'].to(device)
        attention_mask = batch['attention_mask'].to(device)
        labels = batch['labels'].to(device)

        optimizer.zero_grad()

        with torch.amp.autocast(device_type):
            outputs = model(input_ids=input_ids, attention_mask=attention_mask, labels=labels)
            loss = outputs.loss

        loss.backward()
        optimizer.step()
        total_loss += loss.item()

    return total_loss / len(train_loader)

# Testing function
def test_model(model, test_loader):
    model.eval()
    all_preds = []
    all_labels = []

    with torch.no_grad():
        for batch in test_loader:
            input_ids = batch['input_ids'].to(device)
            attention_mask = batch['attention_mask'].to(device)
            labels = batch['labels'].to(device)

            with torch.amp.autocast(device_type):
                outputs = model(input_ids=input_ids, attention_mask=attention_mask)
                logits = outputs.logits
                preds = torch.argmax(logits, dim=-1)

            all_preds.extend(preds.cpu().numpy())
            all_labels.extend(labels.cpu().numpy())

    accuracy = accuracy_score(all_labels, all_preds)
    report = classification_report(all_labels, all_preds, target_names=['bad', 'good'], labels=[0, 1])

    return accuracy, report

# Training loop
epochs = 1

benchmarkLoops = 10

# Start timer
start_time = time.time()

# Run the training loop with tqdm for progress bar
for i in tqdm.tqdm(range(benchmarkLoops)):
    for epoch in range(epochs):
        train_loss = train_epoch(model, train_loader, optimizer)
        accuracy, report = test_model(model, test_loader)
        # print time and loop number
        print(f"Loop {i+1} - Epoch {epoch+1} - Train Loss: {train_loss:.4f} - Accuracy: {accuracy:.4f}")

# End timer
end_time = time.time()
elapsed_time = end_time - start_time
print(f"Elapsed time: {elapsed_time:.2f} seconds")
```
