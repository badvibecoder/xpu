@echo off
echo Running oneapi env bat files

call "c:\Program Files (x86)\Intel\oneAPI\2026.0\oneapi-vars.bat"
call "c:\Program Files (x86)\Intel\oneAPI\2026.0\setvars-vcvarsall.bat"

echo Both files have completed successfully!
pause