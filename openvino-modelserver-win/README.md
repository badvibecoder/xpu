
https://docs.openvino.ai/2026/get-started/install-openvino/install-openvino-winget.html

winget --version
winget source update
winget search --id Intel.OpenVINOToolkit.2026.2.0 -e --source winget
winget install --id Intel.OpenVINOToolkit.2026.2.0 -e --source winget


curl -L https://github.com/openvinotoolkit/model_server/releases/download/v2026.2/ovms_windows_2026.2.0_python_on.zip -o ovms.zip
tar -xf ovms.zip



ovms --model_path <path_to_model> --model_name <model_name> --port 9000 --rest_port 8000 --log_level DEBUG


ovms.exe --pull --source_model "OpenVINO/Qwen3.6-35B-A3B-int4-ov" --model_repository_path E:\ovms\MODEL --model_name qwen-35b-3b-active --target_device GPU --task text_generation --rest_port 8000


mkdir c:\models
ovms --model_repository_path E:\ovms\MODEL --source_model OpenVINO/Qwen3-Coder-30B-A3B-Instruct-int4-ov --task text_generation --target_device GPU --tool_parser qwen3coder --rest_port 8000 --cache_dir .ovcache --model_name Qwen3-Coder-30B-A3B-Instruct